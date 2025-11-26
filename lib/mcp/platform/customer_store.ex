defmodule Mcp.Platform.CustomerStore do
  @moduledoc """
  Join resource for Customer <-> Store relationship.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "customers_stores"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  json_api do
    type "customer_store"

    primary_key do
      keys([:customer_id, :store_id])
      delimiter "~"
    end
  end

  actions do
    defaults [:read, :destroy, :create, :update]
  end

  attributes do
    attribute :joined_at, :utc_datetime_usec do
      default &DateTime.utc_now/0
      allow_nil? false
    end
  end

  relationships do
    belongs_to :customer, Mcp.Platform.Customer do
      primary_key? true
      allow_nil? false
    end

    belongs_to :store, Mcp.Platform.Store do
      primary_key? true
      allow_nil? false
    end
  end
end
