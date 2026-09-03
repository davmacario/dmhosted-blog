---
date: "2026-08-31T23:56:52+02:00"
draft: false
title: "Notes Rag"
summary: "Building a RAG for my personal notes (and running it on K8s)"
tags:
  - kubernetes
  - LLM
  - AI
  - markdown
  - RAG
---

Countless words could be spent to explain the superiority of text-based file formats, but I won't bore you with this.
It comes a moment in every digital notetaker's life when searching for specific information in your notes (or _second brain_, as [Obsidian](https://obsidian.md/) nerds like to call it) becomes more and more difficult.

{{< figure
  src="/obsidian-graph.png"
  alt="Obsidian graph view of my notes"
  caption="Obsidian graph view from my notes"
  align="center"
>}}

Additionally, in the age of AI, I encounter more and more the need to be able to easily inject context into conversations based on my knowledge contained in my notes.

Well, it turns out that it is possible to catch two birds with one stone in this case!
And this is all thanks to **Retrieval Augmented Generation** (RAG).
This is by far not a new technique, but it is one that is often underestimated, as its benefits struggle to hold up with the increasing performance of LLMs.

In this article, I'm going to explain why I think RAG still holds up in the _agentic AI era_ of 2026, and how I run one so that I don't have to get lost in my own mess of a "_second brain_".

> [!warning] Disclaimer
>
> There are probably countless, better performing implementations of RAG systems out there.
> I like mine because _I built it_ :)

## Retrieval Augmented Generation in short

RAG is a technique created to automatically inject relevant context into a LLM by querying relevant information of a set of documents using _information retrieval_ techniques.
These technique work by computing a measure of semantical similarity between the user query and a set of text (or other form of media) samples.

The typical method used to perform information retrieval in this context is through vector similarity.
This approach employs vector embeddings obtained by feeding both the samples and the query through the same _text embedding model_ (same type used as input step of an LLM), which is typically a neural network or matrix transformation trained to capture semantical meaning of input text samples onto a latent representation space (the vector space).
Given this, finding text samples close in meaning means finding vectors that are close in space (i.e., which have a high dot product).

### RAG in practice

How RAGs are implemented in practice in computer systems is by means of a _vector database_[^1], used to store all representations of some reference documents (alongside metadata).
Retrieval then consists of taking the user query, embedding it to get the vector representation, and running a vector DB query to get the top _k_ matching vectors and return the associated documents.

In "traditional" RAG systems, when the user interacts with the LLM, their message is used as input for the DB query, and the returned documents are appended to the conversation to be included in the context.

{{< figure
  src="https://upload.wikimedia.org/wikipedia/commons/1/14/RAG_diagram.svg"
  alt="Diagram of a RAG architecture, showing how retrieved documents are merged with the user query into the LLM prompt"
  caption="Typical RAG architecture. Image by [Turtlecrown](https://commons.wikimedia.org/wiki/File:RAG_diagram.svg), via Wikimedia Commons, licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)."
  align="center"
>}}

[^1]: A **vector database** is a database optimized to store and perform operations (particularly, retrieval) on vector fields. Examples include Chroma, Pinecone, but also PostgreSQL with _pgvector_, or (some functionalities of) Elasticsearch.

## RAG meets my Obsidian Vault

For my use case, RAG is an interesting tool, as it would allow me to let LLMs access my own notes automatically, without having to spend time looking the information up myself and copy-pasting it into the conversation.

On paper, this sounds like the ideal solution, but there are some limitations to be considered.

### Solving RAG limitations

The main drawback of a "traditional" RAG implementation is that documents are retrieved regardless of whether they are actually needed.

In most applications of RAG, this is fine, as the reference knowledge base is generally used to "ground" the LLM response.
In my case, though, I would like to "pull in" extra information into a conversation only if needed.

Additionally, for large user queries, the retrieval

This ties into what the main limitation of "textbook" RAG systems is: RAG needs to be implemented in the LLM harness/frontend, as it needs to happen within the conversation itself.
This means that implementing it would require a custom chat interface which performs document retrieval under the hood.
This is not an option, as I don't want to lock myself into a specific implementation of a LLM chat application.

Both of these limitations can be solved by wrapping the RAG retrieval step in a LLM tool, which can then be exposed to the LLM "frontend" using the Model Context Protocol (MCP)[^2].
The LLM can then autonomously decide whether to invoke a tool

[^2]: [MCP](https://modelcontextprotocol.io/docs/2026-07-28/getting-started/intro) is a standard used to extend LLM capabilities by means of tools, exposed through a well-defined interface.

### Implementation

#### Tech stack

- Python 3.14
- [Chroma](https://www.trychroma.com/) as vector DB
- [LlamaIndex](https://www.llamaindex.ai/) for embeddings and DB interaction
  - Using [`sentence-transformers/all-MiniLM-L6-v2`](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2) as embedding model, chosen for its good performance to small footprint balance, as it needed to run on CPU (+ it is an open model).
- [MCP Python SDK](https://py.sdk.modelcontextprotocol.io/)
- Extras include GitPython (Git repo management), Pydantic (data validation)

The code can be found [here](https://github.com/davmacario/notes-rag/).

#### Architecture

<!--TODO: include c4 diagrams (container is most interesting)-->

#### How it works

The RAG runs as an MCP server, which exposes it as a tool over (streamable-)HTTP.
This allows any LLM harness supporting MCP to connect to it and be advertised the tool (I personally use Claude Code and [OpenCode](https://opencode.ai/)).

The tool itself is used to fetch relevant documents given a _query string_ and the _number of desired documents_.
Note that "documents", in this context, refers to _Markdown sections_.
This means that each vector in the DB is associated with one _section_ / _chapter_ of a file in my notes.
This is also a good way to avoid trying to encode too large pieces of text in one single vector, which, as a rule of thumb, decreases retrieval performance.

This setup delegates to the LLM the choice on whether the conversation actually requires fetching relevant knowledge from the notes, so information is not always retrieved, resulting in better context window usage.
Latest LLMs at the time of writing are also optimized and trained to specifically use tools, which means that they generally have good common sense when it comes to choosing if or which tool to invoke.

## Why not an LLM knowledge bases?

The topic of this article might seem related to the concept of [LLM Knowledge Bases](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f), but there are quite a few reasons why this does not (personally) fit.

First of all, I enjoy writing.
I want all my notes to be written by me; that is how I make sure that the information in them is what I actually know/think.

Secondly, I am also the main user of my notes.
Having a RAG system is just a "nice to have" in making it easier for LLMs to be grounded on my actual knowledge.
On the other hand, this system also allows me to easily look information up, as the MCP server also returns the names of the files the relevant information was obtained from.

Third, I don't want to be dependent on a single specific LLM, or on LLM performance in general, especially with pricing changing on the regular and user experience being generally variable between models.
