# AI & Vector Embeddings

## Overview

The MCP Platform integrates advanced AI capabilities directly into the core
architecture. By leveraging **pgvector** for vector embeddings and **AshAi** for
orchestration, we enable semantic search, recommendation systems, and
intelligent document processing.

## Architecture

The AI subsystem is built on a dual-layer architecture designed for both robust
application integration and developer productivity.

### 1. Application Layer: AshAi

- **Purpose**: Programmatic integration with business logic.
- **Role**: Handles embedding generation, semantic search, and RAG
  (Retrieval-Augmented Generation) workflows within the Elixir application.
- **Key Component**: `Mcp.Ai` Domain.

### 2. Developer Tooling: Open WebUI

- **Purpose**: Interactive debugging and prompt engineering.
- **Role**: Provides a ChatGPT-like interface to interact directly with the
  local LLM (Ollama). Use this to test prompts, verify model behavior, and debug
  "hallucinations" without writing code.
- **Access**: Available at `http://localhost:${OPEN_WEBUI_PORT}` (check `.env`
  for port).

### Infrastructure

- **Ollama**: Local LLM inference engine (port `${OLLAMA_PORT}`, default
  `42736`).
- **Postgres + pgvector**: Vector database for storing embeddings (port
  `${POSTGRES_PORT}`, default `41789`).
- **Open WebUI**: Admin interface for Ollama (port `${OPEN_WEBUI_PORT}`, default
  `53000` or `8080`).

## Key Capabilities

### 1. Vector Embeddings

- **Semantic Search**: Search for content based on meaning rather than just
  keywords.
- **Similarity Matching**: Find related documents, products, or users.
- **High Performance**: Uses `ivfflat` or `hnsw` indexes for fast approximate
  nearest neighbor search.

### 2. Document Management (`Mcp.Ai.Document`)

- **Unified Storage**: A central resource for storing text content and its
  vector representation.
- **Polymorphic Associations**: Link AI documents to any other resource
  (Merchant, Transaction, Message).
- **Automatic Embedding**: Content is automatically embedded upon creation or
  update.

## Quick Start

### Creating a Document

```elixir
Mcp.Ai.Document.create!(%{
  content: "The quick brown fox jumps over the lazy dog.",
  ref_type: "message",
  ref_id: "msg_123"
})
```

### Searching

```elixir
Mcp.Ai.Document.search("animal jumping", limit: 5)
```

## Related Resources

- [Retrieval-Augmented Generation (RAG)](../rag/README.md)
- [Multi-Tenancy](../multi-tenancy/README.md) (Infrastructure support)
