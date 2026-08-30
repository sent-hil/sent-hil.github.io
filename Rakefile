require 'time'

# Take from http://stackoverflow.com/a/25745685
desc 'create a new draft post'
task :post do
	title = ENV['title']
  unless title
    puts "Please set 'title' env variable and try again"
    exit(1)
  end

	slug  = "#{Date.today}-#{title.downcase.gsub(/[^\w]+/, '-')}"
	file  = File.join(File.dirname(__FILE__), '_posts', slug + '.md')

	File.open(file, 'a') do |f|
		f << <<~EOS
			---
			layout: post
			title: #{title}
			---

		EOS
	end

	system("#{ENV['EDITOR']} #{file}")
end

desc 'publish Obsidian notes tagged #post into _posts/'
task :obsidian do
  require_relative 'scripts/obsidian_publish'

  dry_run = ENV['dry_run'] == 'true' || ARGV.include?('--dry-run')
  config = ObsidianPublish::Config.load
  plan = ObsidianPublish.plan(config)

  puts "vault: #{config.vault}"
  puts "tag:   ##{config.tag}"
  puts

  conflicts = ObsidianPublish.conflicts(plan)
  if conflicts.any?
    conflicts.each { |c| puts "  CONFLICT  #{c}" }
    abort "\nNothing written. Rename the note, or delete the post if it is no longer wanted."
  end

  plan.new_notes.each do |note|
    if dry_run
      puts "  new       #{note.relative_path} -> #{File.basename(ObsidianPublish.new_post_path(note))}"
      next
    end

    path, copied, removed, warnings = ObsidianPublish.create(note, config)
    puts "  new       #{note.relative_path} -> #{File.basename(path)}"
    puts "            stripped #{removed.uniq.join(' ')}" if removed.any?
    copied.each { |a| puts "            copied #{a.url}" }
    warnings.each { |w| puts "            note: #{w}" }
  end

  plan.changed.each do |note, post|
    if dry_run
      puts "  changed   #{note.relative_path} -> #{post.filename}"
      next
    end

    copied, removed, warnings = ObsidianPublish.update(note, post, config)
    puts "  changed   #{note.relative_path} -> #{post.filename}"
    puts "            stripped #{removed.uniq.join(' ')}" if removed.any?
    copied.each { |a| puts "            copied #{a.url}" }
    warnings.each { |w| puts "            note: #{w}" }
  end

  plan.unchanged.each  { |n|    puts "  unchanged #{n.relative_path}" }
  plan.orphans.each    { |p|    puts "  orphan    #{p.filename} (note no longer tagged)" }

  puts if plan.new_notes.any? || plan.changed.any? || plan.unchanged.any? || plan.orphans.any?
  puts "DRY RUN -- nothing was written." if dry_run
  puts "#{plan.new_notes.size} new, #{plan.changed.size} changed, " \
       "#{plan.unchanged.size} unchanged, #{plan.orphans.size} orphaned. " \
       "#{plan.handwritten.size} hand-written posts left alone."
end
