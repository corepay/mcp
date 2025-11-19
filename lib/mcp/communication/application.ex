defmodule Mcp.Communication.Application do
  @moduledoc """
  Communication domain application supervisor.
  Manages email, SMS, notifications, and messaging services.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Mcp.Communication.Supervisor
    ]

    opts = [strategy: :one_for_one, name: Mcp.Communication.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
