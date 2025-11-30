defmodule Mcp.Ai.KnowledgeBase do
  use Ash.Resource,
    domain: Mcp.Ai,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "knowledge_bases"
    repo Mcp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :description]
    end

    update :update do
      accept [:name, :description]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :description, :string do
      allow_nil? true
    end

    attribute :reseller_id, :uuid do
      allow_nil? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :documents, Mcp.Ai.Document

    belongs_to :tenant, Mcp.Platform.Tenant do
      allow_nil? true # Nil for Platform-level
    end

    belongs_to :merchant, Mcp.Platform.Merchant do
      allow_nil? true
    end
  end
end

