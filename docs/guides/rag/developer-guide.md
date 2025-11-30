# RAG Developer Guide

## Architecture

The RAG system in MCP consists of three main components:

1. **Storage Layer**: `KnowledgeBase` and `Document` resources backed by
   PostgreSQL and `pgvector`.
2. **Graph Layer**: `Mcp.Platform.Graph` backed by **Apache AGE** for storing
   and querying complex relationships.
3. **Embedding Layer**: `Mcp.Ai.EmbeddingService` which generates vector
   embeddings for text using Ollama or OpenRouter.
4. **Retrieval Layer**: `AgentRunner` which embeds queries, searches for
   relevant documents, and injects context.

## Implementation Details

### Embedding Service

The `Mcp.Ai.EmbeddingService` handles the generation of vector embeddings. It
supports:

- **Ollama**: Using local models like `nomic-embed-text`.
- **OpenRouter**: Using cloud models like `openai/text-embedding-3-small`.

The service ensures that embeddings match the vector column dimensions (1536).

### Vector Search

We use the `pgvector` extension for efficient similarity search. The
`Mcp.Ai.Document` resource includes a `search` action that filters by:

- **Cosine Similarity**: Finding vectors close to the query vector.
- **Tenant/Merchant/Reseller**: Enforcing strict multi-tenancy.

```elixir
# Example Search
{:ok, documents} = Mcp.Ai.Document.search(embedding, tenant_id: current_tenant.id)
```

### Context Injection

The `AgentRunner` automatically handles the RAG workflow:

1. Checks if the `AgentBlueprint` has `knowledge_base_ids`.
2. Embeds the user's last message.
3. Searches for relevant documents in the specified Knowledge Bases (scoped by
   Tenant).
4. Appends the content of the top matching documents to the system prompt.

### GraphRAG (Hybrid Retrieval)

In addition to vector search, the platform supports **GraphRAG** using Apache
AGE. This allows agents to answer questions requiring multi-hop reasoning or
relationship analysis (e.g., "Find merchants similar to X who also have high
risk scores").

- **Module**: `Mcp.Platform.Graph`
- **Query Language**: Cypher
- **Integration**: Agents can be equipped with tools to execute Cypher queries
  or pre-defined graph lookups.

## Configuration

To enable RAG, ensure:

2. `OLLAMA_BASE_URL` is configured if using local embeddings.
3. `OPENROUTER_API_KEY` is set if using cloud embeddings.

## Best Practices

- **Chunking**: Keep document content concise (e.g., paragraphs) for better
  retrieval accuracy.
- **Metadata**: Use the `metadata` map on `Document` to store source URLs, page
  numbers, or other context.
- **Scoping**: Always set the `tenant_id` (or `merchant_id`/`reseller_id`) to
  prevent data leakage between tenants.
