defmodule Mcp.Payments.Refund do
  @moduledoc """
  Ash resource representing a refund on a charge.
  """

  use Ash.Resource,
    domain: Mcp.Payments,
    data_layer: AshPostgres.DataLayer

  @derive {Jason.Encoder,
           only: [
             :id,
             :amount,
             :currency,
             :status,
             :provider_ref,
             :reason,
             :inserted_at,
             :updated_at
           ]}

  postgres do
    table "payment_refunds"
    repo(Mcp.Repo)
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      argument :charge_id, :uuid, allow_nil?: false

      accept [:amount, :reason, :currency]

      change manage_relationship(:charge_id, :charge, type: :append_and_remove)
    end

    update :succeed do
      accept [:provider_ref]
      change set_attribute(:status, :succeeded)
    end

    update :fail do
      change set_attribute(:status, :failed)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :amount, :integer, allow_nil?: false
    attribute :currency, :string, allow_nil?: false

    attribute :status, :atom do
      constraints one_of: [:pending, :succeeded, :failed]
      default :pending
    end

    attribute :provider_ref, :string
    attribute :reason, :string

    timestamps()
  end

  relationships do
    belongs_to :charge, Mcp.Payments.Charge
  end

  code_interface do
    define :create, action: :create
    define :read, action: :read
    define :get_by_id, action: :read, get_by: [:id], get?: true
    define :succeed, action: :succeed
    define :fail, action: :fail
  end
end
