defmodule Mcp.Finance.Ledger do
  use Ash.Resource,
    domain: Mcp.Finance,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "ledgers"
    repo Mcp.Repo
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
    attribute :reference_id, :string # External reference (e.g. Stripe ID)
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
  end
end
