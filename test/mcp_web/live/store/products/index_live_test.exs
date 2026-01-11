defmodule McpWeb.Store.Products.IndexLiveTest do
  @moduledoc false
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  # Integration test requiring full tenant/store setup
  @moduletag :integration

  alias Mcp.Accounts.Auth
  alias Mcp.Accounts.User
  alias Mcp.Platform.Tenant

  describe "GET /app/stores/:store_slug/products" do
    setup %{conn: _conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Store Products Tenant",
          slug: "store-products-#{System.unique_integer([:positive])}",
          subdomain: "store-products-#{System.unique_integer([:positive])}"
        })
        |> Ash.create!()

      user =
        User
        |> Ash.Changeset.for_create(:register, %{
          email: "store_products_#{System.unique_integer([:positive])}@example.com",
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

    test "renders product list with read-only view (no add button)", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/products")

      # Should have page layout with list variant
      assert has_element?(view, "[data-testid='page-layout-list']")
      assert html =~ "Products"

      # Should have product rows
      assert has_element?(view, "[data-testid='product-row']")

      # Should NOT have add product button (read-only for store staff)
      refute has_element?(view, "[data-testid='add-product-btn']")
      refute html =~ "Add Product"
      refute html =~ "New Product"
    end

    test "shows product search", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/stores/downtown/products")

      # Should have search input with correct test id
      assert has_element?(view, "[data-testid='product-search']")
      assert has_element?(view, "input[type=\"search\"]")
    end

    test "filters products by search query", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/products")

      # Initially shows all sample products
      assert html =~ "Premium Tee"
      assert html =~ "Coffee Mug"

      # Search for "Tee"
      view
      |> element("form[phx-change=\"search\"]")
      |> render_change(%{"search" => "Tee"})

      html = render(view)
      assert html =~ "Premium Tee"
      refute html =~ "Coffee Mug"
    end

    test "shows stock status for POS reference with warning for low stock", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/products")

      # Should have stock status elements
      assert has_element?(view, "[data-testid='stock-status']")

      # Coffee Mug has low stock (3 < 10 threshold), should have warning class
      assert has_element?(view, "[data-testid='stock-status'].warning")

      # Should display quantity on hand
      assert html =~ "50"
      assert html =~ "3"
    end
  end
end
