defmodule Mcp.Underwriting.PerformanceTest do
  use Mcp.DataCase, async: false
  alias Mcp.Underwriting.{Application, BankProfile, Processor, RiskAssessment}
  alias Mcp.Underwriting.Services.PlacementIntelligence

  setup do
    unique_id = System.unique_integer([:positive])
    schema = "acq_test_perf_#{unique_id}"
    Mcp.Repo.query!("CREATE SCHEMA IF NOT EXISTS \"#{schema}\"")

    # DDL for necessary tables in the tenant schema
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".merchants (
      id uuid PRIMARY KEY,
      business_name text,
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

    # 1. Create a Processor (Public/Global)
    processor =
      Processor
      |> Ash.Changeset.for_create(:create, %{name: "GlobalProc_#{unique_id}"})
      |> Ash.create!(authorize?: false)

    # 2. Create an Application and Assessment (Tenant-scoped)
    merchant_id = Ecto.UUID.generate()

    Mcp.Repo.query!(
      "INSERT INTO \"#{schema}\".merchants (id, business_name, inserted_at, updated_at) VALUES ('#{merchant_id}', 'Perf Corp', now(), now())"
    )

    app =
      Application
      |> Ash.Changeset.for_create(:create, %{
        subject_id: merchant_id,
        subject_type: :merchant,
        status: :submitted,
        application_data: %{
          "business_name" => "Performance Corp",
          "industry" => "retail",
          "monthly_volume" => 50_000,
          "country" => "US"
        }
      })
      |> Ash.create!(tenant: schema, authorize?: false)

    assessment =
      RiskAssessment
      |> Ash.Changeset.for_create(:create, %{
        score: 75,
        factors: %{"history" => 10, "volatility" => 5},
        application_id: app.id,
        subject_id: merchant_id,
        subject_type: :merchant,
        recommendation: :manual_review
      })
      |> Ash.create!(tenant: schema, authorize?: false)

    {:ok,
     %{
       tenant: schema,
       app: app,
       assessment: assessment,
       processor: processor,
       merchant_id: merchant_id
     }}
  end

  @tag timeout: :infinity
  test "PlacementIntelligence performance with large bank profiles", %{
    tenant: tenant,
    app: app,
    assessment: assessment,
    processor: processor
  } do
    # 3. Seed 500 Bank Profiles
    IO.puts("\nSeeding 500 bank profiles...")

    for i <- 1..500 do
      BankProfile
      |> Ash.Changeset.for_create(:create, %{
        name: "Bank_#{i}",
        processor_id: processor.id,
        risk_weight: Enum.random(1..100),
        appetite_rules: %{
          "min_score" => Enum.random(0..60),
          "max_monthly_volume" => Enum.random(100_000..1_000_000),
          "allowed_industries" => ["retail", "ecommerce", "service"]
        }
      })
      |> Ash.create!(authorize?: false)
    end

    IO.puts("Seeding complete.")

    # 4. Profile the suggest_placement function
    # Run a warm-up
    PlacementIntelligence.suggest_placement(app.id, assessment.id, tenant)

    # Measure 20 runs for better average
    iterations = 20

    {total_time, _} =
      :timer.tc(fn ->
        Enum.each(1..iterations, fn _ ->
          PlacementIntelligence.suggest_placement(app.id, assessment.id, tenant)
        end)
      end)

    avg_time_ms = total_time / iterations / 1000

    IO.puts("Average placement suggestion time (500 profiles): #{avg_time_ms}ms")

    assert avg_time_ms < 50, "Performance threshold exceeded! Average time: #{avg_time_ms}ms"
  end
end
