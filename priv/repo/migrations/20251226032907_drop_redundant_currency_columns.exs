defmodule Mcp.Repo.Migrations.DropRedundantCurrencyColumns do
  use Ecto.Migration

  def up do
    alter table(:balances, prefix: "finance") do
      remove :currency
    end
  end

  def down do
    alter table(:balances, prefix: "finance") do
      add :currency, :text, null: false, default: "USD"
    end
  end
end
