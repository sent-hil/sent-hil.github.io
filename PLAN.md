# Publish Obsidian notes tagged `#post`

### What we're doing

A `rake obsidian` task that reads a configurable Obsidian vault, finds every note tagged `#post`,
and writes each one into `_posts/` as a Jekyll post, copying any embedded images into the repo along
the way. Run it again and notes that changed in Obsidian get rewritten in place, keeping their
original filename and URL. Posts written by hand stay untouched forever: the task only ever writes a
file carrying an `obsidian_source:` key in its frontmatter, so the 24 existing posts are
structurally out of reach. It never commits or pushes — that stays manual.

Title comes from the note's filename. The date is the day the task first publishes the note, and
is frozen from then on, so a post never moves once it is out.

### Steps

1. ~~DONE~~ Add `scripts/publish.yml` (vault path, tag name, `OBSIDIAN_VAULT` env override) and the scan that
   finds tagged notes. Word-boundary match so `#postgres` and `#to-be-mochi` do not count. Prints
   the list, writes nothing.
2. ~~DONE~~ Read `_posts/` and pair each note with its post via the `obsidian_source:` key. Classify every
   note as new, changed, or unchanged, and every post as ours or hand-written. Still writes nothing.
3. ~~DONE~~ Convert one note to a post: frontmatter (`layout`, `title`, `obsidian_source`, `obsidian_hash`),
   body cleaned of the `#post` line and other stray inline tags, written to
   `_posts/YYYY-MM-DD-slug.md` where the date is today — the day it is first published. Demote a
   note's headings one level (`#` becomes `##`) when it contains an H1, since the layout already
   renders the title as the page's only h1.
4. ~~DONE~~ Attachments: resolve `![[file.png]]` and `![](some/path.png)` by basename anywhere in the vault,
   copy into `images/posts/<slug>/` under a slugified filename, and rewrite the embed to
   `![](/images/posts/<slug>/file.png)`. An `![[…]]` with no file extension is a note transclusion,
   not an image — report it and leave the line alone.
5. ~~DONE~~ The update path: rewrite a changed note into its existing file, keeping its original publish
   date and filename so the URL never moves, and re-copy any attachment whose bytes changed. Assert that a file without
   `obsidian_source` is never opened for writing.
6. ~~DONE~~ Reporting and wiring: `--dry-run`, a summary of added / updated / unchanged / skipped, exposed as
   `rake obsidian`. Fix `rake post` and `scripts/new_blog_post.go`, which still generate the old
   `{{ page.title }}` + `<p class="meta">` format.
7. ~~DONE~~ Run it for real on the one tagged note, build, and look at the result.

### What we're NOT doing

- No commit and no push. You do that.
- No unpublishing. Removing the tag in Obsidian reports the orphan; it deletes neither post nor
  copied images.
- No note transclusion. `![[Weekly Goals/2026-W30]]` stays as written and is reported.
- No image processing — no resizing, recompression, or `|400` size hints. Copy the bytes as they
  are; the stylesheet already caps width at the column.
- No watching, cron, or git hook. You run the task when you want to publish.
- No Obsidian plugin or API — plain filesystem reads, vault never written to.
- No re-dating. A post keeps its first publish date however often the note changes afterwards.
- No touching the existing hand-written posts, under any circumstance.

### How we'll know it works

1. Run it: "Status of vibe coded apps 3 months in" appears in `_posts/`, renders at localhost, and
   `git status` shows one new post and no other post modified.
2. Add an image to that note in Obsidian, run again: the file lands in `images/posts/<slug>/`, the
   post shows it, and the post's filename and URL have not moved.
3. Edit a hand-written post, run again: the edit survives untouched and the report says so.
