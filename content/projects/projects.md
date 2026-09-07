---
date: "2026-09-07T17:55:41+02:00"
draft: false
title: "Projects"
summary: "Projects I worked on"
---

## Homelab (DMHosted)

Currently running **Kubernetes** (K3s) on bare-metal over a **3-node cluster**, hosting both public and private services.
Also including: a NAS for bulk storage, a few Linux hosts running Docker.

Originally started as a single Docker host running in my bedroom in Italy, quickly evolved to several PCs connected over VPN.

_Tech stack_:

- Kubernetes (K3s), Docker
- Linux (Debian, Ubuntu, Fedora, TrueNAS, Raspberry Pi OS)
- Proxmox
- Tailscale
- Cloudflare Tunnels
- Prometheus, Grafana, Loki
- AdGuard Home
- CloudNativePG / PostgreSQL

[Repository (GitHub)](https://github.com/davmacario/dmhosted-infra)

## MDI-LLM

Implementation of **_pipeline parallelism_** for **Large Language Models** developed during my M.Sc. thesis and research work at University of Illinois at Chicago and Politecnico di Torino.
Allows running **LLMs in a distributed fashion** over a network of (small) computers by partitioning model weights across them and employing **distributed computing** techniques to achieve higher throughput when serving multiple queries at once.

[Paper](https://arxiv.org/abs/2505.18164) - awarded _"Best Paper Award"_ at IEEE LANMAN 2025

[Repository (GitHub)](https://github.com/davmacario/mdi-llm)

## FREISA

> "Four-Legged Robot Ensuring Intelligent Sprinkler Automation"

Computer vision-enabled quadruped robot able to automatically detect plants and sprinkle water on them based on the conditions of the leaves.

As part of the team, I implemented the **computer vision** component running **YOLOv8** models on an OAK-D Lite camera, achieving **on-board inference**.

**Grand Prize winner** of the [2023 OpenCV AI Competition](https://www.hackster.io/contests/opencv-ai-competition-2023).

[Repository (GitHub)](https://github.com/B-AROL-O/FREISA)

## Notes-RAG

Implementation of a **RAG** using my own **Markdown notes** as knowledge base, exposed via **MCP** to LLM harnesses.
Currently running on my [Kubernetes cluster](#homelab-dmhosted).

Read more [here](/posts/notes-rag).

[Repository (GitHub)](https://github.com/davmacario/notes-rag)

## nvim-kube-schemas

**Neovim** plugin used to automatically download and cache **YAML schemas** for **Kubernetes CRDs** based on the file contents, exposing the schemas to [Yaml Language Server](https://github.com/redhat-developer/yaml-language-server).

[Repository (GitHub)](https://github.com/davmacario/nvim-kube-schemas)
