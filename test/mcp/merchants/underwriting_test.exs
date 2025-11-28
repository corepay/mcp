defmodule Mcp.Merchants.UnderwritingTest do
  use Mcp.DataCase

  alias Mcp.Underwriting
  alias Mcp.Platform

  setup do
    unique_id = System.unique_integer([:positive])
    tenant = %Mcp.Platform.Tenant{
      id: Ecto.UUID.generate(),
      name: "Test Tenant #{unique_id}",
      slug: "test-tenant-#{unique_id}",
      subdomain: "test-tenant-#{unique_id}",
      company_schema: "acq_test_#{unique_id}",
      status: :active,
      plan: :starter,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    } |> Mcp.Repo.insert!()

    # Manually create tenant schema and merchants table
    Mcp.Repo.query!("CREATE SCHEMA IF NOT EXISTS \"#{tenant.company_schema}\"")
    Mcp.Repo.query!("""
      CREATE TABLE IF NOT EXISTS \"#{tenant.company_schema}\".\"merchants\" (
        id UUID PRIMARY KEY,
        slug TEXT NOT NULL,
        business_name TEXT NOT NULL,
        subdomain TEXT NOT NULL,
        status TEXT DEFAULT 'active',
        plan TEXT DEFAULT 'starter',
        risk_level TEXT DEFAULT 'low',
        risk_profile TEXT DEFAULT 'low',
        verification_status TEXT DEFAULT 'pending',
        kyc_status TEXT DEFAULT 'pending',
        country TEXT DEFAULT 'US',
        timezone TEXT DEFAULT 'UTC',
        default_currency TEXT DEFAULT 'USD',
        settings JSONB DEFAULT '{}',
        branding JSONB DEFAULT '{}',
        kyc_documents JSONB DEFAULT '{}',
        operating_hours JSONB DEFAULT '{}',
        processing_limits JSONB DEFAULT '{}',
        max_stores INTEGER DEFAULT 0,
        max_products INTEGER,
        max_monthly_volume DECIMAL,
        risk_score INTEGER,
        business_type TEXT,
        ein TEXT,
        website_url TEXT,
        description TEXT,
        address_line1 TEXT,
        address_line2 TEXT,
        city TEXT,
        state TEXT,
        postal_code TEXT,
        phone TEXT,
        support_email TEXT,
        mcc TEXT,
        tax_id_type TEXT,
        kyc_verified_at TIMESTAMP,
        custom_domain TEXT,
        dba_name TEXT,
        reseller_id UUID,
        inserted_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL
      )
    """)

    # Create underwriting tables in tenant schema
    Mcp.Repo.query!("""
      CREATE TABLE IF NOT EXISTS \"#{tenant.company_schema}\".\"underwriting_applications\" (
        id UUID PRIMARY KEY,
        status TEXT DEFAULT 'draft',
        application_data JSONB DEFAULT '{}',
        risk_score BIGINT DEFAULT 0,
        merchant_id UUID NOT NULL,
        inserted_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL
      )
    """)

    Mcp.Repo.query!("""
      CREATE TABLE IF NOT EXISTS \"#{tenant.company_schema}\".\"underwriting_reviews\" (
        id UUID PRIMARY KEY,
        decision TEXT NOT NULL,
        notes TEXT,
        risk_score INTEGER,
        application_id UUID NOT NULL,
        inserted_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL
      )
    """)

    Mcp.Repo.query!("""
      CREATE TABLE IF NOT EXISTS \"#{tenant.company_schema}\".\"risk_assessments\" (
        id UUID PRIMARY KEY,
        score BIGINT NOT NULL,
        factors JSONB DEFAULT '{}',
        recommendation TEXT,
        risk_level TEXT,
        merchant_id UUID,
        inserted_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL
      )
    """)

    {:ok, merchant} = Mcp.Platform.Merchant.create(%{
      business_name: "Test Merchant #{unique_id}",
      slug: "test-merchant-#{unique_id}",
      subdomain: "test-merchant-#{unique_id}",
      status: :active,
      plan: :starter
    }, tenant: tenant.company_schema)

    %{merchant: merchant, tenant: tenant}
  end

  describe "Underwriting Applications" do
    test "can create a draft application", %{merchant: merchant, tenant: tenant} do
      application = Underwriting.Application.create!(%{
        merchant_id: merchant.id,
        status: :draft,
        application_data: %{business_type: "llc"},
        risk_score: 10
      }, tenant: tenant.company_schema)

      assert application.status == :draft
      assert application.risk_score == 10
      assert application.merchant_id == merchant.id
    end

    test "can submit an application and add a review", %{merchant: merchant, tenant: tenant} do
      application = Underwriting.Application.create!(%{
        merchant_id: merchant.id,
        status: :submitted,
        application_data: %{business_type: "corporation"}
      }, tenant: tenant.company_schema)

      review =
        try do
          Underwriting.Review.create!(%{
            application_id: application.id,
            decision: :approved,
            notes: "Looks good",
            risk_score: 5
          }, tenant: tenant.company_schema)
        rescue
          e ->
            IO.inspect(e, label: "Review Creation Error")
            reraise e, __STACKTRACE__
        end

      assert review.decision == :approved
      assert review.application_id == application.id
    end
  end

  describe "Risk Assessments" do
    test "can create a risk assessment", %{merchant: merchant, tenant: tenant} do
      assessment = Underwriting.RiskAssessment.create!(%{
        merchant_id: merchant.id,
        score: 85,
        factors: %{credit_score: "high"},
        recommendation: :approve
      }, tenant: tenant.company_schema)

      assert assessment.score == 85
      assert assessment.recommendation == :approve
      assert assessment.merchant_id == merchant.id
    end
  end

  describe "Payfac Configuration" do
    test "can create payfac configuration for a tenant", %{tenant: tenant} do
      config = Platform.PayfacConfiguration.create!(%{
        tenant_id: tenant.id,
        provider: :mock,
        auto_approve_threshold: 95
      })

      assert config.provider == :mock
      assert config.auto_approve_threshold == 95
      assert config.tenant_id == tenant.id
    end
  end
end
