defmodule Mcp.Underwriting.DocumentAnalysis do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "document_analyses"
    repo Mcp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:status, :markdown_content, :structured_data, :provider, :merchant_id]
    end

    update :update do
      accept [:status, :markdown_content, :structured_data, :provider]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      constraints [one_of: [:pending, :processing, :completed, :failed]]
      default :pending
      allow_nil? false
    end

    attribute :markdown_content, :string do
      allow_nil? true
    end

    attribute :structured_data, :map do
      allow_nil? true
    end

    attribute :provider, :atom do
      constraints [one_of: [:marker, :chandra]]
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :merchant, Mcp.Platform.Merchant do
      allow_nil? false
    end
  end
end
