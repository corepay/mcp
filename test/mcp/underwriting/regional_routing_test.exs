defmodule Mcp.Underwriting.RegionalRoutingTest do
  use Mcp.DataCase, async: false
  alias Mcp.Underwriting.{Application, BankProfile, Processor, RiskAssessment}
  alias Mcp.Underwriting.Services.PlacementIntelligence

  setup do
    unique_id = System.unique_integer([:positive])
    schema = "acq_test_region_#{unique_id}"
    Mcp.Repo.query!("CREATE SCHEMA IF NOT EXISTS \"#{schema}\"")

    # DDL for necessary tables
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".merchants (
      id uuid PRIMARY KEY,
      business_name text,
      country text,
      inserted_at timestamp(6),
      updated_at timestamp(6)
    )")

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

    # 1. Create two Processors: US and EU using Seed
    us_proc =
      Ash.Seed.seed!(Processor, %{name: "US_Proc", supported_regions: ["US"], status: :active})

    eu_proc =
      Ash.Seed.seed!(Processor, %{
        name: "EU_Proc",
        supported_regions: ["GB", "FR", "DE"],
        status: :active
      })

    # 2. Create Bank Profiles for both using Seed
    us_bank =
      Ash.Seed.seed!(BankProfile, %{name: "US Bank", processor_id: us_proc.id})

    eu_bank =
      Ash.Seed.seed!(BankProfile, %{name: "EU Bank", processor_id: eu_proc.id})

    {:ok, schema: schema, us_bank: us_bank, eu_bank: eu_bank}
  end

  test "routes US merchant to US bank", %{schema: schema, us_bank: us_bank} do
    merchant_id = Ecto.UUID.generate()

    Mcp.Repo.query!(
      "INSERT INTO \"#{schema}\".merchants (id, business_name, country, inserted_at, updated_at) VALUES ('#{merchant_id}', 'US Corp', 'US', now(), now())"
    )

    app = create_app(schema, merchant_id)
    assessment = create_assessment(schema, app.id, merchant_id)

    {:ok, result} = PlacementIntelligence.suggest_placement(app.id, assessment.id, schema)
    assert result.profile.id == us_bank.id
  end

  test "routes EU (France) merchant to EU bank", %{schema: schema, eu_bank: eu_bank} do
    merchant_id = Ecto.UUID.generate()

    Mcp.Repo.query!(
      "INSERT INTO \"#{schema}\".merchants (id, business_name, country, inserted_at, updated_at) VALUES ('#{merchant_id}', 'FR Corp', 'FR', now(), now())"
    )

    app = create_app(schema, merchant_id)
    assessment = create_assessment(schema, app.id, merchant_id)

    {:ok, result} = PlacementIntelligence.suggest_placement(app.id, assessment.id, schema)
    assert result.profile.id == eu_bank.id
  end

  test "returns error if no regional bank available", %{schema: schema} do
    merchant_id = Ecto.UUID.generate()

    Mcp.Repo.query!(
      "INSERT INTO \"#{schema}\".merchants (id, business_name, country, inserted_at, updated_at) VALUES ('#{merchant_id}', 'JP Corp', 'JP', now(), now())"
    )

    app = create_app(schema, merchant_id)
    assessment = create_assessment(schema, app.id, merchant_id)

    assert {:error, :no_eligible_banks} ==
             PlacementIntelligence.suggest_placement(app.id, assessment.id, schema)
  end

  defp create_app(schema, merchant_id) do
    Ash.Seed.seed!(
      Application,
      %{
        id: Ecto.UUID.generate(),
        subject_id: merchant_id,
        subject_type: :merchant,
        status: :submitted,
        application_data: %{}
      },
      tenant: schema
    )
  end

  defp create_assessment(schema, app_id, merchant_id) do
    Ash.Seed.seed!(
      RiskAssessment,
      %{
        id: Ecto.UUID.generate(),
        score: 80,
        application_id: app_id,
        subject_id: merchant_id,
        subject_type: :merchant,
        recommendation: :approve,
        factors: %{}
      },
      tenant: schema
    )
  end
end
