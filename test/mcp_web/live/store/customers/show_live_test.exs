defmodule McpWeb.Store.Customers.ShowLiveTest do
  @moduledoc false
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  # Integration test requiring full tenant/store setup
  @moduletag :integration

  alias Mcp.Accounts.Auth
  alias Mcp.Accounts.User
  alias Mcp.Platform.Tenant

  describe "GET /app/stores/:store_slug/customers/:id" do
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

    test "renders customer show page with customer name as title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown/customers/1")

      assert html =~ "John Doe"
    end

    test "renders back link to customers index using store_slug", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/stores/downtown/customers/1")

      assert has_element?(view, "a[href=\"/app/stores/downtown/customers\"]")
    end

    test "renders customer profile card with avatar", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/stores/downtown/customers/1")

      # Check for avatar/profile section with initials
      assert has_element?(view, "div.avatar.placeholder")
      assert has_element?(view, "div", "JD")
    end

    test "renders customer profile with name", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown/customers/1")

      assert html =~ "John Doe"
    end

    test "does not render email (store staff read-only)", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown/customers/1")

      # Store staff should NOT see email
      refute html =~ "john@example.com"
      refute html =~ "hero-envelope"
    end

    test "renders customer profile with phone", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown/customers/1")

      assert html =~ "+1 555-0123"
    end

    test "renders customer loyalty tier badge", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/stores/downtown/customers/1")

      # Check for loyalty tier badge
      assert has_element?(view, "div", "Gold")
    end

    test "renders customer loyalty points", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown/customers/1")

      assert html =~ "1,250"
    end

    test "renders recent transactions table with last 5 transactions", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/customers/1")

      # Check for recent transactions section
      assert html =~ "Recent Transactions"

      # Check table headers
      assert has_element?(view, "th", "Date")
      assert has_element?(view, "th", "Amount")
      assert has_element?(view, "th", "Status")
    end

    test "renders transaction data in table", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/downtown/customers/1")

      # Check for sample transaction data
      assert html =~ "$125.00"
      assert html =~ "Completed"
    end

    test "does not render edit action (read-only for store staff)", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/customers/1")

      # Should NOT have edit/contact/notes actions
      refute html =~ "Edit Customer"
      refute has_element?(view, "button", "Edit Customer")
    end

    test "does not render contact action (read-only for store staff)", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/customers/1")

      refute html =~ "Contact Customer"
      refute has_element?(view, "button", "Contact Customer")
    end

    test "does not render view notes action (read-only for store staff)", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/customers/1")

      refute html =~ "View Notes"
      refute has_element?(view, "button", "View Notes")
    end

    test "renders AI Insights section in sidebar", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/customers/1")

      # Check for AI Insights section header
      assert html =~ "AI INSIGHTS"

      # Check for at least one insight
      assert has_element?(view, "div", "Frequent visitor")
    end

    test "renders page layout in detail variant", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/stores/downtown/customers/1")

      # Verify the 2/3 + 1/3 grid layout is present (detail variant)
      assert has_element?(view, "div.grid.grid-cols-1.lg\\:grid-cols-3")
    end
  end
end
