defmodule Mcp.Repo.TenantMigrations.AddSearchIndexes do
  @moduledoc """
  Migration to add search indexes for improved query performance.
  """

  use Ecto.Migration

  def up do
    # Add vector search capabilities for AI features
    # alter table(:merchants) do
    #   add :embedding_vector, :vector
    #   add :location, :geometry
    # end

    # Add full-text search indexes for merchants
    # execute """
    # CREATE INDEX merchants_name_search_idx ON merchants
    # USING gin(to_tsvector('english', business_name || ' ' || COALESCE(dba_name, '')));
    # """

    # execute """
    # CREATE INDEX merchants_location_idx ON merchants
    # USING gist(location) WHERE location IS NOT NULL;
    # """

    # Add composite indexes for common query patterns
    create index(:merchants, [:status, :plan])
    create index(:merchants, [:reseller_id, :status])
    create index(:mids, [:merchant_id, :status, :is_primary])
    create index(:stores, [:merchant_id, :status, :routing_type])

    # Add partial indexes for filtered queries
    create index(:merchants, [:verification_status], where: "verification_status != 'verified'")
    create index(:mids, [:status], where: "status = 'active'")
    create index(:customers, [:status], where: "status = 'active'")

    # Create vector index for similarity search
    # execute """
    # CREATE INDEX merchants_embedding_vector_idx ON merchants
    # USING ivfflat (embedding_vector vector_cosine_ops) WITH (lists = 100);
    # """

    # Add time-series capabilities for transactions
    # create table(:transaction_metrics) do
    #   add :merchant_id, :uuid, null: false
    #   add :store_id, :uuid
    #   add :mid_id, :uuid
    #   add :timestamp, :utc_datetime, null: false
    #   add :transaction_count, :integer, default: 0
    #   add :total_volume, :decimal, default: 0
    #   add :average_amount, :decimal
    #   add :success_rate, :decimal
    #   add :response_time_ms, :integer
    #   add :gateway_response_code, :string
    #   add :failure_reason, :string
    # end

    # Create hypertable for time-series data
    # execute """
    # SELECT create_hypertable('transaction_metrics', 'timestamp',
    #   chunk_time_interval => INTERVAL '1 hour');
    # """

    # create index(:transaction_metrics, [:merchant_id, :timestamp])
    # create index(:transaction_metrics, [:store_id, :timestamp])
    # create index(:transaction_metrics, [:mid_id, :timestamp])
  end

  def down do
    drop index(:merchants, [:status, :plan])
    drop index(:merchants, [:reseller_id, :status])
    drop index(:mids, [:merchant_id, :status, :is_primary])
    drop index(:stores, [:merchant_id, :status, :routing_type])
    drop index(:merchants, [:name], where: "verification_status != 'verified'")
    drop index(:mids, [:status], where: "status = 'active'")
    drop index(:customers, [:status], where: "status = 'active'")

    execute "DROP INDEX IF EXISTS merchants_name_search_idx;"
    execute "DROP INDEX IF EXISTS merchants_location_idx;"
    execute "DROP INDEX IF EXISTS merchants_embedding_vector_idx;"

    alter table(:merchants) do
      remove :embedding_vector
      remove :location
    end

    drop table(:transaction_metrics)
  end
end