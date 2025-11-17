defmodule McpCache.Application do
  @moduledoc """
  Cache domain application supervisor.
  Manages Redis caching, session storage, and distributed caching.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      McpCache.Supervisor
    ]

    opts = [strategy: :one_for_one, name: McpCache.Supervisor]
    Supervisor.start_link(children, opts)
  end
end