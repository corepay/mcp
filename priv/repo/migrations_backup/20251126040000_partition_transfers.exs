defmodule Mcp.Repo.Migrations.PartitionTransfers do
  use Ecto.Migration

  def up do
    # Enable pg_partman extension - SKIPPED (Not available in environment)
    # execute "CREATE EXTENSION IF NOT EXISTS pg_partman"

    # Drop existing table
    drop_if_exists table(:transfers, prefix: "finance")

    # Create partitioned table
    create table(:transfers, primary_key: false, prefix: "finance", options: "PARTITION BY RANGE (inserted_at)") do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :amount, :decimal, null: false
      add :timestamp, :utc_datetime_usec, null: false
      
      add :from_account_id, references(:accounts, type: :uuid, prefix: "finance"), null: false
      add :to_account_id, references(:accounts, type: :uuid, prefix: "finance"), null: false

      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()"), primary_key: true
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:transfers, [:from_account_id], prefix: "finance")
    create index(:transfers, [:to_account_id], prefix: "finance")
    create index(:transfers, [:inserted_at], prefix: "finance")

    # Manually create partitions (Native Partitioning)
    # Default partition
    execute "CREATE TABLE finance.transfers_default PARTITION OF finance.transfers DEFAULT"
    
    # Current month partition (November 2025)
    execute "CREATE TABLE finance.transfers_p2025_11 PARTITION OF finance.transfers FOR VALUES FROM ('2025-11-01 00:00:00') TO ('2025-12-01 00:00:00')"
    
    # Next month partition (December 2025)
    execute "CREATE TABLE finance.transfers_p2025_12 PARTITION OF finance.transfers FOR VALUES FROM ('2025-12-01 00:00:00') TO ('2026-01-01 00:00:00')"
  end

  def down do
    # Drop partitioning config (optional, dropping table usually clears it but good to be clean)
    # execute "DELETE FROM partman.part_config WHERE parent_table = 'finance.transfers'"
    
    drop table(:transfers, prefix: "finance")

    # Recreate original table (simplified)
    create table(:transfers, primary_key: false, prefix: "finance") do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :amount, :decimal, null: false
      add :timestamp, :utc_datetime_usec, null: false
      
      add :from_account_id, references(:accounts, type: :uuid, prefix: "finance"), null: false
      add :to_account_id, references(:accounts, type: :uuid, prefix: "finance"), null: false

      timestamps()
    end
  end
end
