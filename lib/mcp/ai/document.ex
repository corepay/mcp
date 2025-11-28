defmodule Mcp.Ai.Document do
  use Ash.Resource,
    domain: Mcp.Ai,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshArchival]

  postgres do
    table "documents"
    repo(Mcp.Repo)

    custom_indexes do
      # Create an HNSW index for fast similarity search
      # This requires the pgvector extension to be enabled
      index(["embedding vector_cosine_ops"],
        name: "documents_embedding_index",
        using: "hnsw"
      )
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
    end

    attribute :metadata, :map do
      allow_nil? false
      default %{}
    end

    # Vector embedding (1536 dimensions for OpenAI, 768 for Ollama/mxbai-embed-large)
    # We'll use 1536 as a safe default for compatibility, or 768 if we stick to local.
    # Let's use 1536 to be safe.
    attribute :embedding, Mcp.Type.Vector do
      constraints dimensions: 1536
    end

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:content, :metadata, :embedding]
    end

    update :update do
      accept [:content, :metadata, :embedding]
    end

    read :search do
      argument :query_embedding, :vector do
        constraints dimensions: 1536
      end

      argument :similarity_threshold, :float do
        default 0.7
      end

      # Filter by cosine similarity
      filter expr(
               cosine_similarity(embedding, ^arg(:query_embedding)) > ^arg(:similarity_threshold)
             )
    end
  end

  calculations do
    calculate :similarity, :float, expr(cosine_similarity(embedding, ^arg(:query_embedding))) do
      argument :query_embedding, :vector do
        constraints dimensions: 1536
      end
    end
  end

  code_interface do
    domain Mcp.Ai
    define :create, action: :create
    define :search, action: :search, args: [:query_embedding]
  end
end
