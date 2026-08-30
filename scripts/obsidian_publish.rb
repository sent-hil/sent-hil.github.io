# Publishes Obsidian notes tagged #post into _posts/.
#
# Entry point is the `obsidian` rake task. Nothing here writes to the vault --
# it is only ever read.

require 'date'
require 'fileutils'
require 'digest'
require 'set'
require 'yaml'

module ObsidianPublish
  ROOT = File.expand_path('..', __dir__)
  CONFIG_PATH = File.join(ROOT, 'scripts', 'publish.yml')
  POSTS_DIR = File.join(ROOT, '_posts')

  # The frontmatter key that marks a post as generated from a note. A post
  # without it was written by hand and is never touched -- that check is the
  # whole safety story, so it lives in one place.
  SOURCE_KEY = 'obsidian_source'
  HASH_KEY = 'obsidian_hash'

  Config = Struct.new(:vault, :tag) do
    def self.load
      raw = File.exist?(CONFIG_PATH) ? YAML.load_file(CONFIG_PATH) : {}
      vault = ENV['OBSIDIAN_VAULT'] || raw['vault']
      abort 'No vault configured. Set OBSIDIAN_VAULT or vault: in scripts/publish.yml.' if vault.nil?

      vault = File.expand_path(vault)
      abort "Vault not found: #{vault}" unless File.directory?(vault)

      new(vault, (raw['tag'] || 'post').delete_prefix('#'))
    end
  end

  # One note in the vault, tagged for publication.
  Note = Struct.new(:path, :vault) do
    def relative_path = path.delete_prefix("#{vault}/")
    def title         = File.basename(path, '.md')
    def read          = File.read(path)
    def hash_of_source = Digest::SHA256.hexdigest(read)
  end

  # One file in _posts/. `source` is nil for anything written by hand.
  Post = Struct.new(:path, :frontmatter) do
    def source   = frontmatter[SOURCE_KEY]
    def hash     = frontmatter[HASH_KEY]
    def ours?    = !source.nil?
    def filename = File.basename(path)
  end

  # What one run would do, worked out before anything is written.
  Plan = Struct.new(:new_notes, :changed, :unchanged, :orphans, :handwritten, keyword_init: true)

  module_function

  # Every note carrying the tag, ignoring hits inside fenced code blocks so a
  # note *about* tagging does not publish itself.
  def tagged_notes(config)
    pattern = /(?<=\A|\s)##{Regexp.escape(config.tag)}(?=\s|\z)/

    notes = Dir.glob(File.join(config.vault, '**', '*.md'), File::FNM_DOTMATCH)
               .reject { |p| p.split(File::SEPARATOR).any? { |part| part.start_with?('.') } }
               .select { |p| outside_code_fences(File.read(p)).match?(pattern) }
               .sort

    notes.map { |p| Note.new(p, config.vault) }
  end

  # Every file in _posts/, hand-written ones included.
  def posts
    Dir.glob(File.join(POSTS_DIR, '*.{md,markdown,html}')).sort.map do |path|
      Post.new(path, frontmatter_of(File.read(path)))
    end
  end

  # A post's YAML frontmatter, or {} when the file has none. Deliberately
  # forgiving: a post we cannot parse is one we must not treat as ours.
  def frontmatter_of(text)
    return {} unless text.start_with?("---\n")

    closing = text.index("\n---", 4)
    return {} if closing.nil?

    YAML.safe_load(text[4...closing]) || {}
  rescue Psych::Exception
    {}
  end

  # Pair tagged notes with the posts generated from them, and say what a run
  # would do about each. Reads only.
  def plan(config)
    all = posts
    ours = all.select(&:ours?)
    by_source = ours.to_h { |post| [post.source, post] }

    notes = tagged_notes(config)
    fresh, existing = notes.partition { |note| by_source[note.relative_path].nil? }
    changed, unchanged = existing.partition do |note|
      by_source[note.relative_path].hash != note.hash_of_source
    end

    published = notes.map(&:relative_path).to_set
    Plan.new(
      new_notes: fresh,
      changed: changed.map { |note| [note, by_source[note.relative_path]] },
      unchanged: unchanged,
      orphans: ours.reject { |post| published.include?(post.source) },
      handwritten: all.reject(&:ours?)
    )
  end

  # "Status of vibe coded apps" -> "Status Of Vibe Coded Apps". Only the first
  # letter of each word is touched, never the rest, so ModernBERT and PG come
  # through as written rather than as Modernbert and Pg.
  def title_case(text)
    text.split(/(\s+)/).map { |word| word.sub(/\A[[:alpha:]]/, &:upcase) }.join
  end

  # The same rule `rake post` uses, so a hand-made and a published post are
  # named alike.
  def slugify(text)
    text.downcase.gsub(/[^\w]+/, '-').gsub(/\A-+|-+\z/, '')
  end

  # An Obsidian tag: '#' then a letter, so '# Heading' and '#1234' are safe.
  TAG = %r{\#[[:alpha:]][\w/-]*}

  # The note's text as a post body: tags removed, blank lines tidied. Tags carry
  # no meaning for a reader and several notes end on a line of them.
  def strip_tags(text)
    removed = []
    fenced = false

    body = text.lines.map { |line|
      if line.match?(/\A\s*(```|~~~)/)
        fenced = !fenced
        next line
      end
      next line if fenced

      tags = line.scan(TAG)
      next line if tags.empty?

      removed.concat(tags)
      stripped = line.gsub(TAG, '')
      # A line that was nothing but tags goes entirely, rather than leaving a
      # blank where it stood.
      next nil if stripped.strip.empty?

      # Close the gap a tag left mid-sentence, without eating the indent.
      indent = stripped[/\A[ \t]*/]
      (indent + stripped.lstrip.gsub(/[ \t]{2,}/, ' ')).rstrip + "\n"
    }.compact.join

    [body.gsub(/\n{3,}/, "\n\n").strip + "\n", removed]
  end

  ATX_HEADING = /\A(\#{1,6})(\s)/

  # The layout renders the title as the page's only h1, so a note that has an
  # H1 of its own would show two. Shift the whole outline down one level to make
  # room, leaving notes that already start at ## exactly as they are. H6 has
  # nowhere to go and stays put.
  def demote_headings(text)
    return text unless outside_code_fences(text).lines.any? { |line| line.match?(/\A\#\s/) }

    fenced = false
    text.lines.map { |line|
      if line.match?(/\A\s*(```|~~~)/)
        fenced = !fenced
        next line
      end
      next line if fenced

      line.sub(ATX_HEADING) { "#{'#' * [::Regexp.last_match(1).length + 1, 6].min}#{::Regexp.last_match(2)}" }
    }.join
  end

  # Where copied attachments live, under the post's own slug so two notes
  # embedding differently-named files never tread on each other.
  IMAGES_DIR = File.join(ROOT, 'images', 'posts')

  # An Obsidian embed, `![[file.png]]` or `![[file.png|400]]`, and a plain
  # markdown image whose target is not a URL.
  # Vault filenames contain spaces, so the target runs to the closing paren
  # rather than to the first space.
  WIKI_EMBED = /!\[\[([^\]|]+)(?:\|[^\]]*)?\]\]/
  MD_IMAGE = /!\[([^\]]*)\]\(\s*(?!\w+:)([^)"]+?)\s*(?:"[^"]*")?\)/

  Attachment = Struct.new(:from, :to, :url, keyword_init: true)

  # Find every file a note embeds, work out where it should land in the repo,
  # and rewrite the body to point at it. An embed with no file extension is a
  # note transclusion, not an attachment, so it is reported and left alone.
  def rewrite_embeds(body, note, config, slug)
    copies = []
    warnings = []

    rewrite = lambda do |target, alt|
      if File.extname(target).empty?
        warnings << "transcluded note left as written: #{target}"
        next nil
      end

      source = resolve_attachment(target, note, config)
      if source.nil?
        warnings << "attachment not found in vault: #{target}"
        next nil
      end

      name = "#{slugify(File.basename(target, '.*'))}#{File.extname(target).downcase}"
      copies << Attachment.new(
        from: source,
        to: File.join(IMAGES_DIR, slug, name),
        url: "/images/posts/#{slug}/#{name}"
      )
      "![#{alt}](/images/posts/#{slug}/#{name})"
    end

    # Markdown images first: the wiki pass emits markdown, and rescanning its
    # own output would chase links that point into the repo rather than the
    # vault.
    body = body.gsub(MD_IMAGE) do
      alt = ::Regexp.last_match(1)
      rewrite.call(::Regexp.last_match(2), alt) || ::Regexp.last_match(0)
    end
    body = body.gsub(WIKI_EMBED) { rewrite.call(::Regexp.last_match(1).strip, '') || ::Regexp.last_match(0) }

    [body, copies.uniq(&:to), warnings]
  end

  # Obsidian resolves a bare filename by searching the whole vault, so this
  # does too: alongside the note first, then vault root, then by basename.
  def resolve_attachment(target, note, config)
    direct = [File.expand_path(target, File.dirname(note.path)), File.join(config.vault, target)]
    direct.find { |path| File.file?(path) } || attachment_index(config)[File.basename(target)]
  end

  def attachment_index(config)
    @attachment_index ||= Dir.glob(File.join(config.vault, '**', '*'), File::FNM_DOTMATCH)
                             .reject { |p| p.end_with?('.md') || File.directory?(p) }
                             .reject { |p| p.split(File::SEPARATOR).any? { |part| part.start_with?('.') } }
                             .sort
                             .reverse # so the first of a duplicate basename wins
                             .to_h { |p| [File.basename(p), p] }
  end

  # The finished post file for a note: frontmatter, then the cleaned body.
  def render(note, config, slug)
    body, removed = strip_tags(demote_headings(note.read))
    body, attachments, warnings = rewrite_embeds(body, note, config, slug)

    frontmatter = {
      'layout' => 'post',
      'title' => title_case(note.title),
      SOURCE_KEY => note.relative_path,
      HASH_KEY => note.hash_of_source
    }
    [+"#{YAML.dump(frontmatter)}---\n\n#{body}", removed, attachments, warnings]
  end

  # Write a post to disk. Every write in this file goes through here, and this
  # is the one place that refuses to touch a hand-written post: an existing file
  # must already carry the source key, and must claim the note we are writing.
  def write_post(path, text, note)
    if File.exist?(path)
      existing = frontmatter_of(File.read(path))
      if existing[SOURCE_KEY].nil?
        abort "Refusing to overwrite hand-written post: #{File.basename(path)}"
      elsif existing[SOURCE_KEY] != note.relative_path
        abort "Refusing to overwrite #{File.basename(path)}, which belongs to #{existing[SOURCE_KEY]}"
      end
    end

    File.write(path, text)
    path
  end

  # Every reason this run must not start, worked out before a single file is
  # written, so a refusal never leaves the run half-done. `write_post` repeats
  # the check as a last line of defence.
  def conflicts(plan, today: Date.today)
    plan.new_notes.filter_map do |note|
      path = new_post_path(note, today: today)
      next unless File.exist?(path)

      claimed = frontmatter_of(File.read(path))[SOURCE_KEY]
      if claimed.nil?
        "#{File.basename(path)} is a hand-written post, and #{note.relative_path} wants that name"
      elsif claimed != note.relative_path
        "#{File.basename(path)} belongs to #{claimed}, and #{note.relative_path} wants that name"
      end
    end
  end

  # Republish a note into the post it already owns, keeping that post's filename
  # -- and so its date and URL -- exactly as it is.
  def update(note, post, config)
    text, removed, attachments, warnings = render(note, config, slug_of(post.filename))
    write_post(post.path, text, note)
    [copy_attachments(attachments), removed, warnings]
  end

  # Publish a note that has no post yet.
  def create(note, config, today: Date.today)
    path = new_post_path(note, today: today)
    text, removed, attachments, warnings = render(note, config, slug_of(File.basename(path)))
    write_post(path, text, note)
    [path, copy_attachments(attachments), removed, warnings]
  end

  # Copy in the attachments a post needs, skipping any whose bytes already
  # match so a rerun touches nothing it does not have to.
  def copy_attachments(attachments)
    attachments.select { |a|
      next false if File.exist?(a.to) && FileUtils.identical?(a.from, a.to)

      FileUtils.mkdir_p(File.dirname(a.to))
      FileUtils.cp(a.from, a.to)
      true
    }
  end

  # The slug inside a post filename: 2026-08-29-a-title.md -> a-title
  def slug_of(filename)
    File.basename(filename, '.*').sub(/\A\d{4}-\d{2}-\d{2}-/, '')
  end

  # Where a note first lands. The date is today, and never moves again.
  def new_post_path(note, today: Date.today)
    File.join(POSTS_DIR, "#{today.strftime('%Y-%m-%d')}-#{slugify(note.title)}.md")
  end

  # The text with fenced code blocks blanked out, so patterns cannot match
  # inside them. Line count is preserved; only content is dropped.
  def outside_code_fences(text)
    fenced = false
    text.lines.map { |line|
      if line.match?(/\A\s*(```|~~~)/)
        fenced = !fenced
        "\n"
      else
        fenced ? "\n" : line
      end
    }.join
  end
end
