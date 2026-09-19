---
date: "2026-09-16T17:51:30+02:00"
draft: true
title: "How is this blog hosted?"
summary: "How is this blog hosted?"
tags:
  - kubernetes
  - homelab
  - networking
  - cloudflare
---

In this article, I'll go through the set up I am using to generate and host this very blog.

## Generating the blog

I am using [Hugo](https://gohugo.io/) to generate the static website.
I had considered other alternatives, but being Hugo very lightweight (no _Node modules_...) and very fast to build (order of _ms_), I quickly settled on it.
It is also very easy to extend (even for someone like me who never actually wrote any actual frontend code so far).

The website code is on [GitHub](<>), and builds happen in CI/CD (GitHub Worflows).
A new release gets created for every change in the site, including new articles.
[Semantic Release](<>) takes care of automating the tag creation, which are also translated into Docker tags for the container images.

The container itself is just based on [Caddy](<>) (a webserver I had been wanting to try out for the longest time), and it is just exposing the statically-built website.

Deploying the website then just becomes a problem of running the built container _somewhere_, and making it accessible publicly in a secure way.

## Deploying the blog

> [!NOTE] Disclaimer
>
> This setup is _very overkill_ for a static website, but it would not be fun otherwise!

I decided on deploying the container on my homelab, which is running Kubernetes ([K3s]()).

## Where it runs

## Exposing it to the public

## Observability

## Fallback and Replication
