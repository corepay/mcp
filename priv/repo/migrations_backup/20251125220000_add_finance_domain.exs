defmodule Mcp.Repo.Migrations.AddFinanceDomain do
  use Ecto.Migration

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS finance"

    create table(:accounts, primary_key: false, prefix: "finance") do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :identifier, :text, null: false
      add :type, :text, null: false
      add :balance, :decimal, null: false, default: 0
      add :currency, :text, null: false
      
      add :tenant_id, references(:tenants, type: :uuid, prefix: "platform")
      add :merchant_id, :uuid
      add :mid_id, :uuid

      timestamps()
    end

    create table(:transfers, primary_key: false, prefix: "finance") do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :amount, :decimal, null: false
      add :timestamp, :utc_datetime_usec, null: false
      
      add :from_account_id, references(:accounts, type: :uuid, prefix: "finance"), null: false
      add :to_account_id, references(:accounts, type: :uuid, prefix: "finance"), null: false

      timestamps()
    end

    create table(:balances, primary_key: false, prefix: "finance") do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :balance, :decimal, null: false
      add :currency, :text, null: false
      
      add :account_id, references(:accounts, type: :uuid, prefix: "finance"), null: false

      timestamps()
    end

    create index(:accounts, [:identifier], unique: true, prefix: "finance")
    create index(:accounts, [:tenant_id], prefix: "finance")
    create index(:accounts, [:merchant_id], prefix: "finance")
    create index(:accounts, [:mid_id], prefix: "finance")
    
    create index(:transfers, [:from_account_id], prefix: "finance")
    create index(:transfers, [:to_account_id], prefix: "finance")
    
    create index(:balances, [:account_id], prefix: "finance")
  end

  def down do
    drop table(:balances, prefix: "finance")
    drop table(:transfers, prefix: "finance")
    drop table(:accounts, prefix: "finance")
  end
end
