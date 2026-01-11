defmodule McpWeb.Store.DashboardLiveTest do
  @moduledoc false
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  # Integration test requiring full tenant/store setup
  @moduletag :integration

  alias Mcp.Accounts.Auth
  alias Mcp.Accounts.User
  alias Mcp.Platform.Tenant

  describe "GET /app/stores/:slug" do
    setup %{conn: _conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Store Tenant",
          slug: "store-test-#{System.unique_integer([:positive])}",
          subdomain: "store-#{System.unique_integer([:positive])}"
        })
        |> Ash.create!()

      user =
        User
        |> Ash.Changeset.for_create(:register, %{
          email: "store_#{System.unique_integer([:positive])}@example.com",
          password: "password123",
          password_confirmation: "password123",
          first_name: "Test",
          last_name: "Merchant"
        })
        |> Ash.Changeset.force_change_attribute(:tenant_id, tenant.id)
        |> Ash.create!()

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

    test "renders dashboard with today's stats", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown")

      assert html =~ "Today's Sales"
      assert html =~ "Transactions"
      assert html =~ "Avg Ticket"
    end

    test "renders quick actions", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown")

      assert html =~ "Quick Actions"
      assert html =~ "New Sale"
    end

    test "renders pending items", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown")

      assert html =~ "Pending"
    end

    test "renders recent transactions", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown")

      assert html =~ "Recent Transactions"
    end
  end
end
