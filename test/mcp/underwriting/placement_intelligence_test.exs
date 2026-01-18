# credo:disable-for-this-file Credo.Check.Readability.StringSigils
defmodule Mcp.Underwriting.Services.PlacementIntelligenceTest do
  use Mcp.DataCase, async: true
  alias Mcp.Underwriting.{Application, BankProfile, Processor, RiskAssessment}
  alias Mcp.Underwriting.Services.PlacementIntelligence

  setup do
    unique_id = System.unique_integer([:positive])
    schema = "tenant_placement_test_#{unique_id}"
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

    # Create a Global Processor and Profiles (outside schema, bypass auth for test fixtures)
    processor =
      Processor.create!(%{name: "Test Processor", adapter: "TestAdapter"}, authorize?: false)

    BankProfile.create!(
      %{
        name: "Retail Safe",
        processor_id: processor.id,
        risk_weight: 20,
        appetite_rules: %{
          "allowed_industries" => ["retail"],
          "min_score" => 80
        }
      },
      authorize?: false
    )

    BankProfile.create!(
      %{
        name: "High Risk High Return",
        processor_id: processor.id,
        risk_weight: 80,
        appetite_rules: %{
          "allowed_industries" => ["gaming"],
          "min_score" => 60
        }
      },
      authorize?: false
    )

    {:ok, %{schema: schema}}
  end

  test "suggest_placement/3 selects best bank based on appetite", %{schema: schema} do
    subject_id = Ecto.UUID.generate()

    # 1. Retail Application (High Score)
    {:ok, app_retail} =
      Application.create(
        %{
          application_data: %{
            "industry" => "retail",
            "monthly_volume" => 10_000,
            "country" => "US"
          },
          subject_id: subject_id,
          subject_type: :merchant
        },
        tenant: schema,
        authorize?: false
      )

    {:ok, ra_retail} =
      RiskAssessment.create(
        %{
          score: 90,
          recommendation: :approve,
          application_id: app_retail.id,
          subject_id: subject_id,
          subject_type: :merchant
        },
        tenant: schema,
        authorize?: false
      )

    {:ok, result} = PlacementIntelligence.suggest_placement(app_retail.id, ra_retail.id, schema)
    assert result.profile.name == "Retail Safe"

    # 2. Gaming Application (Mid Score)
    {:ok, app_gaming} =
      Application.create(
        %{
          application_data: %{
            "industry" => "gaming",
            "monthly_volume" => 50_000,
            "country" => "US"
          },
          subject_id: subject_id,
          subject_type: :merchant
        },
        tenant: schema,
        authorize?: false
      )

    {:ok, ra_gaming} =
      RiskAssessment.create(
        %{
          score: 65,
          recommendation: :approve,
          application_id: app_gaming.id,
          subject_id: subject_id,
          subject_type: :merchant
        },
        tenant: schema,
        authorize?: false
      )

    {:ok, result_gaming} =
      PlacementIntelligence.suggest_placement(app_gaming.id, ra_gaming.id, schema)

    assert result_gaming.profile.name == "High Risk High Return"
  end

  test "suggest_placement/3 returns error when no banks match", %{schema: schema} do
    subject_id = Ecto.UUID.generate()

    # Crypto Application (Not in allowed list)
    {:ok, app} =
      Application.create(
        %{
          application_data: %{"industry" => "crypto", "country" => "US"},
          subject_id: subject_id,
          subject_type: :merchant
        },
        tenant: schema,
        authorize?: false
      )

    {:ok, ra} =
      RiskAssessment.create(
        %{
          score: 95,
          recommendation: :approve,
          application_id: app.id,
          subject_id: subject_id,
          subject_type: :merchant
        },
        tenant: schema,
        authorize?: false
      )

    assert {:error, :no_eligible_banks} ==
             PlacementIntelligence.suggest_placement(app.id, ra.id, schema)
  end
end
