defmodule McpWeb.Api.InstructionSetController do
  use McpWeb, :controller

  alias Mcp.Underwriting.InstructionSet

  action_fallback McpWeb.FallbackController

  @doc """
  POST /api/instruction_sets
  Creates a new Instruction Set.
  """
  def create(conn, params) do
    with {:ok, instruction_set} <- Ash.create(InstructionSet, params) do
      conn
      |> put_status(:created)
      |> render(:show, instruction_set: instruction_set)
    end
  end

  @doc """
  GET /api/instruction_sets/:id
  """
  def show(conn, %{"id" => id}) do
    instruction_set = Ash.get!(InstructionSet, id)
    render(conn, :show, instruction_set: instruction_set)
  end
end
