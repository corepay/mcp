# credo:disable-for-this-file Credo.Check.Readability.StringSigils
defmodule Mcp.Underwriting.Services.PrecedentEngineTest do
  use Mcp.DataCase, async: true
  alias Mcp.Underwriting.{Activity, Application, RiskAssessment}
  alias Mcp.Underwriting.Services.PrecedentEngine

  setup do
    unique_id = System.unique_integer([:positive])
    schema = "tenant_precedent_test_#{unique_id}"
    Mcp.Repo.query!("CREATE SCHEMA IF NOT EXISTS \"#{schema}\"")

    # DDL for underwriting_applications
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".underwriting_applications (
      id uuid PRIMARY KEY,
      status text,
      application_data jsonb,
      risk_score integer,
      subject_id uuid,
      subject_type text,
      submitted_at timestamp,
      sla_due_at timestamp,
      inserted_at timestamp,
      updated_at timestamp
    )")

    # DDL for risk_assessments
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".risk_assessments (
      id uuid PRIMARY KEY,
      score integer,
      factors jsonb,
      recommendation text,
      subject_id uuid,
      subject_type text,
      application_id uuid REFERENCES \"#{schema}\".underwriting_applications(id),
      policy_hash text,
      inserted_at timestamp,
      updated_at timestamp
    )")

    # DDL for underwriting_activities
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".underwriting_activities (
      id uuid PRIMARY KEY,
      type text,
      metadata jsonb,
      actor_id uuid,
      application_id uuid REFERENCES \"#{schema}\".underwriting_applications(id),
      inserted_at timestamp,
      updated_at timestamp
    )")

    {:ok, %{schema: schema}}
  end

  test "harvest/2 collects past assessments and activities", %{schema: schema} do
    subject_id = Ecto.UUID.generate()

    # 1. Create past assessments
    # We need an application first
    {:ok, app} =
      Application
      |> Ash.Changeset.for_create(:create, %{
        application_data: %{"business_name" => "Precedent Corp"},
        status: :approved,
        subject_id: subject_id,
        subject_type: :merchant
      })
      |> Ash.create(tenant: schema)

    {:ok, _ra} =
      RiskAssessment
      |> Ash.Changeset.for_create(:create, %{
        score: 85,
        factors: %{"credit" => "good"},
        recommendation: :approve,
        subject_id: subject_id,
        subject_type: :merchant,
        application_id: app.id,
        policy_hash: "mock-hash-123"
      })
      |> Ash.create(tenant: schema)

    # 2. Create past activities
    {:ok, _act} =
      Activity
      |> Ash.Changeset.for_create(:create, %{
        type: :internal_note,
        metadata: %{"note" => "Subject looks stable."},
        application_id: app.id
      })
      |> Ash.create(tenant: schema)

    # 3. Harvest precedents
    summary = PrecedentEngine.harvest(subject_id, schema)

    assert summary =~ "PAST DECISION LINEAGE"
    assert summary =~ "Score 85"
    assert summary =~ "mock-hash-123"
    assert summary =~ "Subject looks stable"
  end

  test "harvest/2 returns empty message when no data exists", %{schema: schema} do
    subject_id = Ecto.UUID.generate()
    summary = PrecedentEngine.harvest(subject_id, schema)
    assert summary == "No previous precedents found for this subject."
  end
end
