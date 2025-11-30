defmodule Mcp.Core.Telemetry.AIMetrics do
  @moduledoc """
  Prometheus metrics definitions for AI operations.
  """
  import Telemetry.Metrics

  def metrics do
    [
      # Latency
      distribution("mcp.ai.agent.completion.latency",
        event_name: [:mcp, :ai, :agent, :completion],
        measurement: :latency,
        unit: {:native, :millisecond},
        tags: [:blueprint, :provider, :model, :cached, :tenant_id],
        reporter_options: [
          buckets: [100, 500, 1000, 2000, 5000, 10000, 30000]
        ]
      ),

      # Token Usage
      sum("mcp.ai.agent.completion.tokens.total",
        event_name: [:mcp, :ai, :agent, :completion],
        measurement: :total_tokens,
        tags: [:blueprint, :provider, :model, :cached, :tenant_id]
      ),

      # Cost
      sum("mcp.ai.agent.completion.cost",
        event_name: [:mcp, :ai, :agent, :completion],
        measurement: :cost,
        tags: [:blueprint, :provider, :model, :cached, :tenant_id]
      ),
      
      # Cache Hits (derived from tags, but explicit counter is nice)
      counter("mcp.ai.agent.completion.count",
        event_name: [:mcp, :ai, :agent, :completion],
        tags: [:blueprint, :provider, :model, :cached, :tenant_id]
      )
    ]
  end
end
