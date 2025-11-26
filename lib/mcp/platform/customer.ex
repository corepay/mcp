defmodule Mcp.Platform.Customer do
  @moduledoc """
  Customer resource (Tenant-scoped).
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    # , Mcp.Graph.Extension]
    extensions: [AshJsonApi.Resource]

  # use Mcp.Graph.Extension

  postgres do
    table "customers"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  json_api do
    type "customer"

    primary_key do
      keys([:merchant_id, :id])
      delimiter "~"
    end
  end

  actions do
    defaults [:read, :destroy, :create, :update]
  end

  attributes do
    attribute :id, :uuid do
      primary_key? true
      allow_nil? false
      default &Ash.UUID.generate/0
    end

    attribute :email, :ci_string do
      allow_nil? false
    end

    attribute :first_name, :string
    attribute :last_name, :string
    attribute :phone, :string

    attribute :shipping_address, :map
    attribute :billing_address, :map
    attribute :saved_payment_methods, {:array, :map}, default: []

    attribute :total_orders, :integer, default: 0
    attribute :total_spent, :decimal, default: 0

    attribute :status, :atom do
      constraints one_of: [:active, :suspended, :deleted]
      default :active
    end

    # Enhanced Fields
    attribute :marketing_preferences, :map, default: %{}
    attribute :loyalty_tier, :string
    attribute :loyalty_points, :integer, default: 0

    attribute :tags, {:array, :string}
    attribute :last_active_at, :utc_datetime
    attribute :source, :string

    attribute :gdpr_consent, :boolean, default: false
    attribute :gdpr_consent_at, :utc_datetime

    timestamps()
  end

  relationships do
    belongs_to :merchant, Mcp.Platform.Merchant do
      primary_key? true
      allow_nil? false
    end

    belongs_to :user, Mcp.Accounts.User

    many_to_many :stores, Mcp.Platform.Store do
      through Mcp.Platform.CustomerStore
      source_attribute_on_join_resource :customer_id
      destination_attribute_on_join_resource :store_id
    end
  end

  # graph do
  #   node_type :customer
  #   graph_relationship :merchant, :belongs_to, Mcp.Platform.Merchant
  #   graph_relationship :stores, :many_to_many, Mcp.Platform.Store
  # end
end
