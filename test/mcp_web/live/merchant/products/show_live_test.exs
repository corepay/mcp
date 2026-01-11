defmodule McpWeb.Merchant.Products.ShowLiveTest do
  @moduledoc false
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  # Integration test requiring full tenant schema setup
  @moduletag :integration

  alias Mcp.Accounts.Auth
  alias Mcp.Accounts.User
  alias Mcp.Platform.Tenant

  # Test uses mock product data since the ShowLive displays mock data
  # similar to the IndexLive pattern.

  defp create_test_tenant do
    Tenant
    |> Ash.Changeset.for_create(:create, %{
      name: "Test Product Detail Tenant",
      slug: "product-show-#{System.unique_integer([:positive])}",
      subdomain: "product-show-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!()
  end

  defp create_test_user(tenant) do
    User
    |> Ash.Changeset.for_create(:register, %{
      email: "product_show_#{System.unique_integer([:positive])}@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "Merchant"
    })
    |> Ash.Changeset.force_change_attribute(:tenant_id, tenant.id)
    |> Ash.create!()
  end

  defp create_authed_conn(tenant, user) do
    {:ok, session_data} = Auth.create_user_session(user, "127.0.0.1")
    host = "#{tenant.subdomain}.localhost"

    build_conn()
    |> Map.put(:host, host)
    |> put_req_header("x-forwarded-host", host)
    |> init_test_session(%{"tenant_id" => tenant.id})
    |> put_req_cookie("_mcp_access_token", session_data.access_token)
    |> put_req_cookie("_mcp_refresh_token", session_data.refresh_token)
    |> put_req_cookie("_mcp_session_id", session_data.session_id)
  end

  describe "mount/3" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user(tenant)
      conn = create_authed_conn(tenant, user)

      # Use mock product id that ShowLive recognizes
      {:ok, conn: conn, tenant: tenant, user: user, product_id: "1"}
    end

    test "renders product detail with page layout", %{conn: conn, product_id: id} do
      {:ok, view, _html} = live(conn, ~p"/app/products/#{id}")

      assert has_element?(view, "[data-testid='page-layout-detail']")
      assert has_element?(view, "[data-testid='action-sidebar']")
    end

    test "displays product info card with name, SKU, price, description", %{
      conn: conn,
      product_id: id
    } do
      {:ok, view, html} = live(conn, ~p"/app/products/#{id}")

      assert has_element?(view, "[data-testid='product-name']")
      assert has_element?(view, "[data-testid='product-sku']")
      assert has_element?(view, "[data-testid='product-price']")
      assert has_element?(view, "[data-testid='product-description']")

      # Verify mock product data is displayed
      assert html =~ "Widget Pro"
      assert html =~ "SKU-WP-001"
    end

    test "displays inventory section when tracking enabled", %{conn: conn} do
      # Product id "2" has track_inventory: true in mock data
      {:ok, view, _html} = live(conn, ~p"/app/products/2")

      assert has_element?(view, "[data-testid='inventory-section']")
      assert has_element?(view, "[data-testid='stock-quantity']")
      assert has_element?(view, "[data-testid='low-stock-threshold']")
    end

    test "hides inventory section when tracking disabled", %{conn: conn} do
      # Product id "3" has track_inventory: false in mock data
      {:ok, view, _html} = live(conn, ~p"/app/products/3")

      refute has_element?(view, "[data-testid='inventory-section']")
    end

    test "displays AI insights placeholder in sidebar", %{conn: conn, product_id: id} do
      {:ok, _view, html} = live(conn, ~p"/app/products/#{id}")

      assert html =~ "AI insights coming in Phase 5"
    end
  end

  describe "edit mode" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user(tenant)
      conn = create_authed_conn(tenant, user)

      {:ok, conn: conn, tenant: tenant, user: user, product_id: "1"}
    end

    test "switches to edit mode on click", %{conn: conn, product_id: id} do
      {:ok, view, _html} = live(conn, ~p"/app/products/#{id}")

      # Initially in view mode
      assert has_element?(view, "[data-testid='edit-btn']")
      refute has_element?(view, "[data-testid='edit-form']")

      # Click edit button
      view |> element("[data-testid='edit-btn']") |> render_click()

      # Now in edit mode
      assert has_element?(view, "[data-testid='edit-form']")
    end

    test "saves product changes via form submission", %{conn: conn, product_id: id} do
      {:ok, view, _html} = live(conn, ~p"/app/products/#{id}")

      # Enter edit mode
      view |> element("[data-testid='edit-btn']") |> render_click()

      # Submit form with updated name
      view
      |> form("[data-testid='edit-form']", %{
        product: %{name: "Updated Product Name", description: "Updated description"}
      })
      |> render_submit()

      # Verify update was applied (back to view mode with new name)
      html = render(view)
      assert html =~ "Updated Product Name"
    end

    test "validates required fields and shows errors", %{conn: conn, product_id: id} do
      {:ok, view, _html} = live(conn, ~p"/app/products/#{id}")

      # Enter edit mode
      view |> element("[data-testid='edit-btn']") |> render_click()

      # Submit form with empty required field
      view
      |> form("[data-testid='edit-form']", %{product: %{name: ""}})
      |> render_submit()

      # Check for validation error class
      assert has_element?(view, ".input-error")
    end
  end

  describe "variant management" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user(tenant)
      conn = create_authed_conn(tenant, user)

      # Product id "1" has variants in mock data
      {:ok, conn: conn, tenant: tenant, user: user, product_id: "1"}
    end

    test "displays variants list", %{conn: conn, product_id: id} do
      {:ok, view, html} = live(conn, ~p"/app/products/#{id}")

      assert has_element?(view, "[data-testid='variants-section']")
      assert has_element?(view, "[data-testid='variant-row']")
      assert html =~ "Small / Blue"
    end

    test "can add a new variant", %{conn: conn, product_id: id} do
      {:ok, view, _html} = live(conn, ~p"/app/products/#{id}")

      # Click add variant button
      assert has_element?(view, "[data-testid='add-variant-btn']")
      view |> element("[data-testid='add-variant-btn']") |> render_click()

      # Fill and submit variant form
      assert has_element?(view, "form#variant-form")

      view
      |> form("#variant-form", %{
        variant: %{
          name: "Large / Red",
          sku: "NEW-VAR-SKU-123",
          price: "59.99",
          quantity_on_hand: "30"
        }
      })
      |> render_submit()

      # Verify new variant appears
      html = render(view)
      assert html =~ "Large / Red"
    end
  end

  describe "activity log" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user(tenant)
      conn = create_authed_conn(tenant, user)

      {:ok, conn: conn, tenant: tenant, user: user, product_id: "1"}
    end

    test "displays recent activity", %{conn: conn, product_id: id} do
      {:ok, view, _html} = live(conn, ~p"/app/products/#{id}")

      assert has_element?(view, "[data-testid='activity-log']")
    end
  end

  describe "sidebar actions" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user(tenant)
      conn = create_authed_conn(tenant, user)

      {:ok, conn: conn, tenant: tenant, user: user, product_id: "1"}
    end

    test "can duplicate product", %{conn: conn, product_id: id} do
      {:ok, view, _html} = live(conn, ~p"/app/products/#{id}")

      assert has_element?(view, "[data-testid='duplicate-btn']")
      view |> element("[data-testid='duplicate-btn']") |> render_click()

      # Should redirect to the new product copy
      {path, _flash} = assert_redirect(view)
      assert path =~ "/app/products/"
    end

    test "can archive product", %{conn: conn, product_id: id} do
      {:ok, view, _html} = live(conn, ~p"/app/products/#{id}")

      assert has_element?(view, "[data-testid='archive-btn']")

      # Click archive button
      view |> element("[data-testid='archive-btn']") |> render_click()

      # Confirm archive in modal
      assert has_element?(view, "[data-testid='confirm-archive']")
      view |> element("[data-testid='confirm-archive']") |> render_click()

      # Status badge should show archived
      assert has_element?(view, "[data-testid='status-badge']")
      html = render(view)
      assert html =~ "Archived"
    end
  end
end
