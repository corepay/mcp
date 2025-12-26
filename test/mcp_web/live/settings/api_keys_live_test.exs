defmodule McpWeb.Settings.ApiKeysLiveTest do
  @moduledoc false
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Mcp.Platform.ApiKey

  describe "ApiKeysLive" do
    setup %{conn: conn} do
      tenant =
        Mcp.Platform.Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Tenant",
          slug: "test-tenant-#{System.unique_integer([:positive])}",
          subdomain: "test-#{System.unique_integer([:positive])}"
        })
        |> Ash.create!()

      # Create a user for the tenant session context
      user =
        Mcp.Accounts.User
        |> Ash.Changeset.for_create(:register, %{
          email: "user_#{System.unique_integer([:positive])}@example.com",
          password: "password123",
          password_confirmation: "password123",
          first_name: "Test",
          last_name: "User"
        })
        |> Ash.create!()

      host = "#{tenant.subdomain}.localhost"

      authed_conn =
        conn
        |> init_test_session(%{
          "tenant_id" => tenant.id,
          "user_id" => user.id,
          "portal_context" => "tenant"
        })
        |> Map.put(:host, host)
        |> put_req_header("x-forwarded-host", host)

      {:ok, conn: authed_conn, tenant: tenant, user: user}
    end

    @tag :skip
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

    @tag :skip
    test "creates a new api key", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tenant/settings/api-keys")

      view
      |> element("button", "Create New Key")
      |> render_click()

      assert render(view) =~ "API Key Created"
      assert render(view) =~ "mcp_live_"
    end

    @tag :skip
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

      assert render(view) =~ "API Key revoked"

      # Verify it's revoked in DB
      key = Ash.get!(Mcp.Platform.ApiKey, key.id)
      assert key.revoked_at
    end
  end
end
