# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Jekyll blog site that powers sent-hil.com. It's a fork of mojombo's original Jekyll blog with custom modifications. The site uses Jekyll with GitHub Pages deployment through the _site directory.

## Development Commands

### Setup and Development
```bash
bundle                           # Install Ruby dependencies
bundle exec jekyll server       # Start development server
jekyll build                     # Build site to _site directory
```

### Creating New Posts
Two methods available:

**Go script (preferred):**
```bash
go run scripts/new_blog_post.go -title='Title of my New Post'
```

**Rake task (alternative):**
```bash
title='My Post Title' rake post
```

Both create files in `_posts/` with today's date and proper frontmatter.

### Deployment
```bash
git push origin master          # Deploy to GitHub Pages
```

## Architecture

### Jekyll Configuration
- Uses kramdown markdown processor with rouge syntax highlighting
- SEO tags plugin enabled
- Excludes scripts, CHECK, and Readme.md from build
- Custom scope for resources path

### Site Structure
- `_layouts/default.html`: Main site template with header, footer, and navigation
- `_layouts/post.html`: Post wrapper that uses default layout
- `_posts/`: Blog posts in markdown format with YYYY-MM-DD-title.md naming
- `_site/`: Generated site files (included in commits for GitHub Pages)
- `css/`: Stylesheets (screen.css for layout, syntax.css for code highlighting)

### Blog Post Format
Posts use Jekyll frontmatter:
```yaml
---
layout: post
title: Post Title
---
```

### Pre-commit Hook
The repository includes a pre-commit hook that:
1. Runs `jekyll build`
2. Adds `_site` files to the commit

This ensures the built site is always committed alongside source changes.

### Analytics
Site includes GoatCounter analytics integration in the default layout.