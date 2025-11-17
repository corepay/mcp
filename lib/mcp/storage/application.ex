defmodule Mcp.Storage.Application do
  @moduledoc """
  Storage domain application supervisor.
  Manages object storage, file handling, and CDN services.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Mcp.Storage.Supervisor
    ]

    opts = [strategy: :one_for_one, name: Mcp.Storage.Supervisor]
    Supervisor.start_link(children, opts)
  end
end