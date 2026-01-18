defmodule Mcp.Underwriting.UaasLineageTest do
  @moduledoc """
  "World-Class" verification of the Agentic Underwriting-as-a-Service logic.
  Verifies SLA calculation, Activity logging, and Playbook Versioning (lineage).
  """
  use Mcp.DataCase
  alias Mcp.Platform.Tenant

  alias Mcp.Underwriting.{
    Activity,
    Application,
    Gateway,
    InstructionSet,
    RiskAssessment
  }

  require Ash.Query
  import Ash.Expr

  setup do
    unique_id = System.unique_integer([:positive])
    tenant_id = Ecto.UUID.generate()
    schema = "acq_test_lineage_#{unique_id}"

    _tenant =
      Mcp.Repo.insert!(%Tenant{
        id: tenant_id,
        name: "Lineage Test Tenant #{unique_id}",
        slug: "lineage-#{unique_id}",
        subdomain: "lineage-#{unique_id}",
        company_schema: schema,
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      })

    # DDL Setup with strict compliance to Ash Resource schemas
    Mcp.Repo.query!("CREATE SCHEMA IF NOT EXISTS \"#{schema}\"")

    # Merchants
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".merchants (
      id uuid PRIMARY KEY,
      business_name text,
      status text,
      inserted_at timestamp(6),
      updated_at timestamp(6)
    )")

    # Vendor Settings
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".underwriting_vendor_settings (
      id uuid PRIMARY KEY,
      preferred_vendor text,
      circuit_breaker_enabled boolean,
      sla_hours integer,
      auto_approve_threshold integer,
      auto_reject_threshold integer,
      webhook_token text,
      inserted_at timestamp(6),
      updated_at timestamp(6)
    )")

    # Agent Blueprints
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".agent_blueprints (
      id uuid PRIMARY KEY,
      name text,
      base_prompt text,
      description text,
      tools jsonb,
      routing_config jsonb,
      knowledge_base_ids jsonb,
      inserted_at timestamp(6),
      updated_at timestamp(6)
    )")

    # Instruction Sets
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".instruction_sets (
      id uuid PRIMARY KEY,
      name text,
      instructions text,
      hash text,
      blueprint_id uuid,
      tenant_id uuid,
      inserted_at timestamp(6),
      updated_at timestamp(6)
    )")

    # Underwriting Clients
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".underwriting_clients (
      id uuid PRIMARY KEY,
      type text,
      email text,
      phone text,
      external_id text,
      person_details jsonb,
      company_details jsonb,
      application_id uuid,
      inserted_at timestamp(6),
      updated_at timestamp(6)
    )")

    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".underwriting_checks (
      id uuid PRIMARY KEY,
      type text,
      status text,
      outcome text,
      external_id text,
      raw_result jsonb,
      client_id uuid,
      document_id uuid,
      inserted_at timestamp(6),
      updated_at timestamp(6)
    )")

    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".underwriting_documents (
      id uuid PRIMARY KEY,
      file_path text,
      file_name text,
      mime_type text,
      document_type text,
      status text,
      application_id uuid,
      client_id uuid,
      inserted_at timestamp(6),
      updated_at timestamp(6)
    )")

    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".underwriting_addresses (
      id uuid PRIMARY KEY,
      line1 text,
      line2 text,
      city text,
      state text,
      postal_code text,
      country text,
      type text,
      client_id uuid,
      inserted_at timestamp(6),
      updated_at timestamp(6)
    )")

    # Application
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".underwriting_applications (
      id uuid PRIMARY KEY,
      status text,
      application_data jsonb,
      risk_score integer,
      subject_id uuid,
      subject_type text,
      submitted_at timestamp(6),
      sla_due_at timestamp(6),
      inserted_at timestamp(6),
      updated_at timestamp(6)
    )")

    # Activities
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".underwriting_activities (
      id uuid PRIMARY KEY,
      type text,
      metadata jsonb,
      actor_id uuid,
      application_id uuid,
      inserted_at timestamp(6),
      updated_at timestamp(6)
    )")

    # Risk Assessments
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".risk_assessments (
      id uuid PRIMARY KEY,
      score integer,
      factors jsonb,
      recommendation text,
      subject_id uuid,
      subject_type text,
      application_id uuid,
      policy_hash text,
      inserted_at timestamp(6),
      updated_at timestamp(6)
    )")

    # Seed Vendor Settings via raw SQL to bypass policies
    settings_id = Ecto.UUID.generate()
    Mcp.Repo.query!("
      INSERT INTO \"#{schema}\".underwriting_vendor_settings
      (id, preferred_vendor, circuit_breaker_enabled, sla_hours, auto_approve_threshold, auto_reject_threshold, webhook_token, inserted_at, updated_at)
      VALUES
      ('#{settings_id}', 'idenfy', true, 48, 95, 50, 'test_token', now(), now())
    ")

    {:ok, schema: schema}
  end

  test "full underwriting life-cycle with deterministic lineage", %{schema: schema} do
    # 1. Create a Blueprint and InstructionSet
    blueprint =
      Mcp.Underwriting.AgentBlueprint
      |> Ash.Changeset.for_create(:create, %{name: "Tier 1 Blueprint", base_prompt: "Be strict."})
      |> Ash.create!(tenant: schema, authorize?: false)

    instruction_set =
      InstructionSet
      |> Ash.Changeset.for_create(:create, %{
        name: "Standard Risk Rules v1",
        instructions: "Verify all documents. High suspicion of new entities.",
        blueprint_id: blueprint.id
      })
      |> Ash.create!(tenant: schema, authorize?: false)

    assert instruction_set.hash != nil
    initial_hash = instruction_set.hash

    # 2. Create and Submit Application
    merchant_id = Ecto.UUID.generate()

    Mcp.Repo.query!(
      "INSERT INTO \"#{schema}\".merchants (id, business_name, status, inserted_at, updated_at) VALUES ('#{merchant_id}', 'Lineage Corp', 'active', now(), now())"
    )

    app =
      Application
      |> Ash.Changeset.for_create(:create, %{
        subject_id: merchant_id,
        subject_type: :merchant,
        status: :draft
      })
      |> Ash.create!(tenant: schema, authorize?: false)

    # Trigger 'submit' update
    submitted_app =
      app
      |> Ash.Changeset.for_update(:submit, %{application_data: %{"legal_name" => "Lineage Corp"}})
      |> Ash.update!(tenant: schema, authorize?: false)

    # 3. Verify SLA Calculation
    assert submitted_app.status == :submitted
    assert submitted_app.submitted_at != nil
    assert submitted_app.sla_due_at != nil

    diff_hours = DateTime.diff(submitted_app.sla_due_at, submitted_app.submitted_at, :hour)
    assert diff_hours == 48

    # 4. Verify Activity Logging
    activities = Activity |> Ash.read!(tenant: schema, authorize?: false)

    assert Enum.any?(activities, fn a ->
             a.type == :status_change && a.metadata["event"] == "application_submitted"
           end)

    # 5. Run Screening & Verify Lineage
    Elixir.Application.put_env(:mcp, :underwriting_adapter, :mock)

    {:ok, score} =
      Gateway.screen_application(submitted_app.id, tenant: schema, policy_hash: initial_hash)

    assessment =
      RiskAssessment
      |> Ash.Query.filter(expr(application_id == ^submitted_app.id))
      |> Ash.read_one!(tenant: schema, authorize?: false)

    assert assessment.score == score
    assert assessment.policy_hash == initial_hash

    # 6. Verify Deterministic Evolution
    updated_instructions =
      instruction_set
      |> Ash.Changeset.for_update(:update, %{instructions: "New rules override v1."})
      |> Ash.update!(tenant: schema, authorize?: false)

    assert updated_instructions.hash != initial_hash
  end
end
