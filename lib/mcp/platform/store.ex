defmodule Mcp.Platform.Store do
  @moduledoc """
  Store (Sub-brand) resource.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshArchival]

  postgres do
    table "stores"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  json_api do
    type "store"
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :merchant_id,
        :slug,
        :name,
        :routing_type,
        :subdomain,
        :custom_domain,
        :primary_mid_id,
        :status
      ]
    end

    update :update do
      primary? true
      accept [:name, :routing_type, :subdomain, :custom_domain, :primary_mid_id, :status]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :slug, :string do
      allow_nil? false
    end

    attribute :name, :string do
      allow_nil? false
    end

    attribute :routing_type, :atom do
      constraints one_of: [:path, :subdomain]
      default :path
    end

    attribute :subdomain, :string
    attribute :custom_domain, :string

    # Enhanced Fields
    # {lat: ..., lng: ...}
    attribute :geo_location, :map
    attribute :tax_nexus, {:array, :string}

    attribute :store_type, :atom do
      constraints one_of: [:physical, :online, :hybrid, :popup]
    end

    attribute :store_manager_name, :string
    attribute :store_phone, :string
    attribute :store_email, :string

    attribute :settings, :map do
      default %{}
    end

    attribute :branding, :map do
      default %{}
    end

    attribute :fallback_mid_ids, {:array, :uuid}

    attribute :status, :atom do
      constraints one_of: [:active, :suspended, :draft]
      default :active
    end

    timestamps()
  end

  relationships do
    belongs_to :merchant, Mcp.Platform.Merchant
    belongs_to :primary_mid, Mcp.Platform.MID
  end

  code_interface do
    define :read
    define :create
    define :update
    define :destroy
    define :get_by_id, action: :read, get_by: [:id]
  end
end
