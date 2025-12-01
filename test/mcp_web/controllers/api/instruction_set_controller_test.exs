defmodule McpWeb.Api.InstructionSetControllerTest do
  use McpWeb.ConnCase

  alias Mcp.Accounts.ApiKey
  alias Mcp.Underwriting.AgentBlueprint

  setup do
    blueprint =
      Ash.create!(AgentBlueprint, %{
        name: "Generic Agent",
        base_prompt: "Be helpful.",
        tools: []
      })

    # Create API Key
    key = "mcp_sk_#{Ecto.UUID.generate()}"

    ApiKey.create!(%{
      name: "Test Key",
      key: key,
      permissions: ["instruction_sets:write"]
    })

    %{blueprint: blueprint, api_key: key}
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
