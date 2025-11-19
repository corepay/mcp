defmodule Mcp.Core.Telemetry do
  @moduledoc """
  Core domain telemetry for the AI-powered MSP platform.
  Handles metrics, spans, and observability across all domains.
  """

  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Phoenix LiveDashboard metrics
      {TelemetryMetrics.Prometheus,
       [
         metrics: [
           # Phoenix.Telemetry.metrics(),  # Commented out - Phoenix.Telemetry not available
           # Custom metrics for AI-powered MSP
           # Database performance metrics
           Mcp.Core.Telemetry.RepoMetrics,
           # Cache hit rates
           Mcp.Cache.Telemetry.RedisMetrics,
           # AI model inference time
           Mcp.Core.Telemetry.AIMetrics,
           # Payment processing latency
           Mcp.Core.Telemetry.PaymentMetrics,
           # Multi-tenant performance
           Mcp.Core.Telemetry.TenantMetrics
         ]
       ], name: Mcp.Core.Telemetry.Prometheus},

      # Metrics for PostGIS, pgvector, TimescaleDB operations
      {TelemetryMetrics.Prometheus,
       [
         metrics: [
           # Geographic query performance
           Mcp.Core.Telemetry.PostGISMetrics,
           # Vector similarity search performance
           Mcp.Core.Telemetry.PGVectorMetrics,
           # Time-series query performance
           Mcp.Core.Telemetry.TimescaleDBMetrics,
           # Graph query performance
           Mcp.Core.Telemetry.AGEMetrics
         ]
       ], name: Mcp.Core.Telemetry.Extensions},

      # Distributed tracing with OpenTelemetry
      {OpenTelemetry,
       resource: [
         service_name: "mcp-platform",
         service_version: version()
       ]},

      # Performance logger
      {Logger, :console,
       [
         format: "$time $metadata[$level] $message\n",
         metadata: [
           :request_id,
           :tenant_id,
           :trace_id,
           :span_id,
           :domain,
           :operation
         ]
       ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp version do
    case :application.get_key(:mcp, :vsn) do
      {:ok, version} -> to_string(version)
      :undefined -> "0.1.0"
    end
  end
end
