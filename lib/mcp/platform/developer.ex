defmodule Mcp.Platform.Developer do
  @moduledoc """
  Developer (API Partner) resource.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]



  postgres do
    table "developers"
    repo(Mcp.Repo)
  end

  json_api do
    type "developer"
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :company_name,
        :contact_name,
        :contact_email,
        :contact_phone,
        :webhook_url,
        :webhook_secret,
        :status
      ]
    end

    update :update do
      primary? true

      accept [
        :company_name,
        :contact_name,
        :contact_email,
        :contact_phone,
        :webhook_url,
        :webhook_secret,
        :status
      ]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :company_name, :string do
      allow_nil? false
    end

    attribute :contact_name, :string do
      allow_nil? false
    end

    attribute :contact_email, :string do
      allow_nil? false
    end

    attribute :contact_phone, :string

    # Operational Contacts
    attribute :technical_contact_email, :string
    attribute :admin_contact_email, :string
    attribute :support_phone, :string

    # Integration Settings
    attribute :webhook_url, :string
    attribute :webhook_secret, :string
    attribute :webhook_events, {:array, :string}, default: []
    attribute :webhook_signing_secret, :string, sensitive?: true
    attribute :app_type, :string, default: "public"

    # Business Settings
    attribute :revenue_share_percentage, :decimal, default: 0.00
    attribute :payout_settings, :map, default: %{}, sensitive?: true

    attribute :api_quota_daily, :integer, default: 1000
    attribute :api_quota_monthly, :integer, default: 10000

    attribute :status, :atom do
      constraints one_of: [:active, :suspended, :pending]
      default :active
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Mcp.Accounts.User
    has_many :resellers, Mcp.Platform.Reseller
  end

  code_interface do
    define :read
    define :create
    define :update
    define :destroy
    define :get_by_id, action: :read, get_by: [:id]
  end
end
