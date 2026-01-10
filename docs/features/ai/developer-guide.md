# AI Developer Guide

## Introduction
This guide covers how to implement AI features using the `Mcp.Ai` domain.

## Local Development Environment

### Open WebUI (Developer Interface)
The project includes **Open WebUI** running on `http://localhost:${OPEN_WEBUI_PORT}`. Check your `.env` file for the configured port (default is often `53000` or `8080`). This is your "cockpit" for the local AI environment.

**Use Cases:**
1.  **Prompt Engineering**: Test system prompts and user queries to see raw model output before implementing them in Elixir.
2.  **Model Verification**: Ensure the required models (e.g., `llama3`, `mistral`) are pulled and loaded in Ollama.
3.  **Performance Testing**: Gauge the speed of token generation on your local machine.

### AshAi Configuration
The application is configured to talk to Ollama via `config/config.exs`:

```elixir
config :mcp, :ollama,
  model: System.get_env("OLLAMA_MODEL", "llama3"),
  base_url: System.get_env("OLLAMA_BASE_URL") || "http://localhost:#{System.get_env("OLLAMA_PORT", "11434")}"
```

Ensure your `OLLAMA_BASE_URL` is reachable from the Phoenix application (usually `http://localhost:11434` or `http://ollama:11434` inside Docker).

## Vector Embeddings

### 1. Architecture
We use the `pgvector` extension in Postgres.
- **Dimensions**: 1536 (OpenAI text-embedding-ada-002) or 768 (Llama 2).
- **Distance Metric**: Cosine similarity (`<=>`).

### 2. The `Mcp.Ai.Document` Resource
This is the primary interface for vector operations.

**Attributes**:
- `content`: The raw text.
- `embedding`: The vector representation.
- `ref_id`: UUID of the associated resource.
- `ref_type`: String identifier of the associated resource type.

### 3. Implementing Search
To find similar documents:

```elixir
def search(query_text, limit \\ 5) do
  # 1. Generate embedding for query
  {:ok, query_vector} = Mcp.Ai.generate_embedding(query_text)

  # 2. Search database
  Mcp.Ai.Document
  |> Ash.Query.sort(vector_cosine_distance(:embedding, query_vector))
  |> Ash.Query.limit(limit)
  |> Mcp.Ai.read!()
end
```

### 4. Indexing
Ensure your vector column has an index for performance.

```sql
CREATE INDEX ON ai.documents USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
```

## Best Practices
- **Chunking**: Split long documents into smaller chunks before embedding to improve search accuracy.
- **Async Processing**: Generate embeddings in background jobs (Oban) to avoid blocking user requests.
