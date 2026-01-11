defmodule McpWeb.Merchant.Products.CategoriesLiveTest do
  @moduledoc false
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  # Integration test requiring full tenant schema setup
  @moduletag :integration

  alias Mcp.Accounts.Auth
  alias Mcp.Accounts.User
  alias Mcp.Platform.Tenant

  # Test uses mock category data similar to IndexLive/ShowLive patterns

  defp create_test_tenant do
    Tenant
    |> Ash.Changeset.for_create(:create, %{
      name: "Test Categories Tenant",
      slug: "categories-#{System.unique_integer([:positive])}",
      subdomain: "categories-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!()
  end

  defp create_test_user(tenant) do
    User
    |> Ash.Changeset.for_create(:register, %{
      email: "categories_merchant_#{System.unique_integer([:positive])}@example.com",
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

  describe "mount/3 - renders categories list" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user(tenant)
      conn = create_authed_conn(tenant, user)

      {:ok, conn: conn, tenant: tenant, user: user}
    end

    test "renders categories list with page layout", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/products/categories")

      assert html =~ "Categories"
      assert has_element?(view, "[data-testid='page-layout-list']")
    end

    test "displays category tree with parent and children", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/products/categories")

      # Verify category rows are rendered
      assert has_element?(view, "[data-testid='category-row']")

      # Verify parent category is displayed
      assert html =~ "Electronics"

      # Verify child/subcategory is displayed
      assert html =~ "Phones"
    end

    test "shows product counts per category", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      # Verify product count elements exist
      assert has_element?(view, "[data-testid='category-count']")
    end
  end

  describe "create category - modal and form" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user(tenant)
      conn = create_authed_conn(tenant, user)

      {:ok, conn: conn, tenant: tenant, user: user}
    end

    test "opens modal on add category click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      # Click add category button
      assert has_element?(view, "[data-testid='add-category-btn']")
      view |> element("[data-testid='add-category-btn']") |> render_click()

      # Modal should be visible
      assert has_element?(view, "[data-testid='category-modal']")
    end

    test "creates new category via form submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      # Open modal
      view |> element("[data-testid='add-category-btn']") |> render_click()

      # Submit form with new category
      view
      |> form("#category-form", %{category: %{name: "New Category"}})
      |> render_submit()

      # Verify new category appears
      html = render(view)
      assert html =~ "New Category"
    end

    test "creates nested category (subcategory) under parent", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      # Click add subcategory button for Electronics (id: "1")
      assert has_element?(view, "[data-testid='add-subcategory-1']")
      view |> element("[data-testid='add-subcategory-1']") |> render_click()

      # Modal should be visible
      assert has_element?(view, "[data-testid='category-modal']")

      # Submit form with new subcategory
      view
      |> form("#category-form", %{category: %{name: "Tablets"}})
      |> render_submit()

      # Verify new subcategory appears
      html = render(view)
      assert html =~ "Tablets"
    end
  end

  describe "edit category" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user(tenant)
      conn = create_authed_conn(tenant, user)

      {:ok, conn: conn, tenant: tenant, user: user}
    end

    test "edits category name via form submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      # Click edit button for Electronics (id: "1")
      assert has_element?(view, "[data-testid='edit-category-1']")
      view |> element("[data-testid='edit-category-1']") |> render_click()

      # Modal should be visible
      assert has_element?(view, "[data-testid='category-modal']")

      # Submit form with updated name
      view
      |> form("#category-form", %{category: %{name: "Consumer Electronics"}})
      |> render_submit()

      # Verify updated name appears
      html = render(view)
      assert html =~ "Consumer Electronics"
    end
  end

  describe "delete category" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user(tenant)
      conn = create_authed_conn(tenant, user)

      {:ok, conn: conn, tenant: tenant, user: user}
    end

    test "deletes empty category", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/products/categories")

      # Apparel has 0 products (empty) - can delete without warning
      # First verify it exists
      assert html =~ "Apparel"

      # Click delete button for Apparel (id: "2")
      assert has_element?(view, "[data-testid='delete-category-2']")
      view |> element("[data-testid='delete-category-2']") |> render_click()

      # Confirm delete
      assert has_element?(view, "[data-testid='confirm-delete']")
      view |> element("[data-testid='confirm-delete']") |> render_click()

      # Category should be removed
      html = render(view)
      refute html =~ "Apparel"
    end

    test "warns when deleting category with products", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      # Electronics has 15 products - should show warning
      # Click delete button for Electronics (id: "1")
      view |> element("[data-testid='delete-category-1']") |> render_click()

      # Warning should be visible
      assert has_element?(view, "[data-testid='delete-warning']")
    end
  end

  describe "reordering categories" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user(tenant)
      conn = create_authed_conn(tenant, user)

      {:ok, conn: conn, tenant: tenant, user: user}
    end

    test "can reorder categories via hook event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      # Simulate drag-drop reorder event from JS hook
      # Moving category at position 0 to position 1
      render_hook(view, "reorder", %{"from" => 0, "to" => 1})

      # Verify page still renders correctly after reorder
      assert has_element?(view, "[data-testid='category-row']")
    end
  end
end
