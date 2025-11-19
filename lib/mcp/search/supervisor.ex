defmodule Mcp.Search.Supervisor do
  @moduledoc """
  Search domain supervisor.
  Manages Meilisearch client and search services.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Meilisearch client will be added when Meilisearch integration is implemented
      # For now, this supervisor is ready for future search services
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
