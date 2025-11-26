defmodule Mcp.Platform.ResellerTenant do
  @moduledoc """
  Join resource for Reseller <-> Tenant relationship.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "reseller_tenants"
    repo(Mcp.Repo)
  end

  json_api do
    type "reseller_tenant"

    primary_key do
      keys([:reseller_id, :tenant_id])
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

    attribute :contract_details, :map do
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :reseller, Mcp.Platform.Reseller do
      primary_key? true
      allow_nil? false
    end

    belongs_to :tenant, Mcp.Platform.Tenant do
      primary_key? true
      allow_nil? false
    end
  end
end
