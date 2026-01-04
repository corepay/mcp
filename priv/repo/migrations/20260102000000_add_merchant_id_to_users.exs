defmodule Mcp.Repo.Migrations.AddMerchantIdToUsers do
  use Ecto.Migration

  def up do
    alter table(:users, prefix: "platform") do
      add :merchant_id, :uuid
    end

    create index(:users, [:merchant_id], prefix: "platform")
  end

  def down do
    alter table(:users, prefix: "platform") do
      remove :merchant_id
    end
  end
end
