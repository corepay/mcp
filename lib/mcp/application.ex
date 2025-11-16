defmodule Mcp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      McpWeb.Telemetry,
      Mcp.Repo,
      {DNSCluster, query: Application.get_env(:mcp, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Mcp.PubSub},
      # Start a worker by calling: Mcp.Worker.start_link(arg)
      # {Mcp.Worker, arg},
      # Start to serve requests, typically the last entry
      McpWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mcp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    McpWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
