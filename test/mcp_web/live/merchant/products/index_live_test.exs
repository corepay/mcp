defmodule McpWeb.Merchant.Products.IndexLiveTest do
  @moduledoc false
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  # Integration test requiring full tenant schema setup
  @moduletag :integration

  alias Mcp.Accounts.Auth
  alias Mcp.Accounts.User
  alias Mcp.Platform.Tenant

  describe "GET /app/products" do
    setup %{conn: _conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Product Tenant",
          slug: "product-test-#{System.unique_integer([:positive])}",
          subdomain: "product-#{System.unique_integer([:positive])}"
        })
        |> Ash.create!()

      user =
        User
        |> Ash.Changeset.for_create(:register, %{
          email: "product_merchant_#{System.unique_integer([:positive])}@example.com",
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

    test "renders product list with page layout", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/products")

      assert html =~ "Products"
      assert has_element?(view, "[data-testid='page-layout-list']")
      assert has_element?(view, "[data-testid='stats-row']")
      assert has_element?(view, "[data-testid='action-sidebar']")
    end

    test "displays AI insights placeholder", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/products")

      assert html =~ "AI insights coming in Phase 5"
    end

    test "displays product metrics in stats row", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/products")

      assert html =~ "Total Products"
      assert html =~ "Active"
      assert html =~ "Draft"
      assert html =~ "Low Stock"
    end

    test "displays product data table with correct columns", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/products")

      assert html =~ "Name"
      assert html =~ "Status"
      assert html =~ "Stock"
      assert html =~ "Price"
    end

    test "displays sample product data in table", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products")

      # Verify product rows are rendered with data-testid
      assert has_element?(view, "[data-testid='product-row']")
    end

    test "has Add Product button with data-testid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products")

      assert has_element?(view, "[data-testid='add-product-btn']")
    end

    test "action sidebar has quick actions section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/products")

      assert html =~ "QUICK ACTIONS"
      assert html =~ "Add Product"
    end

    test "action sidebar has category filter", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/products")

      assert html =~ "FILTERS"
      assert html =~ "Category"
    end

    test "action sidebar has status filter", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/products")

      assert html =~ "Status"
    end
  end

  describe "search" do
    setup %{conn: _conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Search Tenant",
          slug: "search-test-#{System.unique_integer([:positive])}",
          subdomain: "search-#{System.unique_integer([:positive])}"
        })
        |> Ash.create!()

      user =
        User
        |> Ash.Changeset.for_create(:register, %{
          email: "search_merchant_#{System.unique_integer([:positive])}@example.com",
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

    test "filters products by search query", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products")

      # Use the search form to filter
      view
      |> form("#product-search-form", %{search: "Widget"})
      |> render_change()

      # Should still render the page with filtered results
      html = render(view)
      assert html =~ "Widget Pro"
    end
  end

  describe "filters" do
    setup %{conn: _conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Filter Tenant",
          slug: "filter-test-#{System.unique_integer([:positive])}",
          subdomain: "filter-#{System.unique_integer([:positive])}"
        })
        |> Ash.create!()

      user =
        User
        |> Ash.Changeset.for_create(:register, %{
          email: "filter_merchant_#{System.unique_integer([:positive])}@example.com",
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

    test "filters products by category", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products")

      # Trigger category filter change
      render_change(view, "filter_category", %{"category" => "electronics"})

      # Verify page still renders
      html = render(view)
      assert html =~ "Products"
    end

    test "filters products by status", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products")

      # Trigger status filter change
      render_change(view, "filter_status", %{"status" => "active"})

      # Verify page still renders
      html = render(view)
      assert html =~ "Products"
    end
  end

  describe "bulk selection" do
    setup %{conn: _conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Bulk Tenant",
          slug: "bulk-test-#{System.unique_integer([:positive])}",
          subdomain: "bulk-#{System.unique_integer([:positive])}"
        })
        |> Ash.create!()

      user =
        User
        |> Ash.Changeset.for_create(:register, %{
          email: "bulk_merchant_#{System.unique_integer([:positive])}@example.com",
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

    test "select-all toggles all products selected and shows bulk actions bar", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products")

      # Initially no bulk actions bar
      refute has_element?(view, "[data-testid='bulk-actions-bar']")

      # Trigger select-all
      render_click(view, "select-all")

      # Now bulk actions bar should be visible with selected count
      assert has_element?(view, "[data-testid='bulk-actions-bar']")
      assert has_element?(view, "[data-testid='selected-count']")
    end

    test "select-row toggles individual product selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products")

      # Initially no bulk actions bar
      refute has_element?(view, "[data-testid='bulk-actions-bar']")

      # Trigger select-row for first product (id: "1")
      render_click(view, "select-row", %{"id" => "row-1"})

      # Bulk actions bar should now appear
      assert has_element?(view, "[data-testid='bulk-actions-bar']")
    end
  end
end
