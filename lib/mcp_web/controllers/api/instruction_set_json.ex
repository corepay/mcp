defmodule McpWeb.Api.InstructionSetJSON do
  alias Mcp.Underwriting.InstructionSet

  @doc """
  Renders a single instruction set.
  """
  def show(%{instruction_set: instruction_set}) do
    %{data: data(instruction_set)}
  end

  defp data(%InstructionSet{} = instruction_set) do
    %{
      id: instruction_set.id,
      name: instruction_set.name,
      instructions: instruction_set.instructions,
      blueprint_id: instruction_set.blueprint_id,
      inserted_at: instruction_set.inserted_at,
      updated_at: instruction_set.updated_at
    }
  end
end
