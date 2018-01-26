---
layout: post
title: Challenge - use api docs more than Google or Stackoverflow
---

{{ page.title }}
================

<p class="meta">2018-01-16</p>

Few days ago I challenged myself to not use Google or Stackoverflow, but to check the language/api docs whenever I need to lookup something. This is part of my other long running project to remove abstractions and move closer to the core. I'm hoping this lets me better understand the code and be more idiomatic.

For Go, there's https://godoc.org, which is an easily accessible way to browse the library signatures. In Ruby, there's http://ruby-doc.org/ for standard library docs and http://www.rubydoc.info for library specific docs, though I find I use far less, generally I just Google it (especially when it comes to Rails) or I go into the source directly with `bundle open <gem>`.

Luckily for Ruby and other languages there's [Dash](https://kapeli.com/dash). Dash helps you navigate docus of different languages with just a keyboard. For standard libraries, Dash is now my go to source, for libraries it's less than ideal. I've been [experimenting](https://github.com/sent-hil/go-dashgen) with auto generating docs per project that can be used in Dash, but haven't made much progress yet. Will keep you posted.
