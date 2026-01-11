defmodule McpWeb.Merchant.Products.InventoryLiveTest do
  @moduledoc false
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  # Integration test requiring full tenant schema setup
  @moduletag :integration

  alias Mcp.Accounts.Auth
  alias Mcp.Accounts.User
  alias Mcp.Platform.Tenant

  describe "mount/3" do
    setup :setup_auth

    test "renders full-width inventory table with page layout", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/products/inventory")

      assert html =~ "Inventory"
      assert has_element?(view, "[data-testid='page-layout-table']")
      assert has_element?(view, "[data-testid='data-table']")
    end

    test "shows inventory stats (total items, low stock, out of stock)", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/products/inventory")

      # Check stats row exists
      assert has_element?(view, "[data-testid='stat-total-items']")
      assert has_element?(view, "[data-testid='stat-low-stock']")
      assert has_element?(view, "[data-testid='stat-out-of-stock']")

      # Check values are displayed
      assert html =~ "Total Items"
      assert html =~ "Low Stock"
      assert html =~ "Out of Stock"
    end
  end

  describe "filtering" do
    setup :setup_auth

    test "filters to low stock only", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/inventory")

      # Click low stock filter
      assert has_element?(view, "[data-testid='filter-low-stock']")
      render_click(view, "filter", %{"filter" => "low_stock"})

      # Verify filtered results
      html = render(view)
      # Gadget Basic has low stock (quantity 5, threshold 10)
      assert html =~ "Gadget Basic"
      # Widget Pro has normal stock (125 > 10)
      refute html =~ "Widget Pro"
    end

    test "filters to out of stock only", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/inventory")

      # Click out of stock filter
      assert has_element?(view, "[data-testid='filter-out-of-stock']")
      render_click(view, "filter", %{"filter" => "out_of_stock"})

      # Verify filtered results
      html = render(view)
      # Smart Sensor has 0 quantity
      assert html =~ "Smart Sensor"
      # Widget Pro has 125 quantity
      refute html =~ "Widget Pro"
    end
  end

  describe "stock adjustment" do
    setup :setup_auth

    test "opens adjustment modal on click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/inventory")

      # Initially modal should not be visible
      refute has_element?(view, "[data-testid='adjustment-modal'].modal-open")

      # Click adjust button for first product
      assert has_element?(view, "[data-testid='adjust-1']")
      render_click(view, "open_adjustment", %{"id" => "1"})

      # Modal should now be visible
      assert has_element?(view, "[data-testid='adjustment-modal'].modal-open")
    end

    test "adjusts stock quantity", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/inventory")

      # Open adjustment modal for product 1
      render_click(view, "open_adjustment", %{"id" => "1"})

      # Submit adjustment form
      render_submit(view, "adjust_stock", %{
        "adjustment" => %{
          "product_id" => "1",
          "type" => "add",
          "quantity" => "10",
          "reason" => "Restock"
        }
      })

      # Verify quantity was updated (125 + 10 = 135)
      html = render(view)
      assert html =~ "135"
    end
  end

  describe "bulk adjustments" do
    setup :setup_auth

    test "can select multiple and bulk adjust", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/inventory")

      # Initially bulk adjust button should be disabled or hidden
      refute has_element?(view, "[data-testid='bulk-adjust-btn']:not([disabled])")

      # Select multiple products
      render_click(view, "select-row", %{"id" => "row-1"})
      render_click(view, "select-row", %{"id" => "row-2"})

      # Now bulk adjust button should be visible
      assert has_element?(view, "[data-testid='bulk-adjust-btn']")

      # Click bulk adjust
      render_click(view, "open_bulk_adjustment")

      # Bulk adjustment modal should be visible
      assert has_element?(view, "[data-testid='bulk-adjustment-modal'].modal-open")
    end
  end

  describe "export" do
    setup :setup_auth

    test "export button exists", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/inventory")

      assert has_element?(view, "[data-testid='export-btn']")
    end
  end

  # Private helper for setting up authenticated connection
  defp setup_auth(%{conn: _conn}) do
    tenant =
      Tenant
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Inventory Tenant",
        slug: "inventory-test-#{System.unique_integer([:positive])}",
        subdomain: "inventory-#{System.unique_integer([:positive])}"
      })
      |> Ash.create!()

    user =
      User
      |> Ash.Changeset.for_create(:register, %{
        email: "inventory_merchant_#{System.unique_integer([:positive])}@example.com",
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
end
