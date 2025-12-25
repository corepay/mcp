defmodule Mcp.Analytics.TimeSeries do
  @moduledoc """
  Time-series operations using TimescaleDB extension.
  Provides tenant-isolated time-series analytics and management.
  """

  alias Mcp.Infrastructure.Context
  alias Mcp.Repo

  @tenant_schema_prefix "acq_"

  @doc """
  Converts a regular PostgreSQL table into a TimescaleDB hypertable.
  """
  def create_hypertable(
        tenant_schema_name,
        table_name,
        time_column,
        chunk_time_interval \\ "1 day"
      ) do
    _schema_name = @tenant_schema_prefix <> tenant_schema_name

    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT create_hypertable('#{table_name}', '#{time_column}',
        chunk_time_interval => INTERVAL '#{chunk_time_interval}')
      """

      Repo.query(query)
    end)
  end

  @doc """
  Creates a continuous aggregate view for automatic pre-aggregation.
  """
  def create_continuous_aggregate(
        tenant_schema_name,
        aggregate_name,
        source_table,
        time_bucket \\ "1 hour"
      ) do
    _schema_name = @tenant_schema_prefix <> tenant_schema_name

    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      CREATE MATERIALIZED VIEW #{aggregate_name}
      WITH (timescaledb.continuous) AS
      SELECT
        time_bucket('#{time_bucket}', time) AS bucket,
        merchant_id,
        SUM(transaction_volume) as total_volume,
        COUNT(*) as transaction_count,
        AVG(average_transaction_amount) as avg_amount,
        STDDEV(average_transaction_amount) as amount_stddev
      FROM #{source_table}
      GROUP BY bucket, merchant_id
      """

      Repo.query(query)
    end)
  end

  @doc """
  Retrieves daily analytics for a merchant over a time range.
  """
  def time_series_analytics(tenant_schema_name, table_name, merchant_id, days \\ 30) do
    _schema_name = @tenant_schema_prefix <> tenant_schema_name

    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT
        time_bucket('1 day', time) as date,
        SUM(transaction_volume) as daily_volume,
        COUNT(*) as daily_count,
        AVG(average_transaction_amount) as daily_avg,
        MIN(average_transaction_amount) as daily_min,
        MAX(average_transaction_amount) as daily_max,
        STDDEV(average_transaction_amount) as daily_stddev
      FROM #{table_name}
      WHERE merchant_id = $1
      AND time >= NOW() - INTERVAL '#{days} days'
      GROUP BY time_bucket('1 day', time)
      ORDER BY date DESC
      """

      Repo.query(query, [merchant_id])
    end)
  end

  @doc """
  Retrieves real-time metrics with 5-minute buckets for the last hour.
  """
  def real_time_metrics(tenant_schema_name, table_name, merchant_id) do
    _schema_name = @tenant_schema_prefix <> tenant_schema_name

    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT
        time_bucket('5 minutes', time) as five_min_bucket,
        merchant_id,
        COUNT(*) as transaction_count,
        SUM(transaction_volume) as total_volume,
        AVG(response_time_ms) as avg_response_time
      FROM #{table_name}
      WHERE merchant_id = $1
      AND time >= NOW() - INTERVAL '1 hour'
      GROUP BY five_min_bucket, merchant_id
      ORDER BY five_min_bucket DESC
      """

      Repo.query(query, [merchant_id])
    end)
  end
end
