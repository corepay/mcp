defmodule Mcp.Platform.Supervisor do
  @moduledoc """
  Platform supervisor.
  Manages platform-level services: PubSub, Finch HTTP client, Registry/PartitionSupervisor.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Phoenix PubSub for real-time communication
      {Phoenix.PubSub, name: Mcp.PubSub},

      # Finch HTTP client for external API calls
      {Finch, name: Mcp.Finch},

      # Registry for process lookup
      {Registry, keys: :unique, name: Mcp.Registry},

      # PartitionSupervisor for dynamic supervision
      {PartitionSupervisor, child_spec: Mcp.DynamicSupervisor, name: Mcp.DynamicSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
