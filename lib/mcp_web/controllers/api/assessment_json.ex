defmodule McpWeb.Api.AssessmentJSON do
  alias Mcp.Underwriting.Execution

  @doc """
  Renders a single execution.
  """
  def show(%{execution: execution}) do
    %{data: data(execution)}
  end

  defp data(%Execution{} = execution) do
    %{
      id: execution.id,
      status: execution.status,
      subject_id: execution.subject_id,
      subject_type: execution.subject_type,
      context: execution.context,
      results: execution.results,
      inserted_at: execution.inserted_at,
      updated_at: execution.updated_at
    }
  end
end
