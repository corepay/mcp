defmodule Mcp.Services.Supervisor do
  @moduledoc """
  Services supervisor.
  Manages service GenServers with :one_for_one strategy for fault isolation.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Core services will be added as they're implemented
      # SchemaManager, ConversationManager, ModelRouter, ProcessorPool, etc.
      Mcp.Utils.CircuitBreaker,
      Mcp.Underwriting.CircuitBreaker
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
