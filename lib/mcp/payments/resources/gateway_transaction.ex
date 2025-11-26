defmodule Mcp.Payments.GatewayTransaction do
  @moduledoc """
  Ash resource representing a raw gateway transaction.
  """

  use Ash.Resource,
    domain: Mcp.Payments,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "payment_gateway_transactions"
    repo(Mcp.Repo)
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      argument :charge_id, :uuid, allow_nil?: false

      accept [:provider, :provider_ref, :type, :amount, :currency, :status, :raw_response]

      change manage_relationship(:charge_id, :charge, type: :append_and_remove)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :provider, :atom, allow_nil?: false
    attribute :provider_ref, :string

    attribute :type, :atom do
      constraints one_of: [:authorize, :capture, :refund, :void]
    end

    attribute :amount, :integer
    attribute :currency, :string

    attribute :status, :atom do
      constraints one_of: [:success, :failure, :pending]
    end

    attribute :raw_response, :map

    timestamps()
  end

  relationships do
    belongs_to :charge, Mcp.Payments.Charge
  end

  code_interface do
    define :create, action: :create
  end
end
