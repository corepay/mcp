defmodule McpWeb.Store.Customers.IndexLiveTest do
  @moduledoc false
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  # Integration test requiring full tenant/store setup
  @moduletag :integration

  alias Mcp.Accounts.Auth
  alias Mcp.Accounts.User
  alias Mcp.Platform.Tenant

  describe "GET /app/stores/:store_slug/customers" do
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
          last_name: "Staff"
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

    test "renders page with title 'Customer Lookup'", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown/customers")

      assert html =~ "Customer Lookup"
    end

    test "renders search input in toolbar", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/stores/downtown/customers")

      assert has_element?(view, "input[type=\"search\"]")
      assert has_element?(view, "input[placeholder*=\"Search\"]")
    end

    test "renders data table with customer columns", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/customers")

      # Check table exists
      assert has_element?(view, "#customers-table")

      # Check column headers
      assert html =~ "Name"
      assert html =~ "Phone"
      assert html =~ "Loyalty Status"
    end

    test "does not render add customer action (read-only)", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/customers")

      # Should NOT have add/create buttons in the page content
      refute html =~ "Add Customer"
      refute html =~ "New Customer"

      # Verify no "Add" action in the sidebar's QUICK ACTIONS section
      refute has_element?(view, "aside section button", "Add Customer")
      refute has_element?(view, "aside section a", "Add Customer")
    end

    test "renders filter for loyalty tier", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/customers")

      # Check for filter section
      assert html =~ "FILTERS"
      assert html =~ "Loyalty Tier"
      assert has_element?(view, "select[name=\"loyalty_tier\"]")
    end

    test "renders sample customers in table", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown/customers")

      # Check for sample data
      assert html =~ "John Doe"
      assert html =~ "+1 555-0123"
    end

    test "search filters customers by name", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/customers")

      # Initially shows all customers
      assert html =~ "John Doe"
      assert html =~ "Jane Smith"

      # Search for "Jane"
      view
      |> element("form[phx-change=\"search\"]")
      |> render_change(%{"search" => %{"query" => "Jane"}})

      html = render(view)
      refute html =~ "John Doe"
      assert html =~ "Jane Smith"
    end

    test "search filters customers by phone", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/customers")

      # Initially shows all customers
      assert html =~ "John Doe"

      # Search by phone
      view
      |> element("form[phx-change=\"search\"]")
      |> render_change(%{"search" => %{"query" => "555-0123"}})

      html = render(view)
      assert html =~ "John Doe"
      assert html =~ "+1 555-0123"
    end

    test "filter by loyalty tier", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/customers")

      # Initially shows all tiers
      assert html =~ "Gold"
      assert html =~ "Silver"

      # Filter to gold tier only
      view
      |> element("select[name=\"loyalty_tier\"]")
      |> render_change(%{"loyalty_tier" => "gold"})

      html = render(view)
      assert html =~ "Gold"
    end

    test "row click navigates to customer detail", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/stores/downtown/customers")

      # Click on a customer row
      view
      |> element("tr[id=\"row-1\"]")
      |> render_click()

      # Should navigate to detail page
      assert_redirect(view, ~p"/app/stores/downtown/customers/1")
    end

    test "shows empty state when no customers match search", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/stores/downtown/customers")

      # Search for non-existent customer
      view
      |> element("form[phx-change=\"search\"]")
      |> render_change(%{"search" => %{"query" => "ZZZ_NONEXISTENT"}})

      html = render(view)
      assert html =~ "No customers found"
    end
  end
end
