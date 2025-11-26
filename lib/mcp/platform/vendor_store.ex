defmodule Mcp.Platform.VendorStore do
  @moduledoc """
  Join resource for Vendor <-> Store relationship.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "vendors_stores"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  json_api do
    type "vendor_store"

    primary_key do
      keys([:vendor_id, :store_id])
      delimiter "~"
    end
  end

  actions do
    defaults [:read, :destroy, :create, :update]
  end

  attributes do
    attribute :assigned_at, :utc_datetime_usec do
      default &DateTime.utc_now/0
      allow_nil? false
    end
  end

  relationships do
    belongs_to :vendor, Mcp.Platform.Vendor do
      primary_key? true
      allow_nil? false
    end

    belongs_to :store, Mcp.Platform.Store do
      primary_key? true
      allow_nil? false
    end
  end
end
