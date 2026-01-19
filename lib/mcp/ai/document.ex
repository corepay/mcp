defmodule Mcp.Ai.Document do
  @moduledoc """
  Represents a document in the AI system.
  """
  use Ash.Resource,
    domain: Mcp.Ai,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAi, AshArchival, AshOban],
    authorizers: [Ash.Policy.Authorizer]

  alias Mcp.Ai.OpenAiEmbeddingModel

  require Ash.Query

  policies do
    policy action_type(:read) do
      authorize_if expr(tenant_id == ^actor(:tenant_id))
    end

    policy action_type(:create) do
      authorize_if expr(not is_nil(^actor(:tenant_id)))
    end

    policy action_type(:update) do
      authorize_if expr(tenant_id == ^actor(:tenant_id))
    end

    policy action_type(:destroy) do
      authorize_if expr(tenant_id == ^actor(:tenant_id))
    end

    bypass action(:ash_ai_update_embeddings) do
      authorize_if AshAi.Checks.ActorIsAshAi
    end
  end

  postgres do
    table "documents"
    repo(Mcp.Repo)
  end

  vectorize do
    strategy :ash_oban
    embedding_model(OpenAiEmbeddingModel)

    full_text do
      text(fn record -> record.content end)
      used_attributes([:content])
      name :embedding
    end
  end

  oban do
    triggers do
      trigger :ash_ai_update_embeddings do
        action :ash_ai_update_embeddings
        queue(:document_vectorizer)
        worker_module_name(:update_embeddings)
        scheduler_module_name(:update_embeddings_scheduler)
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
      public? true
    end

    attribute :metadata, :map do
      allow_nil? false
      default %{}
      public? true
    end

    attribute :reseller_id, :uuid do
      allow_nil? true
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :knowledge_base, Mcp.Ai.KnowledgeBase do
      allow_nil? true
    end

    belongs_to :tenant, Mcp.Platform.Tenant do
      allow_nil? true
    end

    belongs_to :merchant, Mcp.Platform.Merchant do
      allow_nil? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :content,
        :metadata,
        :merchant_id,
        :reseller_id,
        :knowledge_base_id
      ]

      change set_attribute(:tenant_id, actor(:tenant_id))
    end

    update :update do
      accept [:content, :metadata]
    end

    read :search do
      argument :query, :string, allow_nil?: false

      prepare before_action(fn query, _context ->
                case OpenAiEmbeddingModel.generate([query.arguments.query], []) do
                  {:ok, [search_vector]} ->
                    Ash.Query.filter(
                      query,
                      expr(vector_cosine_distance(embedding, ^search_vector) < 0.3)
                    )
                    |> Ash.Query.sort(
                      asc: expr(vector_cosine_distance(embedding, ^search_vector))
                    )

                  {:error, error} ->
                    Ash.Query.add_error(query, error)
                end
              end)
    end

    update :ash_ai_update_embeddings do
      primary? false
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
    define :search, action: :search, args: [:query]
  end
end
