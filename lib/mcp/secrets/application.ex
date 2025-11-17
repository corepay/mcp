defmodule Mcp.Secrets.Application do
  @moduledoc """
  Secrets domain application supervisor.
  Manages Vault integration, encryption keys, and credential storage.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Mcp.Secrets.Supervisor
    ]

    opts = [strategy: :one_for_one, name: Mcp.Secrets.Supervisor]
    Supervisor.start_link(children, opts)
  end
end