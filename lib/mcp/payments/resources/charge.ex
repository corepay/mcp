defmodule Mcp.Payments.Charge do
  @moduledoc """
  Ash resource representing a payment charge.
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
             :provider,
             :provider_ref,
             :failure_reason,
             :captured_at,
             :inserted_at,
             :updated_at
           ]}

  postgres do
    table "payment_charges"
    repo(Mcp.Repo)
  end

  actions do
    defaults [:read, :destroy]

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
    end

    create :create do
      primary? true
      argument :customer_id, :uuid, allow_nil?: false
      argument :payment_method_id, :uuid, allow_nil?: false
      argument :capture, :boolean, default: true

      accept [:amount, :currency, :provider, :provider_ref, :status]

      change manage_relationship(:customer_id, :customer, type: :append_and_remove)
      change manage_relationship(:payment_method_id, :payment_method, type: :append_and_remove)
    end

    update :capture do
      accept []
      change set_attribute(:status, :succeeded)
      change set_attribute(:captured_at, &DateTime.utc_now/0)
    end

    update :fail do
      accept [:failure_reason]
      change set_attribute(:status, :failed)
    end

    update :void do
      accept []
      change set_attribute(:status, :voided)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :amount, :integer, allow_nil?: false
    attribute :currency, :string, allow_nil?: false

    attribute :status, :atom do
      constraints one_of: [:pending, :succeeded, :failed, :refunded, :requires_action, :voided]
      default :pending
    end

    # :stripe, :qorpay, etc.
    attribute :provider, :atom, allow_nil?: false
    # ID in the provider's system
    attribute :provider_ref, :string
    attribute :failure_reason, :string
    attribute :captured_at, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :customer, Mcp.Payments.Customer
    belongs_to :payment_method, Mcp.Payments.PaymentMethod
    has_many :refunds, Mcp.Payments.Refund
  end

  code_interface do
    define :create, action: :create
    define :read, action: :read
    define :get_by_id, action: :by_id, args: [:id], get?: true
    define :void, action: :void
  end
end
