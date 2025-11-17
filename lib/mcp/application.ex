defmodule Mcp.Application do
  @moduledoc """
  Main application supervisor for AI-powered MSP platform.
  Orchestrates all domain services: Core, Storage, Cache, Secrets, Communication.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Mcp.Core.Repo,

      # Web layer
      McpWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:mcp, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Mcp.PubSub},

      # Start the web endpoint last
      McpWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Mcp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    McpWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
