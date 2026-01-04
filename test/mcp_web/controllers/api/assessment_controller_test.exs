defmodule McpWeb.Api.AssessmentControllerTest do
  use McpWeb.ConnCase

  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.AgentBlueprint
  alias Mcp.Underwriting.InstructionSet
  alias Mcp.Underwriting.Pipeline

  setup %{conn: conn} do
    # Create tenant first (required for multitenancy)
    tenant =
      Tenant
      |> Ash.Changeset.for_create(:create, %{
        name: "Assessment Test Tenant",
        slug: "assessment-test-#{:rand.uniform(999_999)}",
        subdomain: "assessment-#{:rand.uniform(999_999)}"
      })
      |> Ash.create!()

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

    Mcp.Repo.query!("""
      CREATE TABLE IF NOT EXISTS "#{schema}".pipelines (
        id uuid PRIMARY KEY,
        name text,
        description text,
        stages jsonb,
        review_required boolean DEFAULT false,
        tenant_id uuid,
        inserted_at timestamp(6),
        updated_at timestamp(6)
      )
    """)

    Mcp.Repo.query!("""
      CREATE TABLE IF NOT EXISTS "#{schema}".executions (
        id uuid PRIMARY KEY,
        pipeline_id uuid,
        subject_id uuid,
        subject_type text,
        status text,
        context jsonb,
        results jsonb,
        inserted_at timestamp(6),
        updated_at timestamp(6)
      )
    """)

    # 1. Create a Blueprint
    blueprint =
      Ash.create!(
        AgentBlueprint,
        %{
          name: "FinancialAnalyst",
          base_prompt: "Analyze financial data.",
          tools: [:calculator]
        },
        tenant: schema
      )

    # 2. Create a Pipeline using that Blueprint
    pipeline =
      Ash.create!(
        Pipeline,
        %{
          name: "Mortgage Pipeline",
          stages: [%{blueprint_id: blueprint.id, step_name: "Analysis"}]
        },
        tenant: schema
      )

    # 3. Create an Instruction Set
    instruction_set =
      Ash.create!(
        InstructionSet,
        %{
          name: "Conservative Policy",
          instructions:
            "Reject if DTI > 0.43. Respond with JSON: {\"decision\": \"approve\" | \"reject\", \"dti\": <number>}",
          blueprint_id: blueprint.id
        },
        tenant: schema
      )

    # 4. Create API Key associated with the tenant
    raw_key =
      Mcp.TestFactories.create_api_key(
        ["assessments:write", "assessments:read"],
        owner_id: tenant.id,
        owner_type: :tenant
      )

    conn =
      conn
      |> Plug.Conn.put_req_header("x-forwarded-host", "localhost")
      |> Plug.Conn.put_req_header("x-api-key", raw_key)

    %{
      pipeline: pipeline,
      blueprint: blueprint,
      instruction_set: instruction_set,
      conn: conn,
      tenant: schema
    }
  end

  describe "POST /api/assessments" do
    @tag timeout: 120_000
    test "creates an execution and runs the pipeline synchronously", %{
      conn: conn,
      pipeline: pipeline,
      tenant: tenant
    } do
      payload = %{
        "pipeline_id" => pipeline.id,
        "subject_id" => Ecto.UUID.generate(),
        "subject_type" => "individual",
        "context" => %{
          "annual_volume" => 10_000,
          "debt" => 3000
        }
      }

      conn =
        conn
        |> put_req_header("accept", "application/vnd.mcp.v1+json")
        |> post(~p"/api/assessments", payload)

      assert %{"data" => %{"id" => id, "status" => status}} = json_response(conn, 201)

      # Verify initial status is pending (async)
      assert status == "pending"

      # Drain queue to run orchestrator
      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :underwriting)

      # Fetch updated execution
      execution = Ash.get!(Mcp.Underwriting.Execution, id, tenant: tenant)
      assert execution.status == :completed
      results = execution.results

      assert Map.has_key?(results, "FinancialAnalyst")
      # We check for the structure, as the LLM's math/decision might vary slightly without tools
      assert Map.has_key?(results["FinancialAnalyst"], "decision")
      assert Map.has_key?(results["FinancialAnalyst"], "dti")
    end
  end

  describe "GET /api/assessments/:id" do
    test "retrieves the execution", %{conn: conn, pipeline: pipeline, tenant: tenant} do
      execution =
        Ash.create!(
          Mcp.Underwriting.Execution,
          %{
            pipeline_id: pipeline.id,
            subject_id: Ecto.UUID.generate(),
            subject_type: :individual,
            status: :completed
          },
          tenant: tenant
        )

      execution =
        execution
        |> Ash.Changeset.for_update(:update, %{
          results: %{"FinancialAnalyst" => %{"decision" => "approve"}}
        })
        |> Ash.update!(tenant: tenant)

      conn =
        conn
        |> put_req_header("accept", "application/vnd.mcp.v1+json")
        |> get(~p"/api/assessments/#{execution.id}")

      assert %{"data" => %{"id" => id, "status" => "completed", "results" => results}} =
               json_response(conn, 200)

      assert id == execution.id
      assert results["FinancialAnalyst"]["decision"] == "approve"
    end
  end
end
