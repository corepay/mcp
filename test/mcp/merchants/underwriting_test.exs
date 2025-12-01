defmodule Mcp.Merchants.UnderwritingTest do
  use Mcp.DataCase

  alias Mcp.Underwriting
  alias Mcp.Platform
  alias Mcp.Repo

  setup do
    unique_id = Ecto.UUID.generate()
    schema_name = "test_tenant_#{String.replace(unique_id, "-", "")}"
    full_schema_name = "acq_#{schema_name}"
    IO.puts("DEBUG: Setup for #{unique_id}")

    # Create tenant schema and run migrations outside of the test transaction
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      {:ok, _} = Mcp.MultiTenant.create_tenant_schema(schema_name)

      # Manually run migrations since config is false in test
      path = Application.app_dir(:mcp, "priv/repo/tenant_migrations")
      Ecto.Migrator.run(Repo, path, :up, all: true, prefix: full_schema_name)
    end)

    # Create Tenant resource (this can be inside the transaction)
    tenant =
      Mcp.Platform.Tenant.create!(%{
        name: "Test Tenant #{unique_id}",
        slug: "test-tenant-#{unique_id}",
        subdomain: "test-tenant-#{unique_id}",
        company_schema: full_schema_name
      })

    on_exit(fn ->
      # Cleanup outside of transaction
      # Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      #   try do
      #     Mcp.MultiTenant.drop_tenant_schema(schema_name)
      #   rescue
      #     _ -> :ok
      #   end
      # end)
      :ok
    end)

    {:ok, merchant} =
      Mcp.Platform.Merchant.create(
        %{
          business_name: "Test Merchant #{unique_id}",
          slug: "test-merchant-#{unique_id}",
          subdomain: "test-merchant-#{unique_id}",
          status: :active,
          plan: :starter
        },
        tenant: tenant.company_schema
      )

    %{merchant: merchant, tenant: tenant}
  end

  describe "Underwriting Applications" do
    test "can create a draft application", %{merchant: merchant, tenant: tenant} do
      application =
        Underwriting.Application.create!(
          %{
            subject_id: merchant.id,
            subject_type: :merchant,
            status: :draft,
            application_data: %{business_type: "llc"},
            risk_score: 10
          },
          tenant: tenant.company_schema
        )

      assert application.status == :draft
      assert application.risk_score == 10
      assert application.subject_id == merchant.id
    end

    test "can submit an application and add a review", %{merchant: merchant, tenant: tenant} do
      application =
        Underwriting.Application.create!(
          %{
            subject_id: merchant.id,
            subject_type: :merchant,
            status: :submitted,
            application_data: %{business_type: "corporation"}
          },
          tenant: tenant.company_schema
        )

      review =
        try do
          Underwriting.Review.create!(
            %{
              application_id: application.id,
              decision: :approved,
              notes: "Looks good",
              risk_score: 5
            },
            tenant: tenant.company_schema
          )
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
      application =
        Underwriting.Application.create!(
          %{
            subject_id: merchant.id,
            subject_type: :merchant,
            status: :submitted,
            application_data: %{business_type: "llc"}
          },
          tenant: tenant.company_schema
        )

      assessment =
        Underwriting.RiskAssessment.create!(
          %{
            subject_id: merchant.id,
            subject_type: :merchant,
            application_id: application.id,
            score: 85,
            factors: %{credit_score: "high"},
            recommendation: :approve
          },
          tenant: tenant.company_schema
        )

      assert assessment.score == 85
      assert assessment.recommendation == :approve
      assert assessment.subject_id == merchant.id
    end
  end

  describe "Payfac Configuration" do
    test "can create payfac configuration for a tenant", %{tenant: tenant} do
      config =
        Platform.PayfacConfiguration.create!(%{
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
