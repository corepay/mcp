# credo:disable-for-this-file Credo.Check.Readability.StringSigils
defmodule Mcp.Underwriting.Services.BoardingServiceTest do
  use Mcp.DataCase, async: true
  alias Mcp.Platform.Merchant
  alias Mcp.Underwriting.{Application, BankProfile, Boarding, Processor}
  alias Mcp.Underwriting.Services.BoardingService

  setup do
    unique_id = System.unique_integer([:positive])
    schema = "tenant_boarding_test_#{unique_id}"
    Mcp.Repo.query!("CREATE SCHEMA IF NOT EXISTS \"#{schema}\"")

    # DDL for merchants
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".merchants (
      id uuid PRIMARY KEY,
      slug text,
      business_name text,
      dba_name text,
      ein text,
      website_url text,
      phone text,
      support_email text,
      address_line1 text,
      address_line2 text,
      city text,
      state text,
      postal_code text,
      country text,
      subdomain text,
      status text,
      plan text,
      risk_level text,
      risk_profile text,
      business_type text,
      timezone text,
      default_currency text,
      kyc_status text,
      verification_status text,
      settings jsonb,
      branding jsonb,
      processing_limits jsonb,
      operating_hours jsonb,
      kyc_documents jsonb,
      max_stores integer,
      max_products integer,
      tax_id_type text,
      description text,
      mcc text,
      custom_domain text,
      reseller_id uuid,
      kyc_verified_at timestamp,
      max_monthly_volume numeric,
      risk_score integer,
      inserted_at timestamp,
      updated_at timestamp
    )")

    # DDL for underwriting_applications
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".underwriting_applications (
      id uuid PRIMARY KEY,
      status text,
      application_data jsonb,
      subject_id uuid REFERENCES \"#{schema}\".merchants(id),
      subject_type text,
      risk_score integer,
      submitted_at timestamp,
      sla_due_at timestamp,
      inserted_at timestamp,
      updated_at timestamp
    )")

    # DDL for underwriting_boardings
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".underwriting_boardings (
      id uuid PRIMARY KEY,
      mid text,
      tid text,
      status text,
      metadata jsonb,
      rationale text,
      error_metadata jsonb,
      application_id uuid REFERENCES \"#{schema}\".underwriting_applications(id),
      processor_id uuid,
      bank_profile_id uuid,
      inserted_at timestamp,
      updated_at timestamp
    )")

    # Create Merchant
    {:ok, merchant} =
      Merchant.create(
        %{
          business_name: "Test Merchant",
          slug: "test-merchant-" <> to_string(unique_id),
          subdomain: "test-" <> to_string(unique_id),
          status: :active
        },
        tenant: schema
      )

    # Create Processor & Profile (bypass authorization for test fixtures)
    processor = Processor.create!(%{name: "QorPay", adapter: "QorPayAdapter"}, authorize?: false)

    profile =
      BankProfile.create!(
        %{
          name: "QorPay Retail",
          processor_id: processor.id,
          risk_weight: 30
        },
        authorize?: false
      )

    Req.Test.verify_on_exit!()

    Req.Test.stub(Mcp.Payments.Gateways.QorPay, fn conn ->
      Req.Test.json(conn, %{
        "status" => "approved",
        "mid" => "QOR_MID_TEST",
        "tid" => "QOR_TID_TEST"
      })
    end)

    Elixir.Application.put_env(:mcp, :req_options, plug: {Req.Test, Mcp.Payments.Gateways.QorPay})

    {:ok, %{schema: schema, merchant: merchant, profile: profile}}
  end

  test "board/3 successfully boards to QorPay", %{
    schema: schema,
    merchant: merchant,
    profile: profile
  } do
    # Create Application
    {:ok, app} =
      Application.create(
        %{
          status: :approved,
          application_data: %{"industry" => "retail"},
          subject_id: merchant.id,
          subject_type: :merchant
        },
        tenant: schema,
        authorize?: false
      )

    # Create a mock actor for authorization
    actor = %Mcp.Accounts.User{id: Ecto.UUID.generate(), role: :member, tenant_id: schema}

    # Execute Boarding
    {:ok, result} = BoardingService.board(app.id, profile.id, schema, actor: actor)

    assert result.status == :active
    assert String.starts_with?(result.mid, "QOR_")

    # Verify Boarding Record exists
    boardings = Boarding.read!(tenant: schema, authorize?: false)
    assert length(boardings) == 1
    boarding = List.first(boardings)
    assert boarding.mid == result.mid
    assert boarding.application_id == app.id

    # Verify Application status updated
    updated_app = Application.get_by_id!(app.id, tenant: schema, authorize?: false)
    assert updated_app.status == :funded
  end
end
