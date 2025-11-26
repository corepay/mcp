defmodule Mcp.Payments.Customer do
  @moduledoc """
  Ash resource representing a payment customer.
  """

  use Ash.Resource,
    domain: Mcp.Payments,
    data_layer: AshPostgres.DataLayer

  @derive {Jason.Encoder,
           only: [:id, :email, :name, :phone, :provider_refs, :inserted_at, :updated_at]}

  postgres do
    table "payment_customers"
    repo(Mcp.Repo)
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:email, :name, :phone]
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
    end

    update :update do
      primary? true
      accept [:email, :name, :phone, :provider_refs]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string, allow_nil?: false
    attribute :name, :string
    attribute :phone, :string
    # Map of provider => customer_id
    attribute :provider_refs, :map

    timestamps()
  end

  relationships do
    has_many :payment_methods, Mcp.Payments.PaymentMethod
    has_many :charges, Mcp.Payments.Charge
  end

  code_interface do
    define :create, action: :create
    define :read, action: :read
    define :by_id, action: :read, get_by: [:id], get?: true
    define :update, action: :update
    define :destroy, action: :destroy
  end
end
