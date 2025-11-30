defmodule Mcp.Finance do
  use Ash.Domain,
    extensions: [AshJsonApi.Domain]

  resources do
    resource Mcp.Finance.Ledger
    resource Mcp.Finance.Account
    resource Mcp.Finance.Balance
    resource Mcp.Finance.Transfer
  end

  json_api do
    prefix "/finance"
  end
end
