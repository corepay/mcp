defmodule McpWeb.Store.Products.ShowLiveTest do
  @moduledoc false
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  # Integration test requiring full tenant/store setup
  @moduletag :integration

  alias Mcp.Accounts.Auth
  alias Mcp.Accounts.User
  alias Mcp.Platform.Tenant

  describe "GET /app/stores/:store_slug/products/:id" do
    setup %{conn: _conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Store Products Show Tenant",
          slug: "store-products-show-#{System.unique_integer([:positive])}",
          subdomain: "store-products-show-#{System.unique_integer([:positive])}"
        })
        |> Ash.create!()

      user =
        User
        |> Ash.Changeset.for_create(:register, %{
          email: "store_product_show_#{System.unique_integer([:positive])}@example.com",
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

    test "renders product detail read-only (NO edit button)", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/products/1")

      # Should have page layout with detail variant
      assert has_element?(view, "[data-testid='page-layout-detail']")
      assert html =~ "Premium Tee"

      # Should NOT have edit button (read-only for store staff)
      refute has_element?(view, "[data-testid='edit-btn']")
      refute html =~ "Edit Product"
    end

    test "shows price and stock info", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/downtown/products/1")

      # Should display price with correct test id
      assert has_element?(view, "[data-testid='product-price']")
      assert html =~ "$29.99"

      # Should display stock quantity with correct test id
      assert has_element?(view, "[data-testid='stock-quantity']")
      assert html =~ "50"
    end

    test "can add to POS from detail (quick action)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/stores/downtown/products/1")

      # Should have add to POS button
      assert has_element?(view, "[data-testid='add-to-cart-btn']")

      # Click add to POS button - should not raise an error
      # (POS integration will be implemented later, for now just flash message)
      result =
        view
        |> element("[data-testid='add-to-cart-btn']")
        |> render_click()

      # Event handler executed successfully (no error raised)
      assert is_binary(result)
    end

    test "can adjust stock from detail (opens modal)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/stores/downtown/products/1")

      # Should have adjust stock button
      assert has_element?(view, "[data-testid='adjust-stock-btn']")

      # Click adjust stock button
      view
      |> element("[data-testid='adjust-stock-btn']")
      |> render_click()

      # Should open adjustment modal
      assert has_element?(view, "[data-testid='adjustment-modal']")
    end
  end
end
