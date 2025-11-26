defmodule Mcp.Repo.Migrations.CreateAnalyticsTables do
  @moduledoc """
  Migration for analytics tables with TimescaleDB optimization.

  Creates hypertables for time-series analytics data with efficient
  partitioning and indexing for multi-tenant ISP metrics.
  """

  use Ecto.Migration

  def up do
    # Enable required extensions if not already enabled

    # Create analytics_metrics table as TimescaleDB hypertable
    create table(:analytics_metrics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :category, :string, null: false
      add :metric_name, :string, null: false
      add :metric_key, :string, null: false
      add :metric_type, :string, null: false
      add :value, :decimal, null: false
      add :unit, :string
      add :tags, :jsonb, default: "{}"
      add :source, :string, null: false
      add :recorded_at, :utc_datetime_usec, null: false
      add :aggregation_window, :string

      timestamps()
    end

    # Create TimescaleDB hypertable for analytics_metrics
    execute("""
      SELECT create_hypertable('analytics_metrics', 'recorded_at',
        chunk_time_interval => INTERVAL '1 hour',
        if_not_exists => TRUE
      );
    """)

    # Create distributed hypertable by tenant for multi-tenant isolation
    execute("""
      ALTER TABLE analytics_metrics SET (
        timescaledb.compress,
        timescaledb.compress_segmentby = 'tenant_id',
        timescaledb.compress_orderby = 'recorded_at DESC'
      );
    """)

    # Add compression policy
    execute("""
      ALTER TABLE analytics_metrics SET (
        timescaledb.compress,
        timescaledb.compress_segmentby = 'tenant_id, metric_key',
        timescaledb.compress_orderby = 'recorded_at DESC'
      );
    """)

    # Create data retention policy (keep 1 year of raw data)
    execute("""
      SELECT add_retention_policy('analytics_metrics', INTERVAL '1 year');
    """)

    # Create continuous aggregates for faster queries

    # Hourly aggregates
    create table(:analytics_metrics_hourly, primary_key: false) do
      add :tenant_id, :binary_id, null: false
      add :category, :string, null: false
      add :metric_key, :string, null: false
      add :metric_type, :string, null: false
      add :time_bucket, :utc_datetime, null: false
      add :count_metrics, :bigint, null: false
      add :sum_value, :decimal, null: false
      add :avg_value, :decimal, null: false
      add :min_value, :decimal, null: false
      add :max_value, :decimal, null: false
      add :first_value, :decimal
      add :last_value, :decimal
    end

    execute("""
      SELECT create_hypertable('analytics_metrics_hourly', 'time_bucket',
        chunk_time_interval => INTERVAL '1 day',
        if_not_exists => TRUE
      );
    """)

    # Create continuous aggregate for hourly data
    execute("""
      CREATE MATERIALIZED VIEW IF NOT EXISTS analytics_metrics_hourly_view
      WITH (timescaledb.continuous) AS
      SELECT
        tenant_id,
        category,
        metric_key,
        metric_type,
        time_bucket('1 hour', recorded_at) AS time_bucket,
        COUNT(*) AS count_metrics,
        SUM(value) AS sum_value,
        AVG(value) AS avg_value,
        MIN(value) AS min_value,
        MAX(value) AS max_value,
        first(value, recorded_at) AS first_value,
        last(value, recorded_at) AS last_value
      FROM analytics_metrics
      GROUP BY tenant_id, category, metric_key, metric_type, time_bucket('1 hour', recorded_at);
    """)

    # Daily aggregates
    create table(:analytics_metrics_daily, primary_key: false) do
      add :tenant_id, :binary_id, null: false
      add :category, :string, null: false
      add :metric_key, :string, null: false
      add :metric_type, :string, null: false
      add :time_bucket, :utc_datetime, null: false
      add :count_metrics, :bigint, null: false
      add :sum_value, :decimal, null: false
      add :avg_value, :decimal, null: false
      add :min_value, :decimal, null: false
      add :max_value, :decimal, null: false
      add :first_value, :decimal
      add :last_value, :decimal
      add :stddev_value, :decimal
    end

    execute("""
      SELECT create_hypertable('analytics_metrics_daily', 'time_bucket',
        chunk_time_interval => INTERVAL '1 month',
        if_not_exists => TRUE
      );
    """)

    # Create continuous aggregate for daily data
    execute("""
      CREATE MATERIALIZED VIEW IF NOT EXISTS analytics_metrics_daily_view
      WITH (timescaledb.continuous) AS
      SELECT
        tenant_id,
        category,
        metric_key,
        metric_type,
        time_bucket('1 day', recorded_at) AS time_bucket,
        COUNT(*) AS count_metrics,
        SUM(value) AS sum_value,
        AVG(value) AS avg_value,
        MIN(value) AS min_value,
        MAX(value) AS max_value,
        first(value, recorded_at) AS first_value,
        last(value, recorded_at) AS last_value,
        stddev(value) AS stddev_value
      FROM analytics_metrics
      GROUP BY tenant_id, category, metric_key, metric_type, time_bucket('1 day', recorded_at);
    """)

    # Set refresh policies for continuous aggregates
    execute("""
      SELECT add_continuous_aggregate_policy('analytics_metrics_hourly_view',
        start_offset => INTERVAL '1 hour',
        end_offset => INTERVAL '1 minute',
        schedule_interval => INTERVAL '5 minutes');
    """)

    execute("""
      SELECT add_continuous_aggregate_policy('analytics_metrics_daily_view',
        start_offset => INTERVAL '1 day',
        end_offset => INTERVAL '1 hour',
        schedule_interval => INTERVAL '1 hour');
    """)

    # Create other analytics tables

    # Dashboards table
    create table(:analytics_dashboards, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :string
      add :role, :string, null: false
      add :category, :string, null: false
      add :layout_config, :jsonb, default: "{\"grid\": {\"cols\": 12, \"rows\": 8}}"
      add :refresh_interval, :integer, default: 300
      add :is_public, :boolean, default: false, null: false
      add :is_default, :boolean, default: false, null: false
      add :tags, {:array, :string}, default: []
      add :config, :jsonb, default: "{}"

      timestamps()
    end

    # Widgets table
    create table(:analytics_widgets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :dashboard_id, :binary_id, null: false
      add :widget_id, :string, null: false
      add :title, :string, null: false
      add :widget_type, :string, null: false
      add :data_source, :jsonb, null: false
      add :visualization_config, :jsonb, default: "{}"
      add :position, :jsonb, default: "{\"x\": 0, \"y\": 0, \"width\": 3, \"height\": 2}"
      add :refresh_interval, :integer
      add :filters, :jsonb, default: "{}"
      add :drilldown_config, :jsonb
      add :is_visible, :boolean, default: true, null: false
      add :is_collapsible, :boolean, default: false, null: false
      add :custom_css, :string

      timestamps()
    end

    # Reports table
    create table(:analytics_reports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :string
      add :category, :string, null: false
      add :report_type, :string, null: false
      add :data_sources, {:array, :jsonb}, default: []
      add :template_config, :jsonb, default: "{}"
      add :schedule_config, :jsonb
      add :output_format, :string, default: "pdf"
      add :distribution_config, :jsonb, default: "{\"email\": [], \"webhook\": []}"
      add :parameters, :jsonb, default: "{}"
      add :status, :string, default: "draft"
      add :last_generated_at, :utc_datetime
      add :next_run_at, :utc_datetime
      add :is_public, :boolean, default: false, null: false
      add :tags, {:array, :string}, default: []

      timestamps()
    end

    # Alerts table
    create table(:analytics_alerts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :metric_id, :binary_id, null: false
      add :name, :string, null: false
      add :description, :string
      add :severity, :string, default: "warning"
      add :condition, :string, null: false
      add :threshold_value, :decimal
      add :threshold_percentage, :decimal
      add :evaluation_window, :string, default: "5m"
      add :evaluation_interval, :integer, default: 60
      add :consecutive_violations, :integer, default: 1
      add :notification_config, :jsonb, default: "{\"channels\": [], \"escalation_rules\": []}"
      add :status, :string, default: "active"
      add :is_enabled, :boolean, default: true, null: false
      add :is_triggered, :boolean, default: false, null: false
      add :last_triggered_at, :utc_datetime
      add :last_resolved_at, :utc_datetime
      add :trigger_count, :integer, default: 0
      add :tags, {:array, :string}, default: []

      timestamps()
    end

    # Create indexes for performance

    # Analytics metrics indexes
    create index(:analytics_metrics, [:tenant_id, :recorded_at])
    create index(:analytics_metrics, [:tenant_id, :metric_key, :recorded_at])
    create index(:analytics_metrics, [:tenant_id, :category, :recorded_at])
    create index(:analytics_metrics, [:metric_key, :recorded_at])
    create index(:analytics_metrics, [:source, :recorded_at])

    # Dashboard indexes
    create unique_index(:analytics_dashboards, [:tenant_id, :slug])
    create index(:analytics_dashboards, [:tenant_id, :role])
    create index(:analytics_dashboards, [:tenant_id, :category])
    create index(:analytics_dashboards, [:tenant_id, :is_public])
    create index(:analytics_dashboards, [:tenant_id, :is_default, :role])

    # Widget indexes
    create unique_index(:analytics_widgets, [:dashboard_id, :widget_id])
    create index(:analytics_widgets, [:dashboard_id, :is_visible])
    create index(:analytics_widgets, [:dashboard_id, :widget_type])

    # Report indexes
    create unique_index(:analytics_reports, [:tenant_id, :slug])
    create index(:analytics_reports, [:tenant_id, :status])
    create index(:analytics_reports, [:tenant_id, :report_type])
    create index(:analytics_reports, [:tenant_id, :next_run_at])

    # Alert indexes
    create index(:analytics_alerts, [:tenant_id, :metric_id])
    create index(:analytics_alerts, [:tenant_id, :status])
    create index(:analytics_alerts, [:tenant_id, :is_enabled])
    create index(:analytics_alerts, [:tenant_id, :is_triggered])
    create index(:analytics_alerts, [:metric_id, :is_enabled])

    # Create foreign key constraints
    alter table(:analytics_dashboards) do
      modify :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all)
    end

    alter table(:analytics_widgets) do
      modify :dashboard_id,
             references(:analytics_dashboards, type: :binary_id, on_delete: :delete_all)
    end

    alter table(:analytics_reports) do
      modify :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all)
    end

    alter table(:analytics_alerts) do
      modify :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all)
      modify :metric_id, references(:analytics_metrics, type: :binary_id, on_delete: :delete_all)
    end

    # Create aggregate function for metric queries
    execute("""
      CREATE OR REPLACE FUNCTION metric_aggregates(
        p_tenant_id UUID,
        p_metric_key VARCHAR,
        p_start_time TIMESTAMPTZ,
        p_end_time TIMESTAMPTZ,
        p_interval INTERVAL DEFAULT INTERVAL '1 hour'
      ) RETURNS TABLE (
        time_bucket TIMESTAMPTZ,
        count BIGINT,
        sum_val NUMERIC,
        avg_val NUMERIC,
        min_val NUMERIC,
        max_val NUMERIC
      ) AS $$
      BEGIN
        RETURN QUERY
        SELECT
          time_bucket(p_interval, recorded_at) as time_bucket,
          COUNT(*) as count,
          SUM(value) as sum_val,
          AVG(value) as avg_val,
          MIN(value) as min_val,
          MAX(value) as max_val
        FROM analytics_metrics
        WHERE tenant_id = p_tenant_id
          AND metric_key = p_metric_key
          AND recorded_at >= p_start_time
          AND recorded_at <= p_end_time
        GROUP BY time_bucket(p_interval, recorded_at)
        ORDER BY time_bucket;
      END;
      $$ LANGUAGE plpgsql;
    """)
  end

  def down do
    # Drop custom functions
    execute(
      "DROP FUNCTION IF EXISTS metric_aggregates(UUID, VARCHAR, TIMESTAMPTZ, TIMESTAMPTZ, INTERVAL)"
    )

    # Drop tables in reverse order of dependencies
    drop table(:analytics_alerts)
    drop table(:analytics_reports)
    drop table(:analytics_widgets)
    drop table(:analytics_dashboards)

    # Drop continuous aggregates
    execute("DROP MATERIALIZED VIEW IF EXISTS analytics_metrics_daily_view")
    execute("DROP MATERIALIZED VIEW IF EXISTS analytics_metrics_hourly_view")

    # Drop aggregate tables
    drop table(:analytics_metrics_daily)
    drop table(:analytics_metrics_hourly)

    # Drop main metrics table
    execute("DROP TABLE IF EXISTS analytics_metrics")
  end
end
