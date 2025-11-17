defmodule Mcp.Core.Application do
  @moduledoc """
  Core domain application supervisor.
  Manages foundational services: database, telemetry, pubsub.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Mcp.Core.Telemetry,
      Mcp.Core.Repo,
      {DNSCluster, query: Application.get_env(:mcp, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Mcp.PubSub}
    ]

    opts = [strategy: :one_for_one, name: Mcp.Core.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(_changed, _new, _removed) do
    # Mcp.PubSub.config_change(changed, removed)  # Commented out - Mcp.PubSub not available
    :ok
  end
end