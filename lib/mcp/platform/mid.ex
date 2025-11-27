defmodule Mcp.Platform.MID do
  @moduledoc """
  MID (Merchant ID / Payment Gateway Account) resource.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshArchival]

  postgres do
    table "mids"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  json_api do
    type "mid"
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :merchant_id,
        :mid_number,
        :gateway_id,
        :gateway_credentials,
        :status,
        :is_primary,
        :daily_limit,
        :monthly_limit
      ]
    end

    update :update do
      primary? true

      accept [
        :gateway_credentials,
        :status,
        :is_primary,
        :daily_limit,
        :monthly_limit,
        :routing_rules
      ]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :mid_number, :string do
      allow_nil? false
    end

    attribute :gateway_id, :uuid do
      allow_nil? false
    end

    attribute :gateway_credentials, :map do
      allow_nil? false
    end

    attribute :routing_rules, :map do
      default %{}
    end

    attribute :status, :atom do
      constraints one_of: [:active, :suspended, :testing]
      default :active
    end

    attribute :is_primary, :boolean do
      default false
    end

    # Enhanced Fields
    attribute :processor_name, :string
    attribute :acquirer_name, :string
    attribute :batch_time, :time

    attribute :supported_card_brands, {:array, :string}
    attribute :currencies, {:array, :string}
    attribute :fraud_settings, :map, default: %{}

    attribute :daily_limit, :decimal
    attribute :monthly_limit, :decimal

    attribute :total_volume, :decimal do
      default 0
    end

    attribute :total_transactions, :integer do
      default 0
    end

    timestamps()
  end

  relationships do
    belongs_to :merchant, Mcp.Platform.Merchant

    # Virtual relationship to global Finance Account
    has_one :account, Mcp.Finance.Account do
      domain Mcp.Finance
      source_attribute :id
      destination_attribute :mid_id
      no_attributes? true
    end
  end

  code_interface do
    define :read
    define :create
    define :update
    define :destroy
    define :get_by_id, action: :read, get_by: [:id]
  end
end
