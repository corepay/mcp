defmodule McpWeb.EndToEndFlowTest do
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Mcp.Platform.Tenant
  alias Mcp.Platform.Merchant
  alias Mcp.Underwriting.Application

  setup do
    # 1. Setup Tenant
    tenant = 
      Tenant
      |> Ash.Changeset.for_create(:create, %{
        name: "End-to-End Tenant",
        slug: "e2e-tenant",
        subdomain: "e2e-tenant"
      })
      |> Ash.create!()

    # 2. Setup Merchant (Reseller/Partner context usually manages this, 
    # but for OLA we might start with a fresh user or existing merchant)
    # For this test, we assume the OLA flow creates or attaches to a merchant.
    # The current ApplicationLive implementation picks the first merchant.
    
    merchant = 
      Merchant
      |> Ash.Changeset.for_create(:create, %{
        business_name: "E2E Merchant",
        slug: "e2e-merchant",
        subdomain: "e2e-merchant",
        status: :active
      })
      |> Ash.create!(tenant: tenant.company_schema)

    {:ok, tenant: tenant, merchant: merchant}
  end

  test "complete application flow: submission -> dashboard", %{conn: conn, tenant: tenant, merchant: merchant} do
    # A. OLA Submission
    # We need to simulate the session with the tenant_id
    conn = init_test_session(conn, %{"tenant_id" => tenant.id})
    
    {:ok, view, _html} = live(conn, "/online-application/application")

    # 1. Select Form Mode
    view
    |> element("[phx-click=select_mode][phx-value-mode=form]")
    |> render_click()

    # 2. Fill Step 1: Business Info
    view
    |> form("form", application: %{
      "business_name" => "My Awesome Business",
      "dba_name" => "MAB Corp",
      "business_type" => "LLC",
      "ein" => "12-3456789"
    })
    |> render_change()

    view |> element("button", "Next") |> render_click()

    # 3. Fill Step 2: Contact Info
    view
    |> form("form", application: %{
      "email" => "owner@example.com",
      "phone" => "555-0123",
      "website" => "example.com",
      "address_line1" => "123 Main St",
      "city" => "New York",
      "state" => "NY",
      "zip" => "10001"
    })
    |> render_change()

    view |> element("button", "Next") |> render_click()

    # 4. Fill Step 3: Business Details
    view
    |> form("form", application: %{
      "monthly_volume" => "10000",
      "average_ticket" => "100",
      "description" => "Selling widgets"
    })
    |> render_change()

    view |> element("button", "Next") |> render_click()

    # 5. Step 4: Submit
    # The submit button is only available in step 4
    view
    |> form("form", application: %{})
    |> render_submit()
    
    # Verify redirection or success message
    assert_redirect(view, "/online-application/login")

    # B. Verify Application Created
    # We need to query the tenant schema
    require Ash.Query
    
    application = 
      Application
      |> Ash.Query.filter(merchant_id == ^merchant.id)
      |> Ash.read_one!(tenant: tenant.company_schema)

    assert application
    assert application.status == :submitted
    assert application.application_data["business_name"] == "My Awesome Business"

    # C. Verify Reseller Dashboard
    # We need to authenticate as a reseller
    # 1. Create a reseller user
    reseller_user = 
      Mcp.Accounts.User
      |> Ash.Changeset.for_create(:register, %{
        email: "reseller@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.Changeset.force_change_attribute(:tenant_id, tenant.id)
      |> Ash.create!()

    # 2. Generate session
    {:ok, session_data} = Mcp.Accounts.Auth.create_user_session(reseller_user, "127.0.0.1")

    # 3. Setup connection with cookies
    reseller_conn = 
      build_conn()
      |> init_test_session(%{"tenant_id" => tenant.id})
      |> put_req_cookie("_mcp_access_token", session_data.access_token)
      |> put_req_cookie("_mcp_refresh_token", session_data.refresh_token)
      |> put_req_cookie("_mcp_session_id", session_data.session_id)
    
    {:ok, reseller_view, _html} = live(reseller_conn, "/partners/applications")
    
    # Verify the application is listed
    assert render(reseller_view) =~ "My Awesome Business"
    # Status should be Under_review because screening ran
    assert render(reseller_view) =~ "Under_review"
  end
end
