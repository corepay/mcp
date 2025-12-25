defmodule McpWeb.Ola.ApplicationLiveTest do
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

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

    # WORKAROUND: Manually add columns because Ecto.Migrator fails in Sandbox
    schema = tenant.company_schema

    Repo.query!(
      "ALTER TABLE \"#{schema}\".underwriting_applications ADD COLUMN IF NOT EXISTS submitted_at timestamp(6)"
    )

    Repo.query!(
      "ALTER TABLE \"#{schema}\".underwriting_applications ADD COLUMN IF NOT EXISTS sla_due_at timestamp(6)"
    )

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

    # Create Application linked to user via email
    application =
      Application
      |> Ash.Changeset.for_create(:create, %{
        merchant_id: merchant.id,
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
end
