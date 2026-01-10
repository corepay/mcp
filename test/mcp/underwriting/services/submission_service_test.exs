defmodule Mcp.Underwriting.Services.SubmissionServiceTest do
  use Mcp.DataCase, async: false

  alias Mcp.Accounts.User
  alias Mcp.Platform.Merchant
  alias Mcp.Underwriting.Services.SubmissionService

  describe "create_application/3" do
    setup do
      Mcp.Repo.query!("SET search_path TO public, platform")

      # Optimization: We do not need to insert a Tenant record into platform.tenants
      # for this test. We only need the struct with the correct schema info.
      # This avoids potential locks/hangs on the tenants table during parallel tests.

      uuid = Ecto.UUID.generate()
      schema = "acq_test_template"

      # Mock the tenant struct for downstream usage
      tenant = %Mcp.Platform.Tenant{
        id: uuid,
        company_schema: schema,
        name: "Service Test Tenant",
        slug: "service-test",
        subdomain: "service-test",
        plan: :starter,
        status: :active
      }

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
