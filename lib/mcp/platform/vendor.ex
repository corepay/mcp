defmodule Mcp.Platform.Vendor do
  @moduledoc """
  Vendor resource (Tenant-scoped).
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshArchival]

  postgres do
    table "vendors"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  json_api do
    type "vendor"

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

    attribute :name, :string do
      allow_nil? false
    end

    attribute :service_type, :string

    attribute :contact_name, :string
    attribute :contact_email, :string
    attribute :contact_phone, :string

    attribute :address, :map

    attribute :status, :atom do
      constraints one_of: [:active, :inactive]
      default :active
    end

    # Enhanced Fields
    attribute :tax_form_status, :atom do
      constraints one_of: [:w9_received, :w9_pending, :not_required]
    end

    attribute :payment_terms, :atom do
      constraints one_of: [:net15, :net30, :net60, :due_on_receipt]
    end

    attribute :service_category, :string

    attribute :performance_rating, :integer do
      constraints min: 1, max: 5
    end

    attribute :active_contracts, :map, default: %{}

    timestamps()
  end

  relationships do
    belongs_to :merchant, Mcp.Platform.Merchant do
      primary_key? true
      allow_nil? false
    end

    belongs_to :user, Mcp.Accounts.User

    many_to_many :stores, Mcp.Platform.Store do
      through Mcp.Platform.VendorStore
      source_attribute_on_join_resource :vendor_id
      destination_attribute_on_join_resource :store_id
    end
  end
end
