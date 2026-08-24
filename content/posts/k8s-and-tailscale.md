---
date: "2026-08-24T18:49:44+02:00"
draft: true
title: Tailscale and Kubernetes
summary: "Exposing Kubernetes workloads via Tailscale"
tags:
  - kubernetes
  - tailscale
  - homelab
  - networking
---

I've been using Tailscale since 2020 now, and I've recently migrated all (most) of my homelab applications to a Kubernetes cluster I put together (God bless [Marktplaats](https://marktplaats.nl) and the time SSDs and RAM were cheaper).
As I'm the only user of most applications I run, and I want to be able to reach these services from outside of my home network, I pretty soon landed on the [Tailscale Kubernetes Operator](https://tailscale.com/docs/kubernetes-operator) as the way to securely achieve this.

As much as I love Tailscale, though, I am not a huge fan of having to use the Magic DNS domain names they provide out of the box when using their operator.

In this article, I will go through my current setup, which allows me to achieve secure and private access to applications running on my homelab, using my custom domain, and valid TLS certificates.

## Setup description

### Requirements

- A Kubernetes cluster (ARM is supported!)
- [Helm](https://helm.sh/)
- A domain name (I got mine, `dmhosted.com`, through [Cloudflare](https://www.cloudflare.com/products/registrar/))
- [cert-manager](https://cert-manager.io/) installed on your cluster
- A [Tailscale](https://tailscale.com/) account
- One (or more) custom DNS server for your Tailnet (see [how to](https://tailscale.com/docs/reference/dns-in-tailscale))
- The Tailscale Kubernetes Operator installed on your cluster; I followed the [official guide](https://tailscale.com/docs/kubernetes-operator/install-operator), using Helm

Extras (optional):

- [ExternalDNS](https://kubernetes-sigs.github.io/external-dns/v0.15.0/) - nice to have, allows to automatically create DNS records on your server; the setup is out of the scope of this article and depends on what your DNS server runs on

### Rationale

The Tailscale Kubernetes Operator provides the `ProxyGroup` CRD which is used to define Tailscale proxies routing traffic from your Tailnet to a specific K8s Service.

`ProxyGroup`s can be used in 2 ways:

Additionally, this guide assumes that an instance of Traefik is already deployed on the cluster, as this was my case.

## Benefits of This Setup

> - Allows to expose safely things like internal dashboards (Traefik, Longhorn)
> - Good way to learn K8s networking fundamentals

---

## Links and Credits

-
