# Archyve Test Document

## Introduction

Archyve is a retrieval-augmented generation system. It ingests documents from
sources and makes them searchable.

## Architecture

### Ingestion

Documents flow through [Docling](https://docling-project.github.io) for
extraction, then *chunking*, then embedding.

Each stage is a job:

- extraction, which calls **Docling**
- chunking, which is [structure-aware](https://example.com/chunking)
- embedding

### Retrieval

Retrieval is scoped to a collection and executed as a tool the model calls.

## Conclusion

That is all for now.
