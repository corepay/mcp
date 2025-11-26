defmodule Mcp.Repo.Migrations.CreateAnalyticsTablesPostgresql do
  @moduledoc """
  Migration for analytics tables with PostgreSQL optimization.

  Creates standard PostgreSQL tables for time-series analytics data with efficient
  partitioning and indexing for multi-tenant ISP metrics. This is a PostgreSQL-compatible
  version that replaces TimescaleDB-specific features.
  """

  use Ecto.Migration

  def up do
    # Create analytics_metrics table as standard PostgreSQL table
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

    # Create comprehensive indexes for time-series performance
    create index(:analytics_metrics, [:tenant_id, :recorded_at])
    create index(:analytics_metrics, [:tenant_id, :metric_key, :recorded_at])
    create index(:analytics_metrics, [:tenant_id, :category, :recorded_at])
    create index(:analytics_metrics, [:metric_key, :recorded_at])
    create index(:analytics_metrics, [:source, :recorded_at])
    # Standard indexes without WHERE clauses (NOW() is not IMMUTABLE)
    # Performance optimization handled by application logic

    # Note: Partial indexes with NOW() are not supported due to IMMUTABLE requirement
    # Performance optimization for recent data will be handled by application logic

    # Create analytics_metrics_hourly aggregate table
    create table(:analytics_metrics_hourly, primary_key: false) do
      add :tenant_id, :binary_id, null: false
      add :category, :string, null: false
      add :metric_key, :string, null: false
      add :metric_type, :string, null: false
      add :time_bucket, :utc_datetime, null: false
      add :count_metrics, :bigint, null: false
      add :sum_value, :decimal, null: false
      add :avg_value, :decimal, null: false
      add :min_value, :decimal
      add :max_value, :decimal
      add :first_value, :decimal
      add :last_value, :decimal

      timestamps()
    end

    # Create indexes for hourly aggregate table
    create index(:analytics_metrics_hourly, [:tenant_id, :time_bucket])
    create index(:analytics_metrics_hourly, [:tenant_id, :metric_key, :time_bucket])
    create index(:analytics_metrics_hourly, [:tenant_id, :category, :time_bucket])

    create unique_index(:analytics_metrics_hourly, [:tenant_id, :metric_key, :time_bucket],
             name: :unique_hourly_metric_bucket
           )

    # Create analytics_metrics_daily aggregate table
    create table(:analytics_metrics_daily, primary_key: false) do
      add :tenant_id, :binary_id, null: false
      add :category, :string, null: false
      add :metric_key, :string, null: false
      add :metric_type, :string, null: false
      add :time_bucket, :utc_datetime, null: false
      add :count_metrics, :bigint, null: false
      add :sum_value, :decimal, null: false
      add :avg_value, :decimal, null: false
      add :min_value, :decimal
      add :max_value, :decimal
      add :first_value, :decimal
      add :last_value, :decimal
      add :stddev_value, :decimal

      timestamps()
    end

    # Create indexes for daily aggregate table
    create index(:analytics_metrics_daily, [:tenant_id, :time_bucket])
    create index(:analytics_metrics_daily, [:tenant_id, :metric_key, :time_bucket])
    create index(:analytics_metrics_daily, [:tenant_id, :category, :time_bucket])

    create unique_index(:analytics_metrics_daily, [:tenant_id, :metric_key, :time_bucket],
             name: :unique_daily_metric_bucket
           )

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

    # Create performance indexes for all analytics tables
    # (Analytics metrics indexes already created above)

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

    # Create aggregate function for metric queries (PostgreSQL compatible)
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
          date_trunc('hour', analytics_metrics.recorded_at + p_interval) as time_bucket,
          COUNT(*) as count,
          SUM(analytics_metrics.value) as sum_val,
          AVG(analytics_metrics.value) as avg_val,
          MIN(analytics_metrics.value) as min_val,
          MAX(analytics_metrics.value) as max_val
        FROM analytics_metrics
        WHERE analytics_metrics.tenant_id = p_tenant_id
          AND analytics_metrics.metric_key = p_metric_key
          AND analytics_metrics.recorded_at >= p_start_time
          AND analytics_metrics.recorded_at <= p_end_time
        GROUP BY date_trunc('hour', analytics_metrics.recorded_at + p_interval)
        ORDER BY time_bucket;
      END;
      $$ LANGUAGE plpgsql;
    """)

    # Create a trigger function to automatically aggregate hourly data
    execute("""
      CREATE OR REPLACE FUNCTION aggregate_hourly_metrics()
      RETURNS TRIGGER AS $$
      BEGIN
        -- This would be called by a scheduled job to aggregate hourly data
        -- For now, it's a placeholder that can be called manually
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    """)

    # Create a view for recent metrics (optimized for dashboard queries)
    execute("""
      CREATE OR REPLACE VIEW recent_metrics AS
      SELECT
        tenant_id,
        category,
        metric_key,
        metric_type,
        AVG(value) as avg_value,
        MAX(value) as max_value,
        MIN(value) as min_value,
        COUNT(*) as count,
        MAX(recorded_at) as last_recorded_at
      FROM analytics_metrics
      WHERE recorded_at >= NOW() - INTERVAL '24 hours'
      GROUP BY tenant_id, category, metric_key, metric_type;
    """)
  end

  def down do
    # Drop views and functions first
    execute("DROP VIEW IF EXISTS recent_metrics")
    execute("DROP FUNCTION IF EXISTS aggregate_hourly_metrics()")

    execute(
      "DROP FUNCTION IF EXISTS metric_aggregates(UUID, VARCHAR, TIMESTAMPTZ, TIMESTAMPTZ, INTERVAL)"
    )

    # Drop tables in reverse order of dependencies
    drop table(:analytics_alerts)
    drop table(:analytics_reports)
    drop table(:analytics_widgets)
    drop table(:analytics_dashboards)

    # Drop aggregate tables
    drop table(:analytics_metrics_daily)
    drop table(:analytics_metrics_hourly)

    # Drop main metrics table
    drop table(:analytics_metrics)
  end
end
