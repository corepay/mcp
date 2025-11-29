defmodule McpWeb.Tenant.Underwriting.KanbanLiveTest do
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Mcp.Underwriting.Application

  setup do
    # Create Tenant
    tenant = 
      Mcp.Platform.Tenant
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Tenant",
        slug: "test-tenant-kanban",
        subdomain: "test-tenant-kanban"
      })
      |> Ash.create!()

    # WORKAROUND: Manually add columns because Ecto.Migrator fails in Sandbox
    schema = tenant.company_schema
    Mcp.Repo.query!("CREATE TABLE IF NOT EXISTS \"#{schema}\".merchants (id uuid PRIMARY KEY, business_name text, slug text, subdomain text, status text, country text, plan text, risk_level text, verification_status text, kyc_status text, timezone text, default_currency text, risk_profile text, settings jsonb, branding jsonb, max_stores integer, processing_limits jsonb, kyc_documents jsonb, operating_hours jsonb, inserted_at timestamp(6), updated_at timestamp(6))")
    Mcp.Repo.query!("CREATE TABLE IF NOT EXISTS \"#{schema}\".underwriting_applications (id uuid PRIMARY KEY, merchant_id uuid, status text, application_data jsonb, risk_score integer, submitted_at timestamp(6), sla_due_at timestamp(6), inserted_at timestamp(6), updated_at timestamp(6))")
    Mcp.Repo.query!("CREATE TABLE IF NOT EXISTS \"#{schema}\".underwriting_activities (id uuid PRIMARY KEY, type text, metadata jsonb, actor_id uuid, application_id uuid, inserted_at timestamp(6), updated_at timestamp(6))")

    # Create a merchant for the application
    merchant = 
      Mcp.Platform.Merchant
      |> Ash.Changeset.for_create(:create, %{
        business_name: "Test Merchant",
        slug: "test-merchant-kanban",
        subdomain: "test-merchant-kanban",
        status: :active
      })
      |> Ash.create!(tenant: tenant.company_schema)

    # Create Application
    application = 
      Mcp.Underwriting.Application
      |> Ash.Changeset.for_create(:create, %{
        merchant_id: merchant.id,
        status: :submitted,
        application_data: %{
          "business_name" => "Test Corp",
          "legal_structure" => "llc",
          "owners" => [
            %{"first_name" => "John", "last_name" => "Doe", "email" => "john@example.com"}
          ]
        }
      })
      |> Ash.create!(tenant: tenant.company_schema)

    {:ok, tenant: tenant, application: application}
  end



  test "renders kanban board and updates status", %{conn: conn, tenant: tenant, application: application} do
    # 1. Create Admin User
    admin_user = 
      Mcp.Accounts.User
      |> Ash.Changeset.for_create(:register, %{
        email: "kanban_admin_#{System.unique_integer()}@platform.local",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.Changeset.force_change_attribute(:tenant_id, tenant.id)
      |> Ash.Changeset.force_change_attribute(:role, :admin)
      |> Ash.create!()

    # 2. Generate session
    {:ok, session_data} = Mcp.Accounts.Auth.create_user_session(admin_user, "127.0.0.1")

    # 3. Setup connection with cookies
    conn = 
      conn
      |> init_test_session(%{"tenant_id" => tenant.id})
      |> put_req_cookie("_mcp_access_token", session_data.access_token)
      |> put_req_cookie("_mcp_refresh_token", session_data.refresh_token)
      |> put_req_cookie("_mcp_session_id", session_data.session_id)

    # 4. Mount LiveView
    {:ok, view, html} = live(conn, "/tenant/underwriting/board")

    # 5. Verify Board Rendered
    assert html =~ "Pipeline"
    assert html =~ "Test Corp"
    assert html =~ "Submitted"

    # 6. Test Drag and Drop (Update Status)
    # We simulate the event that the hook sends
    view
    |> render_hook("update_status", %{"id" => application.id, "new_status" => "under_review"})

    # 7. Verify Status Update
    updated_app = Application.get_by_id!(application.id, tenant: tenant.company_schema)
    assert updated_app.status == :under_review
    

  end
end
