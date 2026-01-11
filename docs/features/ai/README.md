# AI & Vector Embeddings

## Overview

The MCP Platform integrates AI capabilities directly into the core architecture
using **pgvector** for embeddings, **AshAi** for orchestration, **LangChain**
for LLM interactions, and **Apache AGE** for graph relationships.

## Current Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Vector Embeddings (pgvector) | ✅ Production | HNSW index, cosine similarity |
| Document Resource | ✅ Production | Multi-tenant scoped |
| KnowledgeBase Resource | ✅ Production | Tenant/Merchant/Reseller scoped |
| Embedding Service | ✅ Production | Ollama + OpenRouter fallback |
| Chat Domain | ✅ Production | Full conversation system |
| LangChain + Tool Calling | ✅ Production | AnalyzeDocument, ConsultExpert |
| Chat LiveView | ✅ Production | Real-time streaming |
| Graph Context (AGE) | ✅ Production | Tenant-isolated Cypher |
| GraphRAG (combined) | 🚧 Planned | Vector + Graph fusion |
| NL → Ash Filters | 🚧 Planned | Natural language queries |
| Portal AI Integration | 🚧 Planned | Merchant/Store dashboards |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AI Layer                                  │
├─────────────────────────────────────────────────────────────────┤
│  Mcp.Ai Domain                                                   │
│  ├── Chat (AshAi prompts)                                       │
│  ├── Document (pgvector embeddings)                             │
│  ├── KnowledgeBase (RAG scoping)                                │
│  └── LlmUsage (tracking)                                        │
├─────────────────────────────────────────────────────────────────┤
│  Mcp.Chat Domain                                                 │
│  ├── Conversation                                               │
│  ├── Message (with tool_calls, tool_results)                    │
│  └── Changes.Respond (LangChain orchestration)                  │
├─────────────────────────────────────────────────────────────────┤
│  Services                                                        │
│  ├── EmbeddingService (Ollama/OpenRouter)                       │
│  ├── VectorStore (pgvector operations)                          │
│  └── SemanticCache                                              │
├─────────────────────────────────────────────────────────────────┤
│  Graph Layer (Apache AGE)                                        │
│  ├── Graph.TenantContext (isolation)                            │
│  └── Platform.Graph (Cypher execution)                          │
└─────────────────────────────────────────────────────────────────┘
```

## Infrastructure

| Service | Purpose | Port |
|---------|---------|------|
| **Ollama** | Local LLM inference | `${OLLAMA_PORT}` (42736) |
| **Open WebUI** | Chat interface for debugging | `${OPEN_WEBUI_PORT}` |
| **PostgreSQL + pgvector** | Vector storage | `${POSTGRES_PORT}` |
| **PostgreSQL + AGE** | Graph database | Same as above |

## Key Resources

### Mcp.Ai.Document

Vector-enabled document storage with automatic embedding:

```elixir
# Create a document (embedding generated separately)
Mcp.Ai.Document.create!(%{
  content: "The quick brown fox jumps over the lazy dog.",
  tenant_id: tenant_id,
  knowledge_base_id: kb_id
})

# Semantic search
Mcp.Ai.Document.search(query_embedding,
  tenant_id: tenant_id,
  similarity_threshold: 0.7
)
```

### Mcp.Ai.KnowledgeBase

Scoped knowledge collections:

```elixir
# Platform-level KB
Mcp.Ai.KnowledgeBase.create!(%{name: "Platform Policies"})

# Tenant-level KB
Mcp.Ai.KnowledgeBase.create!(%{
  name: "Acme Guidelines",
  tenant_id: tenant_id
})

# Merchant-level KB
Mcp.Ai.KnowledgeBase.create!(%{
  name: "Store Procedures",
  merchant_id: merchant_id
})
```

### Mcp.Chat (Conversations)

Full chat system with LangChain:

```elixir
# Messages automatically trigger LLM response via Changes.Respond
# Tools available: AnalyzeDocument, ConsultExpert
```

## Embedding Dimensions

The system uses **1536 dimensions** for compatibility with OpenAI embeddings.
Local Ollama models (768-1024 dim) fall back to OpenRouter for now.

| Model | Dimensions | Provider |
|-------|------------|----------|
| text-embedding-3-small | 1536 | OpenRouter (default) |
| nomic-embed-text | 768 | Ollama (planned) |
| mxbai-embed-large | 1024 | Ollama (planned) |

## Related Docs

- [RAG Developer Guide](../rag/developer-guide.md)
- [Graph RAG Implementation](../../implement/graph/graph-rag-implementation.md)
- [AshAi Strategy](../../implement/ASH_AI_STRATEGY.md)
