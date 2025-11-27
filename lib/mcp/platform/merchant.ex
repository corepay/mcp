defmodule Mcp.Platform.Merchant do
  @moduledoc """
  Merchant resource.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshPostgres.DataLayer,
      AshJsonApi.Resource,
      AshJsonApi.Resource,
      Mcp.Graph.Extension
    ]

  use Mcp.Graph.Extension

  # paper_trail do
  # end

  postgres do
    table "merchants"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  json_api do
    type "merchant"
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :slug,
        :business_name,
        :dba_name,
        :subdomain,
        :custom_domain,
        :business_type,
        :ein,
        :website_url,
        :description,
        :address_line1,
        :address_line2,
        :city,
        :state,
        :postal_code,
        :country,
        :phone,
        :support_email,
        :reseller_id,
        :plan,
        :status,
        :risk_level
      ]
    end

    update :update do
      primary? true

      accept [
        :business_name,
        :dba_name,
        :subdomain,
        :custom_domain,
        :business_type,
        :ein,
        :website_url,
        :description,
        :address_line1,
        :address_line2,
        :city,
        :state,
        :postal_code,
        :country,
        :phone,
        :support_email,
        :plan,
        :status,
        :risk_level
      ]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :slug, :string do
      allow_nil? false
    end

    attribute :business_name, :string do
      allow_nil? false
    end

    attribute :dba_name, :string

    attribute :subdomain, :string do
      allow_nil? false
    end

    attribute :custom_domain, :string

    attribute :business_type, :atom do
      constraints one_of: [:sole_proprietor, :llc, :corporation, :partnership, :nonprofit]
    end

    attribute :ein, :string
    attribute :website_url, :string
    attribute :description, :string

    attribute :address_line1, :string
    attribute :address_line2, :string
    attribute :city, :string
    attribute :state, :string
    attribute :postal_code, :string

    attribute :country, :string do
      default "US"
    end

    attribute :phone, :string
    attribute :support_email, :string

    attribute :plan, :atom do
      constraints one_of: [:starter, :professional, :enterprise]
      default :starter
    end

    attribute :status, :atom do
      constraints one_of: [:active, :suspended, :pending_verification, :closed]
      default :active
    end

    attribute :settings, :map do
      default %{}
    end

    attribute :branding, :map do
      default %{}
    end

    attribute :max_stores, :integer do
      default 0
    end

    attribute :max_products, :integer
    attribute :max_monthly_volume, :decimal

    attribute :risk_level, :atom do
      constraints one_of: [:low, :medium, :high]
      default :low
    end

    attribute :kyc_verified_at, :utc_datetime_usec

    attribute :verification_status, :atom do
      constraints one_of: [:pending, :verified, :rejected]
      default :pending
    end

    # Enhanced Fields
    attribute :mcc, :string

    attribute :tax_id_type, :atom do
      constraints one_of: [:ein, :ssn]
    end

    attribute :kyc_status, :atom do
      constraints one_of: [:pending, :verified, :rejected, :manual_review]
      default :pending
    end

    attribute :kyc_documents, :map, default: %{}, sensitive?: true

    attribute :timezone, :string, default: "UTC"
    attribute :default_currency, :string, default: "USD"
    attribute :operating_hours, :map, default: %{}

    attribute :risk_score, :integer

    attribute :risk_profile, :atom do
      constraints one_of: [:low, :medium, :high]
      default :low
    end

    attribute :processing_limits, :map, default: %{}

    timestamps()
  end

  # graph do
  #   node_type :merchant
  #   graph_relationship :reseller, :belongs_to, Mcp.Platform.Reseller
  #   graph_relationship :stores, :has_many, Mcp.Platform.Store
  # end
  relationships do
    belongs_to :reseller, Mcp.Platform.Reseller
    has_many :stores, Mcp.Platform.Store

    # Virtual relationship to global Finance Account
    has_one :account, Mcp.Finance.Account do
      domain Mcp.Finance
      source_attribute :id
      destination_attribute :merchant_id
      no_attributes? true
    end

    has_many :mids, Mcp.Platform.MID
  end

  code_interface do
    define :read
    define :create
    define :update
    define :destroy
    define :get_by_id, action: :read, get_by: [:id]
  end
end
