defmodule Mcp.Webhooks.Endpoint do
  use Ash.Resource,
    domain: Mcp.Webhooks,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "webhook_endpoints"
    repo Mcp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:url, :secret, :events, :tenant_id, :merchant_id]
    end

    update :update do
      accept [:url, :secret, :events, :enabled]
    end

    read :by_tenant do
      argument :tenant_id, :uuid, allow_nil?: false
      filter expr(tenant_id == ^arg(:tenant_id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :url, :string do
      allow_nil? false
    end

    attribute :secret, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :events, {:array, :string} do
      allow_nil? false
      default []
    end

    attribute :enabled, :boolean do
      allow_nil? false
      default true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :tenant, Mcp.Platform.Tenant do
      allow_nil? true
    end

    belongs_to :merchant, Mcp.Platform.Merchant do
      allow_nil? true
    end
  end
end
