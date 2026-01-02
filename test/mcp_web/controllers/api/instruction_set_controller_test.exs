defmodule McpWeb.Api.InstructionSetControllerTest do
  use McpWeb.ConnCase

  alias Mcp.Platform.ApiKey
  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.AgentBlueprint

  setup do
    blueprint =
      Ash.create!(AgentBlueprint, %{
        name: "Generic Agent",
        base_prompt: "Be helpful.",
        tools: []
      })

    # Create a tenant for the API key
    tenant_id = Ecto.UUID.generate()

    Mcp.Repo.insert!(%Tenant{
      id: tenant_id,
      name: "Test Tenant",
      slug: "test-tenant-#{tenant_id}",
      subdomain: "test-#{tenant_id}",
      company_schema: "acq_#{String.replace(tenant_id, "-", "_")}",
      plan: :starter,
      status: :active,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    })

    # Create API Key using Platform.ApiKey
    {:ok, api_key} =
      ApiKey.create(%{
        prefix: "test",
        type: :developer,
        scopes: ["instruction_sets:write"],
        owner_id: tenant_id,
        owner_type: :tenant
      })

    # Get the actual raw key from metadata
    raw_key = Ash.Resource.get_metadata(api_key, :raw_key)

    %{blueprint: blueprint, api_key: raw_key}
  end

  describe "POST /api/instruction_sets" do
    test "creates a new instruction set", %{conn: conn, blueprint: blueprint, api_key: api_key} do
      payload = %{
        "name" => "New Policy",
        "instructions" => "Do this.",
        "blueprint_id" => blueprint.id
      }

      conn =
        conn
        |> put_req_header("accept", "application/vnd.mcp.v1+json")
        |> put_req_header("x-api-key", api_key)
        |> post(~p"/api/instruction_sets", payload)

      assert %{"data" => %{"id" => _id, "name" => "New Policy"}} = json_response(conn, 201)
    end
  end
end
