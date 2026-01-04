defmodule McpWeb.Api.AssessmentController do
  use McpWeb, :controller

  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.Execution
  alias Mcp.Underwriting.Jobs.RunPipeline

  action_fallback McpWeb.FallbackController

  @doc """
  POST /api/assessments
  Triggers a new Assessment Execution.
  """
  def create(
        conn,
        %{
          "pipeline_id" => pipeline_id,
          "subject_id" => subject_id,
          "subject_type" => subject_type
        } = params
      ) do
    tenant_schema = get_tenant_schema(conn)

    # 1. Create the Execution record
    create_params = %{
      pipeline_id: pipeline_id,
      subject_id: subject_id,
      subject_type: String.to_atom(subject_type),
      context: Map.get(params, "context", %{}),
      status: :pending
    }

    with {:ok, execution} <- Ash.create(Execution, create_params, tenant: tenant_schema) do
      # 2. Trigger the Orchestrator via Oban
      %{execution_id: execution.id, tenant: tenant_schema}
      |> RunPipeline.new()
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
    tenant_schema = get_tenant_schema(conn)
    execution = Ash.get!(Execution, id, tenant: tenant_schema)
    render(conn, :show, execution: execution)
  end

  # Get the tenant schema from the connection context
  defp get_tenant_schema(conn) do
    case conn.assigns[:current_tenant_id] do
      nil ->
        nil

      tenant_id ->
        case Ash.get(Tenant, tenant_id) do
          {:ok, tenant} -> tenant.company_schema
          _ -> nil
        end
    end
  end
end
