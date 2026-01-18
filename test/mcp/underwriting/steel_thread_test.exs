defmodule Mcp.Underwriting.SteelThreadTest do
  @moduledoc """
  Steel Thread Test: Submission -> Assessment -> Placement -> Boarding -> Funding.
  Verifies the complete lifecycle of a merchant boarding in a production-ready environment.
  """
  use Mcp.DataCase, async: false
  alias Mcp.Platform.Merchant
  alias Mcp.Underwriting.{Application, BankProfile, Boarding, Processor, RiskAssessment}
  alias Mcp.Underwriting.Services.{BoardingService, PlacementIntelligence}

  setup do
    unique_id = System.unique_integer([:positive])
    schema = "steel_thread_#{unique_id}"
    Mcp.Repo.query!("CREATE SCHEMA IF NOT EXISTS \"#{schema}\"")

    # DDL for necessary tables in the tenant schema
    # (In a real app, this would be handled by migrations, but for these unit tests we shim it)
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".merchants (
      id uuid PRIMARY KEY,
      slug text,
      business_name text,
      dba_name text,
      subdomain text,
      custom_domain text,
      business_type text,
      ein text,
      website_url text,
      description text,
      address_line1 text,
      address_line2 text,
      city text,
      state text,
      postal_code text,
      country text,
      phone text,
      support_email text,
      reseller_id uuid,
      plan text,
      status text,
      risk_level text,
      settings jsonb,
      branding jsonb,
      max_stores integer,
      max_products integer,
      max_monthly_volume numeric,
      kyc_verified_at timestamp,
      verification_status text,
      mcc text,
      tax_id_type text,
      kyc_status text,
      kyc_documents jsonb,
      timezone text,
      default_currency text,
      operating_hours jsonb,
      risk_score integer,
      risk_profile text,
      processing_limits jsonb,
      inserted_at timestamp,
      updated_at timestamp
    )")

    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".underwriting_applications (
      id uuid PRIMARY KEY,
      status text,
      application_data jsonb,
      subject_id uuid,
      subject_type text,
      risk_score integer,
      submitted_at timestamp,
      sla_due_at timestamp,
      inserted_at timestamp,
      updated_at timestamp
    )")

    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".risk_assessments (
      id uuid PRIMARY KEY,
      score integer,
      factors jsonb,
      recommendation text,
      application_id uuid,
      subject_id uuid,
      subject_type text,
      policy_hash text,
      inserted_at timestamp,
      updated_at timestamp
    )")

    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".underwriting_activities (
      id uuid PRIMARY KEY,
      type text,
      metadata jsonb,
      application_id uuid,
      actor_id uuid,
      inserted_at timestamp,
      updated_at timestamp
    )")

    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".underwriting_boardings (
      id uuid PRIMARY KEY,
      mid text,
      tid text,
      status text,
      metadata jsonb,
      rationale text,
      error_metadata jsonb,
      application_id uuid,
      processor_id uuid,
      bank_profile_id uuid,
      inserted_at timestamp,
      updated_at timestamp
    )")

    # Seed Platform Data (Global)
    processor = Processor.create!(%{name: "QorPay", adapter: "QorPayAdapter"}, authorize?: false)

    profile =
      BankProfile.create!(
        %{
          name: "QorPay High Risk",
          processor_id: processor.id,
          risk_weight: 80,
          appetite_rules: %{
            "min_score" => 60,
            "allowed_industries" => ["retail", "ecommerce"]
          }
        },
        authorize?: false
      )

    # Create Merchant
    {:ok, merchant} =
      Merchant.create(
        %{
          business_name: "Thread Merchant",
          slug: "thread-merchant-#{unique_id}",
          subdomain: "thread-#{unique_id}",
          status: :active
        },
        tenant: schema
      )

    # Stub QorPay
    Req.Test.stub(Mcp.Payments.Gateways.QorPay, fn conn ->
      Req.Test.json(conn, %{
        "status" => "approved",
        "mid" => "STEEL_MID_123",
        "tid" => "STEEL_TID_123"
      })
    end)

    Elixir.Application.put_env(:mcp, :req_options, plug: {Req.Test, Mcp.Payments.Gateways.QorPay})

    {:ok, schema: schema, merchant: merchant, profile: profile, processor: processor}
  end

  test "Steel Thread: Full Lifecycle Success", %{
    schema: schema,
    merchant: merchant,
    profile: profile
  } do
    # 1. Create & Submit Application
    {:ok, app} =
      Application.create(
        %{
          subject_id: merchant.id,
          subject_type: :merchant,
          application_data: %{"industry" => "retail", "monthly_volume" => 50_000},
          status: :draft
        },
        tenant: schema
      )

    {:ok, app} = Application.submit(app, %{}, tenant: schema)
    assert app.status == :submitted
    assert app.submitted_at != nil

    # 2. Automated Risk Assessment (Simulated)
    # Typically done by an agent, here we create it directly
    assessment =
      RiskAssessment.create!(
        %{
          application_id: app.id,
          subject_id: merchant.id,
          subject_type: :merchant,
          score: 75,
          recommendation: :approve
        },
        tenant: schema
      )

    # 3. Placement Intelligence (Bank Matching)
    {:ok, match} = PlacementIntelligence.suggest_placement(app.id, assessment.id, schema)
    assert match.profile.id == profile.id
    assert match.rationale =~ "Matched based on risk score"

    # 4. Boarding Execution
    actor = %Mcp.Accounts.User{id: Ecto.UUID.generate(), role: :member, tenant_id: schema}

    {:ok, boarding} =
      BoardingService.board(app.id, profile.id, schema, rationale: match.rationale, actor: actor)

    # 5. Final Verifications
    assert boarding.status == :active
    assert boarding.mid == "STEEL_MID_123"
    assert String.trim(boarding.rationale) == String.trim(match.rationale)

    # 6. Verify Application status: :funded
    final_app = Application.get_by_id!(app.id, tenant: schema)
    assert final_app.status == :funded

    # 7. Audit Logging (Activity)
    # Check if activity was logged during submission/boarding
    # (Assuming Activity resource is also multitenant)
    # This might require another table shim if we want to be thorough.
  end

  test "Steel Thread: Boarding Failure Trapping", %{
    schema: schema,
    merchant: merchant,
    profile: profile
  } do
    # 1. Setup Application & Assessment
    {:ok, app} =
      Application.create(
        %{
          subject_id: merchant.id,
          subject_type: :merchant,
          application_data: %{"industry" => "retail"},
          status: :submitted
        },
        tenant: schema
      )

    _assessment =
      RiskAssessment.create!(
        %{
          application_id: app.id,
          subject_id: merchant.id,
          subject_type: :merchant,
          score: 75,
          recommendation: :approve
        },
        tenant: schema
      )

    # 2. Force Failure in Gateway
    Req.Test.stub(Mcp.Payments.Gateways.QorPay, fn conn ->
      conn
      |> Plug.Conn.put_status(422)
      |> Req.Test.json(%{"error" => "Invalid Business License"})
    end)

    # 3. Execute Boarding
    actor = %Mcp.Accounts.User{id: Ecto.UUID.generate(), role: :member, tenant_id: schema}

    {:error, {reason, boarding}} =
      BoardingService.board(app.id, profile.id, schema, rationale: "Test Failure", actor: actor)

    # 4. Verify Failure State
    assert boarding.status == :failed
    assert boarding.error_metadata["reason"] =~ "Invalid Business License"
    assert reason.body == %{"error" => "Invalid Business License"}

    # 5. Application remains unchanged or :approved but not :funded
    final_app = Application.get_by_id!(app.id, tenant: schema)
    assert final_app.status != :funded
  end

  test "Steel Thread: Async Boarding & Status Sync", %{
    schema: schema,
    merchant: merchant,
    profile: profile
  } do
    # 1. Setup Application & Assessment
    {:ok, app} =
      Application.create(
        %{
          subject_id: merchant.id,
          subject_type: :merchant,
          application_data: %{"industry" => "retail"},
          status: :submitted
        },
        tenant: schema
      )

    _assessment =
      RiskAssessment.create!(
        %{
          application_id: app.id,
          subject_id: merchant.id,
          subject_type: :merchant,
          score: 75,
          recommendation: :approve
        },
        tenant: schema
      )

    # 2. Stub QorPay for PENDING status
    Req.Test.stub(Mcp.Payments.Gateways.QorPay, fn conn ->
      case conn.method do
        "POST" ->
          Req.Test.json(conn, %{"status" => "pending", "mid" => "ASYNC_MID_123"})

        "GET" ->
          # First check: still pending
          Req.Test.json(conn, %{"status" => "pending"})
      end
    end)

    # 3. Execute Boarding (Should be :pending)
    actor = %Mcp.Accounts.User{id: Ecto.UUID.generate(), role: :member, tenant_id: schema}

    {:ok, boarding} =
      BoardingService.board(app.id, profile.id, schema, rationale: "Async Test", actor: actor)

    assert boarding.status == :pending

    # Application should be :approved, not yet :funded
    app = Application.get_by_id!(app.id, tenant: schema)
    assert app.status == :approved

    # 4. Update Stub for APPROVED status
    Req.Test.stub(Mcp.Payments.Gateways.QorPay, fn conn ->
      Req.Test.json(conn, %{"status" => "approved"})
    end)

    # 5. Sync Status
    :ok = BoardingService.sync_status(boarding, tenant: schema, actor: actor)

    # 6. Verify Final State
    updated_boarding = Ash.get!(Boarding, boarding.id, tenant: schema, authorize?: false)
    assert updated_boarding.status == :active

    final_app = Application.get_by_id!(app.id, tenant: schema)
    assert final_app.status == :funded
  end
end
