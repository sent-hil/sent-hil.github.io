---
layout: post
title: Single vs Double dash in cli args
---

{{ page.title }}
================

<p class="meta">28 May 2016</p>

> It all depends on the program. Usually "-" is used for 'short' options
> (one-letter, -h), and "--" is used for "long"(er) options (--help).
>
> Short options can usually be combined (so "-h -a" is same as "-ha")

[Source](http://serverfault.com/a/387938)

One exception I found was `find` which uses single dash, but full names like
`find /usr/src -name CVS`.

-- is not in POSIX, but GNU recommends it and it makes for better readability.
