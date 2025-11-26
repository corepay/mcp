defmodule Mcp.Platform.DeveloperTenant do
  @moduledoc """
  Join resource for Developer <-> Tenant relationship.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "developer_tenants"
    repo(Mcp.Repo)
  end

  json_api do
    type "developer_tenant"

    primary_key do
      keys([:developer_id, :tenant_id])
      delimiter "~"
    end
  end

  actions do
    defaults [:read, :destroy, :create, :update]
  end

  attributes do
    attribute :status, :atom do
      constraints one_of: [:active, :inactive]
      default :active
    end

    attribute :permissions, :map do
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :developer, Mcp.Platform.Developer do
      primary_key? true
      allow_nil? false
    end

    belongs_to :tenant, Mcp.Platform.Tenant do
      primary_key? true
      allow_nil? false
    end
  end
end
