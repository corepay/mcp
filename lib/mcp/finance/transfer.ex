defmodule Mcp.Finance.Transfer do
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

  attributes do
    uuid_primary_key :id

    attribute :inserted_at, :utc_datetime_usec do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :updated_at, :utc_datetime_usec do
      default &DateTime.utc_now/0
      match_other_defaults? true
    end
  end
end
