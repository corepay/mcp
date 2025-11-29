defmodule McpWeb.Tenant.UnderwritingLiveTest do
  use McpWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Admin Underwriting" do
    setup do
      # Create tenant and admin user
      tenant = Mcp.Platform.Tenant.create!(%{
        name: "Admin Tenant",
        slug: "admin-tenant",
        subdomain: "admin-tenant"
      })
      
      # Ensure tenant schema exists
      Mcp.Infrastructure.TenantManager.create_tenant_schema(tenant.company_schema)

      admin_user = 
        Mcp.Accounts.User
        |> Ash.Changeset.for_create(:register, %{
          email: "admin@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Ash.Changeset.force_change_attribute(:tenant_id, tenant.id)
        |> Ash.Changeset.force_change_attribute(:role, :admin)
        |> Ash.create!()

      {:ok, session_data} = Mcp.Accounts.Auth.create_user_session(admin_user, "127.0.0.1")

      # Create a merchant
      merchant = 
        Mcp.Platform.Merchant
        |> Ash.Changeset.for_create(:create, %{
          business_name: "Risky Business",
          slug: "risky-business",
          subdomain: "risky-business",
          support_email: "risk@example.com"
        })
        |> Ash.create!(tenant: tenant.company_schema)



      # Create a test application
      application = 
        Mcp.Underwriting.Application
        |> Ash.Changeset.for_create(:create, %{
          merchant_id: merchant.id,
          status: :manual_review,
          application_data: %{
            "business_name" => "Risky Business",
            "email" => "risk@example.com"
          }
        })
        |> Ash.create!(tenant: tenant.company_schema)

      # Create a risk assessment for it
      Mcp.Underwriting.RiskAssessment.create!(%{
        merchant_id: application.merchant_id,
        application_id: application.id,
        score: 65,
        factors: %{kyb: %{status: :review}},
        recommendation: :manual_review
      }, tenant: tenant.company_schema)

      %{
        conn: build_conn()
              |> init_test_session(%{"tenant_id" => tenant.id})
              |> put_req_cookie("_mcp_access_token", session_data.access_token)
              |> put_req_cookie("_mcp_refresh_token", session_data.refresh_token)
              |> put_req_cookie("_mcp_session_id", session_data.session_id),
        application: application,
        tenant: tenant
      }
    end

    test "lists applications on dashboard", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/underwriting")

      assert render(view) =~ "Underwriting Queue"
      assert render(view) =~ "Risky Business"
      assert render(view) =~ "Manual review"
    end

    test "can approve application from review page", %{conn: conn, application: application, tenant: tenant} do
      {:ok, view, _html} = live(conn, "/admin/underwriting/#{application.id}")

      assert render(view) =~ "Risky Business"
      assert render(view) =~ "Risk Score"
      
      # Click Approve
      view
      |> element("button", "Approve Application")
      |> render_click()
      
      # Should redirect back to dashboard
      assert_redirect(view, "/admin/underwriting")
      
      # Verify status update
      updated_app = Mcp.Underwriting.Application.get_by_id!(application.id, tenant: tenant.company_schema)
      assert updated_app.status == :approved
    end
  end
end
