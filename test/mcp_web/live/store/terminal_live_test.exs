defmodule McpWeb.Store.TerminalLiveTest do
  use McpWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Mcp.Accounts.Auth
  alias Mcp.Accounts.User
  alias Mcp.Platform.Tenant

  # Integration test requiring full tenant/store setup
  @moduletag :integration

  setup %{conn: _conn} do
    unique_id = "#{System.system_time(:millisecond)}-#{:rand.uniform(999_999)}"
    schema_name = "acq_#{String.replace(unique_id, "-", "_")}"

    tenant =
      Tenant
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Store Terminal Tenant #{unique_id}",
        slug: "terminal-#{unique_id}",
        subdomain: "terminal-#{unique_id}",
        company_schema: schema_name
      })
      |> Ash.create!()

    user =
      User
      |> Ash.Changeset.for_create(:register, %{
        email: "terminal_#{unique_id}@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "Test",
        last_name: "Store"
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

  describe "Terminal LiveView - Single Screen Layout" do
    test "renders terminal interface with two-panel layout", %{conn: conn, tenant: tenant} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/#{tenant.slug}/terminal")

      assert html =~ "Virtual Terminal"
      # Should show search/line items panel and order summary panel
      assert html =~ "Search items"
      assert html =~ "Order Summary"
    end

    test "shows empty state when no items added", %{conn: conn, tenant: tenant} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/#{tenant.slug}/terminal")

      assert html =~ "$0.00"
      assert html =~ "Search or add products"
    end

    test "has customer section", %{conn: conn, tenant: tenant} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/#{tenant.slug}/terminal")

      # Customer section should be visible (optional customer)
      assert html =~ "customer" or html =~ "Add Customer"
    end

    test "has exit button to dashboard", %{conn: conn, tenant: tenant} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/#{tenant.slug}/terminal")

      # Use Regex or partial match for link ensuring it points to dashboard
      assert html =~ "href=\"/app/stores/#{tenant.slug}/dashboard\""
    end

    test "shows order summary with subtotal, tax, and total", %{conn: conn, tenant: tenant} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/#{tenant.slug}/terminal")

      assert html =~ "Subtotal"
      assert html =~ "Tax"
      assert html =~ "TOTAL"
    end
  end
end
