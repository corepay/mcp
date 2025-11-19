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
      # Ash domains will be added when implemented
      # For now, this supervisor is ready for domain services
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
