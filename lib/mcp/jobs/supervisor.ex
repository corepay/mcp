defmodule Mcp.Jobs.Supervisor do
  @moduledoc """
  Jobs supervisor.
  Manages Oban background job processing.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Oban configuration will be added when job processing is implemented
      # For now, this supervisor is ready for Oban integration
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
