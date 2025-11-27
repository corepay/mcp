defmodule Mcp.Application do
  @moduledoc """
  Main application supervisor for AI-powered MSP platform.
  """

  use Application

  @impl true
  def start(_type, _args) do
    # Ensure OS monitoring applications are started
    ensure_os_mon_apps()

    children = [
      # Platform-level services (shared resources)
      Mcp.Platform.Supervisor,

      # Clustering Supervisor
      {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies) || [], [name: Mcp.ClusterSupervisor]]},

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

  # Ensure any available OS monitoring applications are started
  defp ensure_os_mon_apps do
    # Try to start os_mon if available, but don't fail if it's not
    Application.start(:os_mon)
    :cpu_sup.start_link()
    :memsup.start_link()
    :disksup.start_link()
  rescue
    # OS monitoring not available, continue without it
    _ -> :ok
  end
end
