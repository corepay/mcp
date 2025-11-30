# RAG API Reference

## Resources

### Mcp.Ai.KnowledgeBase

Represents a collection of documents.

**Attributes**:

- `id`: UUID (Primary Key)
- `name`: String (Required)
- `description`: String
- `tenant_id`: UUID (Optional, for scoping)
- `merchant_id`: UUID (Optional, for scoping)
- `reseller_id`: UUID (Optional, for scoping)

**Relationships**:

- `documents`: HasMany `Mcp.Ai.Document`

**Actions**:

- `create`: Create a new Knowledge Base.
- `update`: Update name or description.
- `destroy`: Delete a Knowledge Base.

### Mcp.Ai.Document

Represents a chunk of text with a vector embedding.

**Attributes**:

- `id`: UUID (Primary Key)
- `content`: Text (Required)
- `metadata`: Map (Default: `%{}`)
- `embedding`: Vector (1536 dimensions)
- `knowledge_base_id`: UUID (Required)
- `tenant_id`: UUID (Optional, for scoping)
- `merchant_id`: UUID (Optional, for scoping)
- `reseller_id`: UUID (Optional, for scoping)

**Actions**:

- `create`: Create a document and generate its embedding.
- `search`: Find documents similar to a query vector.
  - Arguments: `query_embedding`, `similarity_threshold`, `tenant_id`,
    `merchant_id`.

## Services

### Mcp.Ai.EmbeddingService

**Functions**:

- `generate_embedding(text, provider \\ :ollama)`: Returns `{:ok, [float]}` or
  `{:error, reason}`.
