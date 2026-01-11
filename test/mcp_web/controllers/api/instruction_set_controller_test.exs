defmodule McpWeb.Api.InstructionSetControllerTest do
  use McpWeb.ConnCase

  alias Mcp.Platform.ApiKey
  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.AgentBlueprint

  setup do
    # Create isolated test tenant
    unique_id = System.unique_integer([:positive])

    tenant =
      Mcp.Repo.insert!(%Tenant{
        id: Ecto.UUID.generate(),
        name: "Test Tenant #{unique_id}",
        slug: "test-tenant-#{unique_id}",
        subdomain: "test-#{unique_id}",
        company_schema: "acq_test_#{unique_id}",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      })

    schema = tenant.company_schema

    # Create required tables in tenant schema
    Mcp.Repo.query!("""
      CREATE TABLE IF NOT EXISTS "#{schema}".agent_blueprints (
        id uuid PRIMARY KEY,
        name text,
        description text,
        base_prompt text,
        tools jsonb,
        routing_config jsonb,
        knowledge_base_ids jsonb,
        inserted_at timestamp(6),
        updated_at timestamp(6)
      )
    """)

    Mcp.Repo.query!("""
      CREATE TABLE IF NOT EXISTS "#{schema}".instruction_sets (
        id uuid PRIMARY KEY,
        name text,
        instructions text,
        blueprint_id uuid,
        tenant_id uuid,
        inserted_at timestamp(6),
        updated_at timestamp(6)
      )
    """)

    # Create blueprint with tenant context
    blueprint =
      Ash.create!(
        AgentBlueprint,
        %{
          name: "Generic Agent",
          base_prompt: "Be helpful.",
          tools: []
        },
        tenant: schema
      )

    # Create API Key using Platform.ApiKey
    {:ok, api_key} =
      ApiKey.create(%{
        prefix: "test",
        type: :developer,
        scopes: ["instruction_sets:write"],
        owner_id: tenant.id,
        owner_type: :tenant
      })

    # Get the actual raw key from metadata
    raw_key = Ash.Resource.get_metadata(api_key, :raw_key)

    %{blueprint: blueprint, api_key: raw_key, tenant: tenant}
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
