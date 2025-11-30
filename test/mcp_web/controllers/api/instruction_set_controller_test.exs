defmodule McpWeb.Api.InstructionSetControllerTest do
  use McpWeb.ConnCase

  alias Mcp.Underwriting.AgentBlueprint

  setup do
    blueprint = Ash.create!(AgentBlueprint, %{
      name: "Generic Agent",
      base_prompt: "Be helpful.",
      tools: []
    })
    %{blueprint: blueprint}
  end

  describe "POST /api/instruction_sets" do
    test "creates a new instruction set", %{conn: conn, blueprint: blueprint} do
      payload = %{
        "name" => "New Policy",
        "instructions" => "Do this.",
        "blueprint_id" => blueprint.id
      }

      conn = 
        conn
        |> put_req_header("accept", "application/vnd.mcp.v1+json")
        |> post(~p"/api/instruction_sets", payload)

      assert %{"data" => %{"id" => _id, "name" => "New Policy"}} = json_response(conn, 201)
    end
  end
end
