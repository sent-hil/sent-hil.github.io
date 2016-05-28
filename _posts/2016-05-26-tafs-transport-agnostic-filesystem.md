---
layout: post
title: tafs - Transport Agnostic FileSystem
---

{{ page.title }}
================

<p class="meta">26 May 2016</p>

> tafs or Transport Agnostic File System is an interface for building virtual filesystems on top of FUSE. The purpose of this library is to make it easier to build virtual filesystems that mounts different domains as a filesystem, ie. [s3fs](https://github.com/s3fs-fuse/s3fs-fuse) or [gcsfuse](https://github.com/GoogleCloudPlatform/gcsfuse).
>
> #### Why?
>
> This is mainly a learning project for me to better understand the filesystems, encryption and FUSE itself. Originally the idea was to build an [tahoe-lafs](https://www.tahoe-lafs.org/trac/tahoe-lafs) inspired filesystem in Go, but it has evolved into what you see here.
>
> #### Goals
>
> * Transport Agnostic
> * Versioned
> * Encrypted
> * Shareable with public and private groups
>
> #### Transport ideas
>
> * Web browser - transport that lets you browse web with individual files being webpages, uses [Readability](https://readability.com/developers/api/parser)
> * Github - navigated github.com, download repos etc.
> * Tail changes - with above transport, can use `tail -f` to watch for changes in webpages.
> * Notes - with above transport, modify file, ie webpage, to locally save changes.

Source: [https://github.com/sent-hil/tafs](https://github.com/sent-hil/tafs)

After weeks of picking my brain for my next person project, the above is what I have come up with. This project fulfills two of my recent goals: work on an open source project and better understand the tools and technologies.

In my previous job I was also building a FUSE based network filesystem. Although we had shipped a working version, there was a nagging feeling in the back of my mind of not fully understanding how everything worked. This was due to using existing libraries and also being constantly up against deadlines. So once that was over, I promised myself next time I would fully understand all the working pieces. If that means writing my own device driver, so be it. Tight deadlines also meant not having a chance to contribute back to open source as much as I would have liked. This project is the antidote for both of those problems.