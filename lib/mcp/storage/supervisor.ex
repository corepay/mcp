defmodule Mcp.Storage.Supervisor do
  @moduledoc """
  Storage domain supervisor.
  Manages storage clients, file processors, and CDN services.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      Mcp.Storage.ClientFactory,
      Mcp.Storage.FileManager,
      Mcp.Storage.CDNManager
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
