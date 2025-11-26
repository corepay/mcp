defmodule Mcp.Finance.Balance do
  use Ash.Resource,
    domain: Mcp.Finance,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshDoubleEntry.Balance]

  postgres do
    table "balances"
    repo(Mcp.Repo)
    schema("finance")
  end

  balance do
    account_resource(Mcp.Finance.Account)
    transfer_resource(Mcp.Finance.Transfer)
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end
end
