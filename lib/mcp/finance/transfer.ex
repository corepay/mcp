defmodule Mcp.Finance.Transfer do
  @moduledoc """
  Represents a financial transfer between accounts.
  """
  use Ash.Resource,
    domain: Mcp.Finance,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshDoubleEntry.Transfer]

  postgres do
    table "transfers"
    repo(Mcp.Repo)
    schema("finance")
  end

  transfer do
    account_resource(Mcp.Finance.Account)
    balance_resource(Mcp.Finance.Balance)
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:amount, :from_account_id, :to_account_id, :description]
    end
  end

  attributes do
    attribute :id, AshDoubleEntry.ULID do
      primary_key? true
      allow_nil? false
      default &AshDoubleEntry.ULID.generate/0
    end

    attribute :amount, AshMoney.Types.Money do
      allow_nil? false
    end

    attribute :inserted_at, :utc_datetime_usec do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :description, :string

    attribute :updated_at, :utc_datetime_usec do
      default &DateTime.utc_now/0
      match_other_defaults? true
    end
  end

  code_interface do
    define :create
  end
end
