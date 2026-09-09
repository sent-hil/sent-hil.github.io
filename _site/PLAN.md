# Publish the 3D bookshelf as a blog post

### What we're doing

Copy the bookshelf app from `~/play/home-design/bookshelf` into this repo as static files under
`bookshelf/`, and add a post whose only content is the `<virtual-bookshelf>` element. Jekyll copies
a plain directory into `_site` untouched, so a file copy is the whole import. No Node, no rake task.

Before the copy, shrink the payload in the source repo: swap three.js for its minified builds and
resize and recompress the covers and photos. The app's own `theme.css` is dropped. The component
reads its colours and fonts from the host page's CSS variables through its shadow root, and
`css/paprika.css` defines the same variables, so the blog's paprika theme, Inter/Figtree, and dark
mode apply. The component's hard-coded pixel sizes and control styles get replaced with the blog's
tokens so it reads as part of the page.

### Steps

1. In the source repo, replace `vendor/three.core.js` and `vendor/three.module.js` with the
   `.min.js` builds from `node_modules/three/build`, and point the import in `scene.js` and
   `vendor/OrbitControls.js` at `three.module.min.js`. 2.7 MB becomes 0.7 MB. Confirm the
   standalone `index.html` still renders with `python -m http.server`.
2. In the source repo, resize covers to 500px wide max, JPEG quality 82, strip metadata, keep each
   file's name and format so the catalog stays untouched. Resize the two photos to 1824x1368 at
   quality 85. One cover first, compare in the modal, then the batch. Run the app's
   `node scripts/validate.mjs` once to confirm every asset still passes.
3. Copy `bookshelf.js`, `scene.js`, `bookshelf.css`, `assets/`, and `vendor/` into `bookshelf/`.
   Leave out `index.html`, `embed.html`, `theme.css`.
4. `jekyll build`, confirm `_site/bookshelf/` has every file byte-identical.
5. Create `_posts/2026-09-08-my-virtual-bookshelf-built-with-astra.md`, title
   "My virtual bookshelf built with astra", `layout: post`. Body is only
   `<virtual-bookshelf></virtual-bookshelf>` and `<script type="module" src="/bookshelf/bookshelf.js">`.
6. Serve locally and check the post: 3D view, photo view, a book modal, keyboard selection, dark
   mode via the OS toggle.
7. Restyle `bookshelf/bookshelf.css` on the blog's tokens: `--base`, `--sm`, `--xs` in place of
   16px/14px/13px, links with paprika's inset box-shadow underline, hairline borders on buttons and
   selects, the `+` marker on the "Browse all books" summary. One change first, check, then the rest.

### What we're NOT doing

- No Node, npm, package.json, or build step in this repo. Node runs once in the source repo for
  its existing validate script, nothing new is installed.
- No rake task. The copy is a one-time `cp`.
- No iframe embed and no `theme.css`. Direct embed only.
- No prose in the post beyond the element.
- No WebP or format conversion. JPEGs stay JPEG, the three PNGs stay PNG, so the catalog is untouched.
- No changes to `bookshelf.js`, the catalog, or the 3D scene beyond the one import line.
- No edit to `CLAUDE.md`.
- No commit and no push, in either repo. You do that.

### How we'll know it works

1. `du -sh bookshelf/` is about 2.5 MB, down from 9.6 MB.
2. `bundle exec jekyll server`, open the post: the shelf renders in 3D, dragging rotates it,
   clicking a spine opens the modal with a cover that looks sharp at its display size, Escape
   closes it.
3. Toggle the OS to dark mode and reload: stage, controls, and modal turn paprika dark with no
   white patches. Buttons and links look like the rest of the post.
4. `git status` shows `bookshelf/`, one new post, and the matching `_site` output, nothing else.
