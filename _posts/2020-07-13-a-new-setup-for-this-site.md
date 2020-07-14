---
layout: post
title: Dokku powered personal hub
---

{{ page.title }}
================

<p class="meta">07 May, 2020</p>

Last July 4th weekend I took some time to redo the setup for sent-hil.com. Previously it was Jekyll app running on Github pages. For the amount of blogging I did and traffic it received, it was more than enough. However I wanted to convert sent-hil.com to be a hub for different apps. My first attempt was to use AWS ECS to deploy dockers containers, but after couple days of struggling I gave up. I tried GCP, which was more fruitful, but ultimately I ran into some technical issues.

At that point I gave up wth a hosted solution and started looking around for a DIY solution and ultimately found [dokku](http://dokku.viewdocs.io/dokku/). It took couple hours to figure it out and this is the [result of it](https://github.com/sent-hil/sent-hil.com)

The repo contains the following folders:

* terraform - contains terraform scripts to bring up a VPC with RDS and EC2 instance.
* blog - Jekyll app that powers the root [sent-hil.com](sent-hil.com) (public).
* graph - [Hasura](https://hasura.io) app (private).
* stats - [Goatcounter](https://www.goatcounter.com) app (private) for analytics.

To deploy I do `git push dokku master`.

## Downsides

This setup is horizontally challenged. dokku has some support for K8/Nomad, but it seems experiemental and I couldn't find documentation to get started. This setup will last me for a long time. Worst case I will vertically scale the instance.

Overrall I'm pretty happy with the setup. It's fairly easy to manage, cheap and I can always ssh into the instance to debug. That's something I sorely missed when trying to work with the hosted solutions.
