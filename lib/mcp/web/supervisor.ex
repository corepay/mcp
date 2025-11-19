defmodule Mcp.Web.Supervisor do
  @moduledoc """
  Web supervisor.
  Manages web-layer services: Telemetry, Presence, Endpoint.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Web telemetry
      McpWeb.Telemetry,

      # DNS cluster for service discovery
      {DNSCluster, query: Application.get_env(:mcp, :dns_cluster_query) || :ignore},

      # Phoenix Presence for real-time features
      McpWeb.Presence,

      # Phoenix Endpoint (start last)
      McpWeb.Endpoint
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
