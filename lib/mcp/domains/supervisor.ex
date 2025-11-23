defmodule Mcp.Domains.Supervisor do
  @moduledoc """
  Domains supervisor.
  Manages Ash domain services with :one_for_one strategy for fault isolation.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # GDPR compliance domain - Ash domains don't need to be started as processes
      # Mcp.Domains.Gdpr
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
