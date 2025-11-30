defmodule Mcp.Merchants.UnderwritingTest do
  use Mcp.DataCase

  alias Mcp.Underwriting
  alias Mcp.Platform

  setup do
    unique_id = System.unique_integer([:positive])
    tenant =
      try do
        Mcp.Platform.Tenant.create!(%{
          name: "Test Tenant #{unique_id}",
          slug: "test-tenant-#{unique_id}",
          subdomain: "test-tenant-#{unique_id}",
          company_schema: "acq_test_#{unique_id}"
        })
      rescue
        e ->
          reraise e, __STACKTRACE__
      end

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
