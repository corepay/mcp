defmodule McpWeb.Api.InstructionSetController do
  use McpWeb, :controller

  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.InstructionSet

  action_fallback McpWeb.FallbackController

  @doc """
  POST /api/instruction_sets
  Creates a new Instruction Set.
  """
  def create(conn, params) do
    tenant_schema = get_tenant_schema(conn)

    with {:ok, instruction_set} <- Ash.create(InstructionSet, params, tenant: tenant_schema) do
      conn
      |> put_status(:created)
      |> render(:show, instruction_set: instruction_set)
    end
  end

  @doc """
  GET /api/instruction_sets/:id
  """
  def show(conn, %{"id" => id}) do
    tenant_schema = get_tenant_schema(conn)
    instruction_set = Ash.get!(InstructionSet, id, tenant: tenant_schema)
    render(conn, :show, instruction_set: instruction_set)
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
