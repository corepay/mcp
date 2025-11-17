defmodule McpCache.Supervisor do
  @moduledoc """
  Cache domain supervisor.
  Manages Redis clients, session stores, and cache managers.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Redix, name: :redix_cache, host: System.get_env("REDIS_HOST", "localhost"), port: String.to_integer(System.get_env("REDIS_PORT", "43879"))},
      McpCache.RedisClient,
      McpCache.SessionStore,
      McpCache.CacheManager
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end