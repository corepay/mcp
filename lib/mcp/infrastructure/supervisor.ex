defmodule Mcp.Infrastructure.Supervisor do
  @moduledoc """
  Infrastructure supervisor.
  Manages all infrastructure services with :rest_for_one strategy for dependency ordering.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Database (Ecto Repo)
      Mcp.Repo,

      # Cache services
      Mcp.Cache.Supervisor,

      # Secrets management
      Mcp.Secrets.Supervisor,

      # Storage services
      Mcp.Storage.Supervisor,

      # Search services (Meilisearch)
      Mcp.Search.Supervisor
    ]

    # Use :rest_for_one for dependency ordering (e.g., Cache depends on Redis)
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
