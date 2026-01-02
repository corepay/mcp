defmodule McpWeb.Settings.ApiKeysLiveTest do
  @moduledoc false
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  # Integration test requiring full tenant schema setup
  @moduletag :integration

  alias Mcp.Accounts.Auth
  alias Mcp.Accounts.User
  alias Mcp.Platform.ApiKey
  alias Mcp.Platform.Tenant

  describe "ApiKeysLive" do
    setup %{conn: _conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Tenant",
          slug: "test-tenant-#{System.unique_integer([:positive])}",
          subdomain: "test-#{System.unique_integer([:positive])}"
        })
        |> Ash.create!()

      # Create a user for the tenant session context
      user =
        User
        |> Ash.Changeset.for_create(:register, %{
          email: "user_#{System.unique_integer([:positive])}@example.com",
          password: "password123",
          password_confirmation: "password123",
          first_name: "Test",
          last_name: "User"
        })
        |> Ash.Changeset.force_change_attribute(:tenant_id, tenant.id)
        |> Ash.create!()

      # Create a proper JWT session
      {:ok, session_data} = Auth.create_user_session(user, "127.0.0.1")

      host = "#{tenant.subdomain}.localhost"

      authed_conn =
        build_conn()
        |> Map.put(:host, host)
        |> put_req_header("x-forwarded-host", host)
        |> init_test_session(%{"tenant_id" => tenant.id})
        |> put_req_cookie("_mcp_access_token", session_data.access_token)
        |> put_req_cookie("_mcp_refresh_token", session_data.refresh_token)
        |> put_req_cookie("_mcp_session_id", session_data.session_id)

      {:ok, conn: authed_conn, tenant: tenant, user: user}
    end

    test "lists api keys", %{conn: conn, tenant: tenant} do
      {:ok, _key} =
        ApiKey.create(%{
          prefix: "mcp_list_test",
          type: :merchant,
          owner_id: tenant.id,
          owner_type: :tenant
        })

      {:ok, _view, html} = live(conn, "/tenant/settings/api-keys")

      assert html =~ "API Keys"
      assert html =~ "mcp_list_test_..."
    end

    test "creates a new api key", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tenant/settings/api-keys")

      view
      |> element("button", "Create New Key")
      |> render_click()

      assert render(view) =~ "API Key Created"
      assert render(view) =~ "mcp_live_"
    end

    test "revokes an api key", %{conn: conn, tenant: tenant} do
      {:ok, key} =
        ApiKey.create(%{
          prefix: "mcp_revoke_test",
          type: :merchant,
          owner_id: tenant.id,
          owner_type: :tenant
        })

      {:ok, view, _html} = live(conn, "/tenant/settings/api-keys")

      # Initial state
      assert render(view) =~ "mcp_revoke_test"

      # Click Revoke (enters confirmation mode)
      view
      |> element(~s|button[phx-click="confirm_revoke"][phx-value-id="#{key.id}"]|)
      |> render_click()

      assert render(view) =~ "Are you sure?"

      # Confirm Revoke
      view
      |> element("button", "Yes, Revoke")
      |> render_click()

      # After revoking, the key should no longer appear in the list
      refute render(view) =~ "mcp_revoke_test"

      # Verify it's revoked in DB
      key = Ash.get!(Mcp.Platform.ApiKey, key.id)
      assert key.revoked_at
    end
  end
end
