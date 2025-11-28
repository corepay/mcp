defmodule Mcp.Application do
  @moduledoc """
  Main application supervisor for AI-powered MSP platform.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Platform-level services (shared resources)
      Mcp.Platform.Supervisor,

      # Clustering Supervisor
      {Cluster.Supervisor,
       [Application.get_env(:libcluster, :topologies) || [], [name: Mcp.ClusterSupervisor]]},

      # Infrastructure services (with dependencies)
      Mcp.Infrastructure.Supervisor,

      # Domain services (Ash domains)
      Mcp.Domains.Supervisor,

      # Oban must start after Repo (in Infrastructure) and Domains
      {Oban, Application.fetch_env!(:mcp, Oban)},

      # GDPR compliance module (comprehensive implementation)
      Mcp.Gdpr.Supervisor,

      # Application services (GenServers)
      Mcp.Services.Supervisor,

      # Background job processing
      Mcp.Jobs.Supervisor,

      # Web layer (must start after platform services)
      Mcp.Web.Supervisor
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
