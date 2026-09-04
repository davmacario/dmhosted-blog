---
date: "2026-08-31T23:56:52+02:00"
draft: false
title: "Notes RAG"
summary: "Building a RAG for my personal notes (and running it on K8s)"
tags:
  - kubernetes
  - LLM
  - AI
  - markdown
  - RAG
  - MCP
---

Countless words could be spent to explain the superiority of text-based file formats, but I won't bore you with this.
The one benefit that's relevant to this article is that plain text can be searched by anything: `grep`, your editor, a shell one-liner.
The catch is that all of those search for _strings_, and there comes a moment in every digital notetaker's life when you remember the idea but not the words you wrote it in.
From then on, finding things in your notes (or _second brain_, as [Obsidian](https://obsidian.md/) nerds like to call it) gets harder and harder.

{{< figure
  src="/obsidian-graph.png"
  alt="Obsidian graph view of my notes"
  caption="Obsidian graph view of (part of) my notes"
  align="center"
>}}

Furthermore, with AI usage increasing, I often feel the need to automatically inject context into conversations, based on my knowledge contained in my notes.

Well, it turns out that it is possible to kill two birds with one stone in this case!
And this is all thanks to **Retrieval Augmented Generation** (RAG).\
RAG is by no means a new technique, but it is one that is increasingly underestimated, as its benefits struggle to keep up with the growing capability of LLMs.

In this article, I'm going to explain why I think RAG still holds up in the _agentic AI era_ (for my specific use case), and how I run one so that I don't have to get lost in my own mess of a "_second brain_".

> [!warning] Disclaimer
>
> There are probably countless, better performing implementations of RAG systems out there.
> I like mine because _I built it_ and it runs on my own hardware :)

## Retrieval Augmented Generation in short

RAG is a technique created to automatically inject relevant context into an LLM by querying relevant information from a set of documents using _information retrieval_ techniques.
These techniques work by computing a measure of semantic similarity between the user query and a set of text (or other form of media) samples.

The typical method used to perform information retrieval in this context is through vector similarity.
This approach employs vector embeddings obtained by feeding both the samples and the query through the same _text embedding model_, which is typically a neural network or matrix transformation trained to capture semantic meaning of input text samples onto a latent representation space (the vector space).
Given this, finding text samples close in meaning comes down to finding vectors that are close in space (which have, e.g., high _cosine similarity_).

### RAG in practice

In practice, RAG systems are built around a _vector database_[^1], used to store all representations of some reference documents (alongside metadata).
Retrieval then consists of taking the user query, embedding it to get the vector representation, and running a vector DB query to get the top _k_ matching vectors and return the associated documents.

In "traditional" RAG systems, when the user interacts with the LLM, their message is used as input for the DB query, and the returned documents are appended to the conversation to be included in the context.

{{< figure
  src="https://upload.wikimedia.org/wikipedia/commons/1/14/RAG_diagram.svg"
  alt="Diagram of a RAG architecture, showing how retrieved documents are merged with the user query into the LLM prompt"
  caption="Typical RAG architecture. Image by [Turtlecrown](https://commons.wikimedia.org/wiki/File:RAG_diagram.svg), via Wikimedia Commons, licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)."
  align="center"
>}}

[^1]: A **vector database** is a database optimized to store and perform operations (particularly, retrieval) on vector fields. Examples include Chroma and Pinecone, but also PostgreSQL with _pgvector_, or (some functionalities of) Elasticsearch.

## RAG meets my Obsidian Vault

For my use case, RAG is an interesting tool, as it would allow me to let LLMs access my own notes automatically, without having to spend time looking the information up myself and copy-pasting it into the conversation.

On paper, this sounds like the ideal solution, but there are some limitations to be considered.

### Solving RAG limitations

The main drawback of a "traditional" RAG implementation is that documents are retrieved regardless of whether they are actually needed.

In most applications of RAG, this is fine, as the reference knowledge base is generally used to "ground" the LLM response.
In my case, though, I would like to "pull in" extra information into a conversation only if needed.

Additionally, retrieval performance (in terms of relevance of the results) is negatively affected by long user queries, especially on reference data that contains sparse bits of information, like personal notes.
Ideally, the queried string is something resembling a Google search (few words, mostly keywords).\
This is actually not usually a problem in most RAG systems, as retrieval performance is very good on state-of-the-art embedding models, but for my use case I wanted retrieval to be very lightweight and run on CPU only, so that I could easily containerize it and run it on my homelab (currently no GPUs there).

> [!TIP]
>
> Decrease in retrieval performance with longer queries happens because embedding the whole query with a single vector inevitably "averages out" nuances.

The main limitation of "textbook" RAG systems, however, is that they need to be implemented in the LLM harness/frontend, as RAGs need to be always queried during conversations.
This means that implementing it would require a custom chat interface which performs document retrieval under the hood.
This is not an option, as I don't want to lock myself into a specific implementation of an LLM chat application.

All these limitations can be solved by wrapping the RAG retrieval step in an LLM tool, which can then be exposed to the LLM "frontend" using the Model Context Protocol (MCP)[^2].
The LLM can then autonomously decide whether to invoke a tool based on the conversation.

[^2]: [MCP](https://modelcontextprotocol.io/docs/2026-07-28/getting-started/intro) is a standard used to extend LLM capabilities by means of tools, exposed through a well-defined interface.

### Implementation

#### Tech stack

- Python 3.14
- [Chroma](https://www.trychroma.com/) as vector DB
- [LlamaIndex](https://www.llamaindex.ai/) for embeddings and DB interaction
  - Using [`sentence-transformers/all-MiniLM-L6-v2`](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2) as embedding model, chosen for its good performance to small footprint balance, as it needed to run on CPU (+ it is an open model).
- [MCP Python SDK](https://py.sdk.modelcontextprotocol.io/)
- Extras include GitPython (Git repo management), Pydantic (data validation)

The code can be found [here](https://github.com/davmacario/notes-rag/) - _feel free to contribute!_

#### Architecture

{{< figure
  src="/notes-rag-c2-container.svg"
  alt="Container diagram - notes-rag"
  caption="Container Diagram (from C4 model) of the application"
  align="center"
>}}

#### How it works

The RAG runs as an **MCP server**, which exposes it as a tool over (streamable-)HTTP.
This allows any LLM harness supporting MCP to connect to it and discover the tool (I personally use Claude Code and [OpenCode](https://opencode.ai/)).

The tool itself is used to fetch relevant documents given a _query string_ and the _number of desired documents_.
Note that "documents", in this context, refers to _Markdown sections_.
This means that each vector in the DB is associated with one _section_ / _chapter_ of a file in my notes.
This is also a good way to avoid trying to encode too large pieces of text in one single vector, which, as a rule of thumb, decreases retrieval performance.

The documents come from my own notes, which are stored on a hosted Git platform, and get fetched on a schedule.
Whenever a change is found, the vector DB is rebuilt, and hot-swapped.

This setup delegates to the LLM the choice on whether the conversation actually requires fetching relevant knowledge from the notes, so information is not always retrieved, resulting in better context window usage.
Latest LLMs at the time of writing are also optimized and trained to specifically use tools, which means that they generally have good _common sense_ when it comes to choosing if or which tool to invoke.

Also, being _free_ to use tools, the LLM can choose to perform multiple calls to the MCP server, for example if needing to look up information from different topics.

#### Usage in practice

The application itself is [containerized](https://github.com/davmacario/notes-rag/pkgs/container/notes-rag), and it can run on virtually any host, as it is built to take the smallest footprint possible.
In my case, it [runs on Kubernetes](https://github.com/davmacario/dmhosted-infra/tree/main/kubernetes/apps/notes-rag), and it is exposed to my VPN (Tailscale) only, over HTTPS[^3].

> [!NOTE]
>
> The MCP server runs on my own infra, while the LLM can, in principle, be whatever (as long as the harness used supports MCP).

To add this MCP server to Claude Code, I can just run:

```bash
claude mcp add --transport http notes-rag https://notes-rag.internal.dmhosted.com/mcp
```

Claude will then have access to the tool, including a description of it and the parameters each call requires.

{{< figure
  src="/notes-rag-mcp-1.png"
  alt="Notes-RAG MCP in Claude (1)"
  caption="Notes-RAG MCP in Claude Code"
  align="center"
>}}

{{< figure
  src="/notes-rag-mcp-2.png"
  alt="Notes-RAG MCP in Claude (2)"
  caption="Notes-RAG MCP in Claude Code - Tool"
  align="center"
>}}

[^3]: See [this other article](/posts/k8s-and-tailscale) for an explanation how.

## Why not an LLM knowledge base?

The topic of this article might seem related to the concept of [LLM Knowledge Bases](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f), but there are quite a few reasons why this does not (personally) fit.

As defined by Andrej Karpathy, an **LLM Knowledge Base** is essentially a note taking / information system where the user dumps information to an LLM, which is then tasked to categorize, rewrite, and store it in a structured way.
The outcome of this is a wiki, where the LLM acts as the main way to both add and retrieve information.

First of all, I enjoy writing.
I want all my notes to be written by me; that is how I make sure that the information in them is what I actually know/think.

Secondly, I am also the main user of my notes.
Having a RAG system is just a "nice to have" in making it easier for LLMs to be grounded on my actual knowledge.
At the same time, this system also lets me easily look information up, as the MCP server also returns the names of the files the relevant information was obtained from.

Third, I don't want to be dependent on a single specific LLM, or on LLM performance in general, especially with pricing changing on the regular and user experience being generally variable between models.

## Conclusions

Having ran and used the RAG for some time now, I can proudly say I already have been able to save myself a lot of effort that I would have otherwise spent in searching my own notes, not to mention the fact that I could find bits of information I had completely forgot I had.
For a good while, before deciding to take on this project, I had let AI agents "free" on my notes directory, which typically required several tool calls before being able to find the right information, and sometimes even resulted in important documents being overlooked.
Another important aspect is that my notes don't have to necessarily live on my machine, as the MCP server is accessible remotely.

Additionally, from a personal perspective, I find myself not keen on letting AI models "take the lead" (call it being a _control freak_ or _impostor syndrome_), which means I still want to be the author and have full control on what my notes contain.
Under this light, my RAG implementation is a way to establish the dependency of the AI agents on my own knowledge, allowing me to still be in charge, and the AI to "learn" from what I know, often resulting in the ability to inject my point of view in conversations with LLMs.

There are still many features that I would like to implement in the future (incremental indexing, real-time fetch of new notes, ...), and the solution is currently far from perfect, but I learned a lot building it, and I haven't gone back to searching my notes by hand since..

---

## Links and Credits

- [Code](https://github.com/davmacario/notes-rag/)
- [Infra (Kubernetes)](https://github.com/davmacario/dmhosted-infra/tree/main/kubernetes/apps/notes-rag)
- [LLM Knowledge Bases](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
