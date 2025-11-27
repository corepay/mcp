defmodule Mcp.Finance.Account do
  use Ash.Resource,
    domain: Mcp.Finance,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshDoubleEntry.Account, AshArchival]

  postgres do
    table "accounts"
    repo(Mcp.Repo)
    schema("finance")
  end

  account do
    balance_resource(Mcp.Finance.Balance)
    transfer_resource(Mcp.Finance.Transfer)
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false
    attribute :identifier, :string, allow_nil?: false

    # Cross-schema links
    attribute :merchant_id, :uuid
    attribute :mid_id, :uuid

    timestamps()
  end

  relationships do
    # Link to Tenant (Global)
    belongs_to :tenant, Mcp.Platform.Tenant do
      domain Mcp.Platform
    end
  end
end
