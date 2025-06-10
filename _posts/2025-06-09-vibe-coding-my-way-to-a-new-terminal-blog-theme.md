---
layout: post
title: Vibe Coding My Way To A New Terminal Blog Theme
---

# {{ page.title }}

<p class="meta">09 June, 2025</p>

I was very inspired by recent [post](https://x.com/sh_reya/status/1931119169929703827) by [Shreya Shankar](https://x.com/sh_reya/status/1931400666003784008) where she tweeted about vibe coding interfaces to look at the data. In her follow up [post](https://x.com/sh_reya/status/1931400666003784008) she gave some tips about how to get the clean terminal look. Turns out it's as simple as telling Claude 'sleek terminal theme'.

So last night while lying in bed with my phone I told Claude

> I want to build a text introduction site for a developer with some intro text. I want the text to be inside a terminal mimicking a cli. Assume we are using a dark iterm theme in mac. Make the terminal appear in center of screen with plenty of room for it to grow. Let's start with just html and css

The results were way better than I expected:

![](/assets/claude-terminal-developer.png)

I downloaded the resulting html, asked Claude Code to adapt the theme to use in this Jekyll blog. It took a few minutes and about ~$0.40, yes cents. Updating this blog theme was perhaps the last item on my todo list, with Claude it took me about an hour. I just had to clean up few css styles and that's it. I honestly didn't think it woudl work on first try.

Do I care about the quality of this code? Not really. It's a site that got 37 visits last month. I can't imagine doing this for production code though.

I don't know how long before LLMs get good enough to put software engineers out of a job, but it does raise the bar of what someone can create with just a few dollars, enough knowledge to make good choices, and good taste.

It's like when photographers got the ability to see the picture they took on a digital screen. It reduced the feedback cycle between shutter and seeing the photo, and made it accessible to a whole new subset of people. LLMs make writing code accessible to anyone with a computer and few cents.
