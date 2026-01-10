defmodule McpWeb.Ola.ApplicationLiveTest do
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  # Integration test requiring full tenant schema setup
  @moduletag :integration

  require Ash.Query

  alias Mcp.Accounts.{Auth, User}
  alias Mcp.Chat.{Conversation, Message}
  alias Mcp.Platform.{Merchant, Tenant}
  alias Mcp.Repo
  alias Mcp.Underwriting.{Application, Document}

  setup do
    # Create Tenant
    tenant =
      Tenant
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Tenant OLA",
        slug: "test-tenant-ola",
        subdomain: "test-tenant-ola"
      })
      |> Ash.create!()

    # WORKAROUND: Create table manually because Ecto.Migrator fails in Sandbox for tenant Schema
    schema = tenant.company_schema

    Repo.query!("""
      CREATE TABLE IF NOT EXISTS "#{schema}".underwriting_applications (
        id uuid PRIMARY KEY,
        subject_id uuid,
        subject_type text,
        status text,
        application_data jsonb DEFAULT '{}'::jsonb,
        risk_score integer DEFAULT 0,
        submitted_at timestamp(6),
        sla_due_at timestamp(6),
        inserted_at timestamp(6) NOT NULL,
        updated_at timestamp(6) NOT NULL
      )
    """)

    Repo.query!(
      "CREATE TABLE IF NOT EXISTS \"#{schema}\".underwriting_activities (id uuid PRIMARY KEY, type text, metadata jsonb, actor_id uuid, application_id uuid, inserted_at timestamp(6), updated_at timestamp(6))"
    )

    # Create User
    user =
      User
      |> Ash.Changeset.for_create(:register, %{
        email: "applicant_#{System.unique_integer()}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.Changeset.force_change_attribute(:tenant_id, tenant.id)
      |> Ash.create!()

    # WORKAROUND: Create merchants table
    Repo.query!("""
      CREATE TABLE IF NOT EXISTS "#{schema}".merchants (
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
        reseller_id uuid,
        status text DEFAULT 'active',
        settings jsonb DEFAULT '{}'::jsonb,
        branding jsonb DEFAULT '{}'::jsonb,
        max_stores integer DEFAULT 0,
        max_products integer,
        max_monthly_volume numeric,
        risk_level text DEFAULT 'low',
        kyc_verified_at timestamp(6),
        verification_status text DEFAULT 'pending',
        mcc text,
        tax_id_type text,
        kyc_status text DEFAULT 'pending',
        kyc_documents jsonb DEFAULT '{}'::jsonb,
        timezone text DEFAULT 'UTC',
        default_currency text DEFAULT 'USD',
        operating_hours jsonb DEFAULT '{}'::jsonb,
        risk_score integer,
        risk_profile text DEFAULT 'low',
        processing_limits jsonb DEFAULT '{}'::jsonb,
        inserted_at timestamp(6) NOT NULL,
        updated_at timestamp(6) NOT NULL
      )
    """)

    Repo.query!("""
      CREATE TABLE IF NOT EXISTS conversations (
        id uuid PRIMARY KEY,
        title text,
        inserted_at timestamp(6) NOT NULL,
        updated_at timestamp(6) NOT NULL
      )
    """)

    Repo.query!("""
      CREATE TABLE IF NOT EXISTS messages (
        id uuid PRIMARY KEY,
        text text,
        source text DEFAULT 'user',
        complete boolean DEFAULT true,
        tool_calls jsonb[] DEFAULT ARRAY[]::jsonb[],
        tool_results jsonb[] DEFAULT ARRAY[]::jsonb[],
        conversation_id uuid,
        response_to_id uuid,
        inserted_at timestamp(6) NOT NULL,
        updated_at timestamp(6) NOT NULL
      )
    """)

    # Create Merchant (needed for application submission)
    merchant =
      Merchant
      |> Ash.Changeset.for_create(:create, %{
        business_name: "Test Merchant OLA",
        slug: "test-merchant-ola",
        subdomain: "test-merchant-ola",
        status: :active
      })
      |> Ash.create!(tenant: tenant.company_schema)

    # Create Application linked to merchant
    application =
      Application
      |> Ash.Changeset.for_create(:create, %{
        subject_id: merchant.id,
        subject_type: :merchant,
        status: :submitted,
        application_data: %{
          "business_name" => "Test Business",
          "contact_email" => user.email,
          "business_type" => "llc",
          "annual_volume" => 100_000,
          "website" => "https://example.com"
        }
      })
      |> Ash.create!(tenant: tenant.company_schema)

    {:ok, tenant: tenant, user: user, merchant: merchant, application: application}
  end

  test "chat functionality works", %{conn: conn, tenant: tenant, user: user} do
    # 1. Login
    {:ok, session_data} = Auth.create_user_session(user, "127.0.0.1")

    conn =
      conn
      |> init_test_session(%{
        "tenant_id" => tenant.id,
        "_mcp_access_token" => session_data.access_token
      })
      |> put_req_cookie("_mcp_access_token", session_data.access_token)
      |> put_req_cookie("_mcp_refresh_token", session_data.refresh_token)
      |> put_req_cookie("_mcp_session_id", session_data.session_id)

    # 2. Mount LiveView
    {:ok, view, html} = live(conn, "/online-application/application")

    assert html =~ "How would you like to apply?"

    # 3. Switch to Chat Mode
    view
    |> element("div[phx-value-mode='chat']")
    |> render_click()

    assert render(view) =~ "Chat with Atlas"

    # 4. Send Message
    view
    |> form("form[phx-submit='send_chat']", %{"message" => "Hello Atlas"})
    |> render_submit()

    # 5. Verify Message Persisted
    conversation =
      Conversation
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.read_one!()

    assert conversation

    message =
      Message
      |> Ash.Query.filter(conversation_id == ^conversation.id)
      |> Ash.Query.filter(text == "Hello Atlas")
      |> Ash.read_one!()

    assert message
    assert message.source == :user

    # 6. Verify Message in UI
    assert has_element?(view, "#main-chat-container", "Hello Atlas")
  end

  test "file upload in chat works", %{
    conn: conn,
    tenant: tenant,
    user: user,
    application: application
  } do
    # 1. Login
    {:ok, session_data} = Auth.create_user_session(user, "127.0.0.1")

    conn =
      conn
      |> init_test_session(%{
        "tenant_id" => tenant.id,
        "_mcp_access_token" => session_data.access_token
      })
      |> put_req_cookie("_mcp_access_token", session_data.access_token)
      |> put_req_cookie("_mcp_refresh_token", session_data.refresh_token)
      |> put_req_cookie("_mcp_session_id", session_data.session_id)

    # 2. Mount LiveView & Switch to Chat
    {:ok, view, _html} = live(conn, "/online-application/application")

    view
    |> element("div[phx-value-mode='chat']")
    |> render_click()

    # 3. Upload File
    upload =
      file_input(view, "form[phx-submit='send_chat']", :chat_files, [
        %{
          name: "test_doc.pdf",
          content: "PDF Content",
          type: "application/pdf"
        }
      ])

    assert render_upload(upload, "test_doc.pdf") =~ "test_doc.pdf"

    # 4. Submit Chat with Upload
    view
    |> form("form[phx-submit='send_chat']", %{"message" => "Here is my doc"})
    |> render_submit()

    # 5. Verify Messages
    conversation =
      Conversation
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.read_one!()

    messages =
      Message
      |> Ash.Query.filter(conversation_id == ^conversation.id)
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.read!()

    assert length(messages) >= 2
    assert Enum.any?(messages, &(&1.text == "Here is my doc"))
    assert Enum.any?(messages, &(&1.text == "Uploaded document: test_doc.pdf"))

    # 6. Verify Document Created
    document =
      Document
      |> Ash.Query.filter(application_id == ^application.id)
      |> Ash.Query.filter(file_name == "test_doc.pdf")
      |> Ash.read_one!(tenant: tenant.company_schema)

    assert document
    assert document.mime_type == "application/pdf"
  end

  test "atlas concierge is present in form mode", %{conn: conn, tenant: tenant, user: user} do
    # 1. Login
    {:ok, session_data} = Auth.create_user_session(user, "127.0.0.1")

    conn =
      conn
      |> init_test_session(%{
        "tenant_id" => tenant.id,
        "_mcp_access_token" => session_data.access_token
      })
      |> put_req_cookie("_mcp_access_token", session_data.access_token)

    # 2. Mount & Switch to Form
    {:ok, view, _html} = live(conn, "/online-application/application")

    view
    |> element("div[phx-value-mode='form']")
    |> render_click()

    # 3. Verify Concierge Component
    assert has_element?(view, "#atlas-concierge")

    # 4. Toggle Chat (using the button inside the component)
    view
    |> element("#atlas-concierge button[phx-click='toggle']")
    |> render_click()

    assert has_element?(view, "#atlas-messages", "Hi! I'm Atlas")
  end
end
