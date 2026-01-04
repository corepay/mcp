defmodule Mcp.Underwriting.Services.SubmissionServiceTest do
  use Mcp.DataCase, async: true

  alias Mcp.Accounts.User
  alias Mcp.Platform.{Merchant, Tenant}
  alias Mcp.Underwriting.Services.SubmissionService

  describe "create_application/3" do
    setup do
      # Create Tenant
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Service Test Tenant",
          slug: "service-test",
          subdomain: "service-test"
        })
        |> Ash.create!()

      schema = tenant.company_schema
      Repo.query!("CREATE SCHEMA IF NOT EXISTS \"#{schema}\"")

      # Setup tables (Similar to LiveView test but focused on service)
      Repo.query!("""
        CREATE TABLE IF NOT EXISTS \"#{schema}\".merchants (
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
          country text DEFAULT 'US',
          phone text,
          support_email text,
          plan text DEFAULT 'starter',
          status text DEFAULT 'active',
          settings jsonb DEFAULT '{}',
          branding jsonb DEFAULT '{}',
          max_stores integer DEFAULT 0,
          max_products integer,
          max_monthly_volume numeric,
          risk_level text DEFAULT 'low',
          kyc_verified_at timestamp(6),
          verification_status text DEFAULT 'pending',
          mcc text,
          tax_id_type text,
          kyc_status text DEFAULT 'pending',
          kyc_documents jsonb DEFAULT '{}',
          timezone text DEFAULT 'UTC',
          default_currency text DEFAULT 'USD',
          operating_hours jsonb DEFAULT '{}',
          risk_score integer,
          risk_profile text DEFAULT 'low',
          processing_limits jsonb DEFAULT '{}',
          reseller_id uuid,
          inserted_at timestamp(6),
          updated_at timestamp(6)
        )
      """)

      Repo.query!("""
        CREATE TABLE IF NOT EXISTS \"#{schema}\".underwriting_applications (
          id uuid PRIMARY KEY,
          subject_id uuid,
          subject_type text,
          status text,
          application_data jsonb,
          risk_score integer,
          submitted_at timestamp(6),
          sla_due_at timestamp(6),
          inserted_at timestamp(6),
          updated_at timestamp(6)
        )
      """)

      # Create Merchant
      merchant =
        Merchant
        |> Ash.Changeset.for_create(:create, %{
          business_name: "Service Merchant",
          slug: "service-merchant",
          subdomain: "service-merchant",
          status: :active
        })
        |> Ash.create!(tenant: schema)

      # Create User linked to Merchant
      user =
        User
        |> Ash.Changeset.for_create(:register, %{
          email: "service_user_#{System.unique_integer()}@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Ash.Changeset.force_change_attribute(:tenant_id, tenant.id)
        |> Ash.Changeset.force_change_attribute(:merchant_id, merchant.id)
        |> Ash.create!()

      {:ok, tenant: tenant, user: user, merchant: merchant}
    end

    test "creates application linked to user's merchant", %{
      tenant: tenant,
      user: user,
      merchant: merchant
    } do
      params = %{
        "business_name" => "Service Biz",
        "email" => user.email,
        "monthly_volume" => "10000"
      }

      {:ok, application} = SubmissionService.create_application(params, user, tenant)

      assert application.subject_id == merchant.id
      assert application.status == :submitted
      assert application.application_data["business_name"] == "Service Biz"
    end

    test "returns error if user has no merchant", %{tenant: tenant} do
      user_no_merchant =
        User
        |> Ash.Changeset.for_create(:register, %{
          email: "no_merchant@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Ash.create!()

      assert {:error, :no_merchant} =
               SubmissionService.create_application(%{}, user_no_merchant, tenant)
    end
  end
end
