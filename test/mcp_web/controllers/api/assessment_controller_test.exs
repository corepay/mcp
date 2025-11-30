defmodule McpWeb.Api.AssessmentControllerTest do
  use McpWeb.ConnCase

  alias Mcp.Underwriting.{AgentBlueprint, Pipeline, InstructionSet}

  setup do
    # 1. Create a Blueprint
    blueprint = Ash.create!(AgentBlueprint, %{
      name: "FinancialAnalyst",
      base_prompt: "Analyze financial data.",
      tools: [:calculator]
    })

    # 2. Create a Pipeline using that Blueprint
    pipeline = Ash.create!(Pipeline, %{
      name: "Mortgage Pipeline",
      stages: [%{blueprint_id: blueprint.id, step_name: "Analysis"}]
    })

    # 3. Create an Instruction Set
    instruction_set = Ash.create!(InstructionSet, %{
      name: "Conservative Policy",
      instructions: "Reject if DTI > 0.43. Respond with JSON: {\"decision\": \"approve\" | \"reject\", \"dti\": <number>}",
      blueprint_id: blueprint.id
    })

    %{pipeline: pipeline, blueprint: blueprint, instruction_set: instruction_set}
  end

  describe "POST /api/assessments" do
    @tag timeout: 120_000
    test "creates an execution and runs the pipeline synchronously", %{conn: conn, pipeline: pipeline} do
      payload = %{
        "pipeline_id" => pipeline.id,
        "subject_id" => Ecto.UUID.generate(),
        "subject_type" => "individual",
        "context" => %{
          "income" => 10000,
          "debt" => 3000
        }
      }

      conn = 
        conn
        |> put_req_header("accept", "application/vnd.mcp.v1+json")
        |> post(~p"/api/assessments", payload)

      assert %{"data" => %{"id" => id, "status" => status, "results" => results}} = json_response(conn, 201)
      
      # Verify Orchestrator ran (Synchronous for v1)
      assert status == "completed"
      assert Map.has_key?(results, "FinancialAnalyst")
      # We check for the structure, as the LLM's math/decision might vary slightly without tools
      assert Map.has_key?(results["FinancialAnalyst"], "decision")
      assert Map.has_key?(results["FinancialAnalyst"], "dti")
    end
  end

  describe "GET /api/assessments/:id" do
    test "retrieves the execution", %{conn: conn, pipeline: pipeline} do
      execution = Ash.create!(Mcp.Underwriting.Execution, %{
        pipeline_id: pipeline.id,
        subject_id: Ecto.UUID.generate(),
        subject_type: :individual,
        status: :completed
      })

      execution = 
        execution
        |> Ash.Changeset.for_update(:update, %{results: %{"FinancialAnalyst" => %{"decision" => "approve"}}})
        |> Ash.update!()

      conn = 
        conn
        |> put_req_header("accept", "application/vnd.mcp.v1+json")
        |> get(~p"/api/assessments/#{execution.id}")

      assert %{"data" => %{"id" => id, "status" => "completed", "results" => results}} = json_response(conn, 200)
      assert id == execution.id
      assert results["FinancialAnalyst"]["decision"] == "approve"
    end
  end
end
