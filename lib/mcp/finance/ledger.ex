defmodule Mcp.Finance.Ledger do
  @moduledoc """
  Immutable ledger for financial transactions.
  """
  use Ash.Resource,
    domain: Mcp.Finance,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "ledgers"
    repo(Mcp.Repo)
  end

  attributes do
    uuid_primary_key :id
    attribute :account_id, :uuid, allow_nil?: false
    attribute :amount, :decimal, allow_nil?: false
    attribute :currency, :string, allow_nil?: false, default: "USD"

    attribute :type, :atom do
      constraints one_of: [:credit, :debit]
      allow_nil? false
    end

    attribute :description, :string
    # External reference (e.g. Stripe ID)
    attribute :reference_id, :string

    attribute :status, :atom do
      constraints one_of: [:pending, :cleared, :failed]
      default :pending
    end

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:account_id, :amount, :currency, :type, :description, :reference_id, :status]
    end

    update :update do
      accept [:status]
    end
  end

  code_interface do
    define :create
    define :read
    define :get_by_id, action: :read, get_by: [:id]
  end
end
