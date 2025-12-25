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
    # Note: TelemetryMetrics.Prometheus and OpenTelemetry dependencies are not yet added
    # This is a placeholder for future telemetry configuration
    children = []
    Supervisor.init(children, strategy: :one_for_one)
  end
end
