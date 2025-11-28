defmodule Mcp.Platform.PayfacConfiguration do
  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "payfac_configurations"
    repo Mcp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:provider, :provider_api_key, :auto_approve_threshold, :auto_reject_threshold]
      argument :tenant_id, :uuid, allow_nil?: false
      change manage_relationship(:tenant_id, :tenant, type: :append_and_remove)
    end

    update :update do
      primary? true
      accept [:provider, :provider_api_key, :auto_approve_threshold, :auto_reject_threshold]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :provider, :atom do
      constraints one_of: [:complycube, :mock]
      default :mock
    end

    attribute :provider_api_key, :string do
      sensitive? true
    end

    attribute :auto_approve_threshold, :integer do
      default 90
    end

    attribute :auto_reject_threshold, :integer do
      default 40
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Mcp.Platform.Tenant
  end

  code_interface do
    define :create
    define :update
    define :read
    define :destroy
  end
end
