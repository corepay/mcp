defmodule Mcp.Payments.PaymentMethod do
  @moduledoc """
  Ash resource representing a customer's payment method.
  """

  use Ash.Resource,
    domain: Mcp.Payments,
    data_layer: AshPostgres.DataLayer

  @derive {Jason.Encoder,
           only: [
             :id,
             :type,
             :provider,
             :provider_token,
             :last4,
             :brand,
             :exp_month,
             :exp_year,
             :bank_name,
             :account_holder_name,
             :account_type,
             :last4_account,
             :inserted_at,
             :updated_at
           ]}

  postgres do
    table "payment_methods"
    repo(Mcp.Repo)
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
    end

    create :create do
      primary? true
      argument :customer_id, :uuid

      accept [
        :type,
        :provider,
        :provider_token,
        :last4,
        :brand,
        :exp_month,
        :exp_year,
        :bank_name,
        :account_holder_name,
        :account_type,
        :last4_account
      ]

      change manage_relationship(:customer_id, :customer, type: :append_and_remove)
    end

    update :update do
      primary? true
      accept [:provider_token]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :atom do
      constraints one_of: [:card, :bank_account]
    end

    attribute :provider, :atom, allow_nil?: false
    # Token from the provider (e.g. src_...)
    attribute :provider_token, :string
    attribute :last4, :string
    attribute :brand, :string
    attribute :exp_month, :integer
    attribute :exp_year, :integer

    # ACH Specifics
    attribute :bank_name, :string
    attribute :account_holder_name, :string

    attribute :account_type, :atom do
      constraints one_of: [:checking, :savings]
    end

    # Last 4 of account number
    attribute :last4_account, :string

    timestamps()
  end

  relationships do
    belongs_to :customer, Mcp.Payments.Customer
  end

  code_interface do
    define :create, action: :create
    define :read, action: :read
    define :by_id, action: :by_id, args: [:id], get?: true
    define :update, action: :update
    define :destroy, action: :destroy
  end
end
