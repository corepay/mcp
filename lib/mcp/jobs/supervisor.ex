defmodule Mcp.Jobs.Supervisor do
  @moduledoc """
  Jobs supervisor.
  Manages Oban background job processing for GDPR compliance and other async tasks.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Oban, Application.get_env(:mcp, Oban)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
