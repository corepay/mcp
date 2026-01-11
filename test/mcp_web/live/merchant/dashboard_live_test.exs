defmodule McpWeb.Merchant.DashboardLiveTest do
  @moduledoc false
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  # Integration test requiring full tenant schema setup
  @moduletag :integration

  alias Mcp.Accounts.Auth
  alias Mcp.Accounts.User
  alias Mcp.Platform.Tenant

  describe "GET /app/dashboard" do
    setup %{conn: _conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Merchant Tenant",
          slug: "merchant-test-#{System.unique_integer([:positive])}",
          subdomain: "merchant-#{System.unique_integer([:positive])}"
        })
        |> Ash.create!()

      user =
        User
        |> Ash.Changeset.for_create(:register, %{
          email: "merchant_#{System.unique_integer([:positive])}@example.com",
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

    test "renders dashboard with stats", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/dashboard")

      # Verify stat cards are rendered
      assert html =~ "Today's Revenue"
      assert html =~ "Transactions"
      assert html =~ "Customers"
      assert html =~ "Avg Order"
    end

    test "renders stores performance section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/dashboard")

      assert html =~ "Stores Performance"
    end

    test "renders recent transactions section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/dashboard")

      assert html =~ "Recent Transactions"
    end

    test "renders needs attention section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/dashboard")

      assert html =~ "Needs Attention"
    end
  end
end
