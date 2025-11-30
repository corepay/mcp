defmodule Mcp.Telemetry do
  @moduledoc """
  Helper module for emitting Telemetry events in the MCP platform.
  """

  @doc """
  Executes a telemetry event.
  The event name is automatically prefixed with `[:mcp]`.
  """
  def execute(event, measurements, metadata \\ %{}) when is_list(event) do
    :telemetry.execute([:mcp | event], measurements, metadata)
  end

  @doc """
  Executes a span for the given function.
  Emits `[:mcp, event, :start]`, `[:mcp, event, :stop]`, and `[:mcp, event, :exception]`.
  """
  def span(event, metadata, fun) when is_list(event) do
    :telemetry.span([:mcp | event], metadata, fun)
  end
end
