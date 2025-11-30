defmodule McpWeb.Api.AssessmentController do
  use McpWeb, :controller

  alias Mcp.Underwriting.Execution

  action_fallback McpWeb.FallbackController

  @doc """
  POST /api/assessments
  Triggers a new Assessment Execution.
  """
  def create(conn, %{"pipeline_id" => pipeline_id, "subject_id" => subject_id, "subject_type" => subject_type} = params) do
    # 1. Create the Execution record
    create_params = %{
      pipeline_id: pipeline_id,
      subject_id: subject_id,
      subject_type: String.to_atom(subject_type),
      context: Map.get(params, "context", %{}),
      status: :pending
    }

    with {:ok, execution} <- Ash.create(Execution, create_params) do
      # 2. Trigger the Orchestrator via Oban
      %{execution_id: execution.id}
      |> Mcp.Underwriting.Jobs.RunPipeline.new()
      |> Oban.insert!()

      conn
      |> put_status(:created)
      |> render(:show, execution: execution)
    end
  end

  @doc """
  GET /api/assessments/:id
  Retrieves the status and results of an Assessment.
  """
  def show(conn, %{"id" => id}) do
    execution = Ash.get!(Execution, id)
    render(conn, :show, execution: execution)
  end
end
