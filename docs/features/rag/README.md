# Retrieval-Augmented Generation (RAG)

## Overview

RAG enhances LLM responses with domain-specific knowledge fetched from the
platform's knowledge bases. The MCP Platform combines **vector search**
(pgvector) with **graph relationships** (Apache AGE) for intelligent retrieval.

## Current Implementation Status

| Component | Status | Location |
|-----------|--------|----------|
| KnowledgeBase resource | ✅ Built | `lib/mcp/ai/resources/knowledge_base.ex` |
| Document resource | ✅ Built | `lib/mcp/ai/document.ex` |
| Vector similarity search | ✅ Built | HNSW index, cosine similarity |
| Multi-tenant scoping | ✅ Built | Tenant/Merchant/Reseller isolation |
| Graph tenant context | ✅ Built | `lib/mcp/graph/tenant_context.ex` |
| GraphRAG (vector+graph) | 🚧 Planned | Documented in implement/graph/ |
| Auto context injection | 🚧 Planned | AgentRunner integration |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     RAG Pipeline                                 │
├─────────────────────────────────────────────────────────────────┤
│  1. Query Input                                                  │
│     └── User question or search term                            │
├─────────────────────────────────────────────────────────────────┤
│  2. Embedding Generation                                         │
│     └── EmbeddingService.generate_embedding(query)              │
├─────────────────────────────────────────────────────────────────┤
│  3. Vector Search                                                │
│     └── Document.search(embedding, tenant_id: t, threshold: 0.7)│
├─────────────────────────────────────────────────────────────────┤
│  4. (Planned) Graph Expansion                                    │
│     └── Find related entities via Apache AGE                    │
├─────────────────────────────────────────────────────────────────┤
│  5. Context Assembly                                             │
│     └── Rank and combine results for LLM prompt                 │
├─────────────────────────────────────────────────────────────────┤
│  6. LLM Generation                                               │
│     └── LangChain with injected context                         │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Create a Knowledge Base

```elixir
kb = Ash.create!(Mcp.Ai.KnowledgeBase, %{
  name: "Underwriting Guidelines",
  description: "Standard operating procedures for risk assessment",
  tenant_id: tenant_id
})
```

### 2. Add Documents

```elixir
# Generate embedding first
{:ok, embedding} = Mcp.Ai.EmbeddingService.generate_embedding(content)

# Create document with embedding
Ash.create!(Mcp.Ai.Document, %{
  content: "The maximum debt-to-income ratio for FHA loans is 43%.",
  embedding: embedding,
  knowledge_base_id: kb.id,
  tenant_id: tenant_id
})
```

### 3. Search Documents

```elixir
# Generate query embedding
{:ok, query_embedding} = Mcp.Ai.EmbeddingService.generate_embedding("FHA loan requirements")

# Semantic search
results = Ash.read!(Mcp.Ai.Document, action: :search, args: [
  query_embedding: query_embedding,
  tenant_id: tenant_id,
  similarity_threshold: 0.7
])
```

## Scoping Hierarchy

Knowledge bases can be scoped at multiple levels:

| Scope | Use Case |
|-------|----------|
| Platform (nil tenant) | Platform-wide policies, shared knowledge |
| Tenant | Tenant-specific procedures, compliance rules |
| Merchant | Store-specific guidelines, product info |
| Reseller | Partner-specific documentation |

```elixir
# Scoping is automatic via relationships
kb_platform = %{name: "Platform Policies"}
kb_tenant = %{name: "Acme Policies", tenant_id: acme_id}
kb_merchant = %{name: "Store Manual", merchant_id: store_id}
```

## Graph Enhancement (Planned)

The platform supports Apache AGE for relationship-aware retrieval:

```elixir
# Current: Basic graph queries
Mcp.Graph.TenantContext.execute_cypher(tenant_id, "relationships", """
  MATCH (m:Merchant)-[:SIMILAR_TO]->(other:Merchant)
  WHERE m.id = $merchant_id
  RETURN other
""")

# Planned: Combined vector + graph search
Mcp.RAG.GraphEnhanced.search_with_relationships(tenant_id, query, [
  expand_graph: true,
  relationship_depth: 2
])
```

## Related Docs

- [AI Overview](../ai/README.md)
- [Graph RAG Implementation](../../implement/graph/graph-rag-implementation.md)
- [Developer Guide](developer-guide.md)
