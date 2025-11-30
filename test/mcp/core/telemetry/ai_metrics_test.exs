defmodule Mcp.Core.Telemetry.AIMetricsTest do
  use ExUnit.Case, async: true
  alias Mcp.Core.Telemetry.AIMetrics

  test "metrics/0 returns a list of Telemetry.Metrics" do
    metrics = AIMetrics.metrics()
    assert is_list(metrics)
    assert length(metrics) > 0
    
    first_metric = List.first(metrics)
    assert %Telemetry.Metrics.Distribution{} = first_metric
    assert first_metric.event_name == [:mcp, :ai, :agent, :completion]
  end
end
