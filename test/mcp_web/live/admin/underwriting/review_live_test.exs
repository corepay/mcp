defmodule McpWeb.Admin.Underwriting.ReviewLiveTest do
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Mcp.Underwriting.Application
  alias Mcp.Underwriting.Activity
  require Ash.Query

  setup do
    # Create Tenant
    tenant = 
      Mcp.Platform.Tenant
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Tenant Review",
        slug: "test-tenant-review",
        subdomain: "test-tenant-review"
      })
      |> Ash.create!()

    # Create a merchant for the application
    merchant = 
      Mcp.Platform.Merchant
      |> Ash.Changeset.for_create(:create, %{
        business_name: "Test Merchant Review",
        slug: "test-merchant-review",
        subdomain: "test-merchant-review",
        status: :active
      })
      |> Ash.create!(tenant: tenant.company_schema)

    # WORKAROUND: Manually add columns because Ecto.Migrator fails in Sandbox
    schema = tenant.company_schema
    Mcp.Repo.query!("ALTER TABLE \"#{schema}\".underwriting_applications ADD COLUMN IF NOT EXISTS submitted_at timestamp(6)")
    Mcp.Repo.query!("ALTER TABLE \"#{schema}\".underwriting_applications ADD COLUMN IF NOT EXISTS sla_due_at timestamp(6)")
    Mcp.Repo.query!("CREATE TABLE IF NOT EXISTS \"#{schema}\".underwriting_activities (id uuid PRIMARY KEY, type text, metadata jsonb, actor_id uuid, application_id uuid, inserted_at timestamp(6), updated_at timestamp(6))")

    # Create Application
    # Create Applicant User for Chat Integration
    applicant_user = 
      Mcp.Accounts.User
      |> Ash.Changeset.for_create(:register, %{
        email: "contact@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.Changeset.force_change_attribute(:tenant_id, tenant.id)
      |> Ash.create!()

    application = 
      Mcp.Underwriting.Application
      |> Ash.Changeset.for_create(:create, %{
        merchant_id: merchant.id,
        status: :submitted,
        application_data: %{
          "business_name" => "Test Business",
          "contact_email" => "contact@example.com",
          "business_type" => "llc",
          "annual_volume" => 100_000,
          "website" => "https://example.com"
        }
      })
      |> Ash.create!(tenant: tenant.company_schema)

    {:ok, tenant: tenant, application: application, applicant_user: applicant_user}
  end

  test "request info flow updates status and logs activity", %{conn: conn, tenant: tenant, application: application, applicant_user: applicant_user} do
    # 1. Create Admin User
    admin_user = 
      Mcp.Accounts.User
      |> Ash.Changeset.for_create(:register, %{
        email: "review_admin_#{System.unique_integer()}@platform.local",
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
    {:ok, view, html} = live(conn, "/admin/underwriting/#{application.id}")

    # 5. Verify Page Rendered
    assert html =~ "Test Business"
    assert html =~ "Submitted"

    # 3. Verify Application Details
    assert has_element?(view, "h1", "Test Business")
    assert has_element?(view, "p", "llc")
    assert has_element?(view, "p", "100000")


    


    # 6. Click Request Info
    view
    |> element("button", "Request More Info")
    |> render_click()

    # 7. Verify Modal Appears
    rendered = render(view)
    assert has_element?(view, "#request-info-modal")
    assert render(view) =~ "Reason for request"

    # 8. Submit Request Info
    view
    |> form("#request-info-modal form", %{
      "reason" => "Need clearer ID",
      "document_type" => "identity"
    })
    |> render_submit()
    
    # 9. Verify Redirect and Flash
    flash = assert_redirect(view, "/admin/underwriting")
    assert flash["info"] =~ "Requested more information"

    # 10. Verify Status Change and Chat Message
    updated_app = Mcp.Underwriting.Application.get_by_id!(application.id, tenant: tenant.company_schema)
    assert updated_app.status == :more_info_required
    
    # Verify Chat Message
    conversation = 
      Mcp.Chat.Conversation
      |> Ash.Query.filter(user_id == ^applicant_user.id)
      |> Ash.read_one!(tenant: tenant.company_schema)
      
    assert conversation
    
    message = 
      Mcp.Chat.Message
      |> Ash.Query.filter(conversation_id == ^conversation.id)
      |> Ash.read_one!(tenant: tenant.company_schema)
      
    assert message.text == "SYSTEM NOTIFICATION: Please upload your **Identity**. Reason: Need clearer ID"
    assert message.source == :agent

    # 11. Verify Activity Log
    activity = 
      Activity
      |> Ash.Query.filter(application_id == ^application.id)
      |> Ash.read_one!(tenant: tenant.company_schema)

    assert activity.type == :status_change
    assert activity.metadata["reason"] == "Need clearer ID"
  end

  test "can verify and reject documents", %{conn: conn, tenant: tenant, application: application} do
    # 1. Create a document
    document = 
      Mcp.Underwriting.Document
      |> Ash.Changeset.for_create(:create, %{
        file_path: "apps/#{application.id}/doc.pdf",
        file_name: "doc.pdf",
        mime_type: "application/pdf",
        document_type: :identity,
        application_id: application.id
      })
      |> Ash.create!(tenant: tenant.company_schema)

    # 2. Setup Admin Session
    admin_user = 
      Mcp.Accounts.User
      |> Ash.Changeset.for_create(:register, %{
        email: "doc_admin_#{System.unique_integer()}@platform.local",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.Changeset.force_change_attribute(:tenant_id, tenant.id)
      |> Ash.Changeset.force_change_attribute(:role, :admin)
      |> Ash.create!()

    {:ok, session_data} = Mcp.Accounts.Auth.create_user_session(admin_user, "127.0.0.1")

    conn = 
      conn
      |> init_test_session(%{"tenant_id" => tenant.id})
      |> put_req_cookie("_mcp_access_token", session_data.access_token)
      |> put_req_cookie("_mcp_refresh_token", session_data.refresh_token)
      |> put_req_cookie("_mcp_session_id", session_data.session_id)

    # 3. Mount LiveView
    {:ok, view, _html} = live(conn, "/admin/underwriting/#{application.id}")

    # 4. Verify Document Present
    assert has_element?(view, "p", "doc.pdf")

    # 5. Click Verify
    view
    |> element("button[title='Verify Document']")
    |> render_click()

    # 6. Verify Status Change
    assert has_element?(view, "span.text-success", "verified")
    
    updated_doc = Ash.read_one!(Ash.Query.filter(Mcp.Underwriting.Document, id == ^document.id), tenant: tenant.company_schema)
    assert updated_doc.status == :verified

    # 7. Click Reject
    view
    |> element("button[title='Reject Document']")
    |> render_click()

    # 8. Verify Status Change
    assert has_element?(view, "span.text-error", "rejected")

    updated_doc = Ash.read_one!(Ash.Query.filter(Mcp.Underwriting.Document, id == ^document.id), tenant: tenant.company_schema)
    assert updated_doc.status == :rejected
  end

  test "can add internal notes", %{conn: conn, tenant: tenant, application: application} do
    # Setup Admin Session
    admin_user = 
      Mcp.Accounts.User
      |> Ash.Changeset.for_create(:register, %{
        email: "note_admin_#{System.unique_integer()}@platform.local",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.Changeset.force_change_attribute(:tenant_id, tenant.id)
      |> Ash.Changeset.force_change_attribute(:role, :admin)
      |> Ash.create!()

    {:ok, session_data} = Mcp.Accounts.Auth.create_user_session(admin_user, "127.0.0.1")

    conn = 
      conn
      |> init_test_session(%{"tenant_id" => tenant.id})
      |> put_req_cookie("_mcp_access_token", session_data.access_token)
      |> put_req_cookie("_mcp_refresh_token", session_data.refresh_token)
      |> put_req_cookie("_mcp_session_id", session_data.session_id)

    # 1. Mount LiveView
    {:ok, view, _html} = live(conn, "/admin/underwriting/#{application.id}")

    # 2. Add Note
    view
    |> form("form[phx-submit='add_note']", %{"note" => "This is a test note"})
    |> render_submit()

    # 3. Verify Note in Timeline
    assert has_element?(view, "p", "Internal Note")
    assert has_element?(view, "div", "This is a test note")
    
    # 4. Verify Activity Log
    activity = 
      Mcp.Underwriting.Activity
      |> Ash.Query.filter(application_id == ^application.id)
      |> Ash.Query.filter(type == :internal_note)
      |> Ash.read_one!(tenant: tenant.company_schema)

    assert activity.metadata["note"] == "This is a test note"
  end
end
