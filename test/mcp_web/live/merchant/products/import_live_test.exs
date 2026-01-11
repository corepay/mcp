defmodule McpWeb.Merchant.Products.ImportLiveTest do
  @moduledoc false
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  # Integration test requiring full tenant schema setup
  @moduletag :integration

  alias Mcp.Accounts.Auth
  alias Mcp.Accounts.User
  alias Mcp.Platform.Tenant

  defp create_test_tenant do
    Tenant
    |> Ash.Changeset.for_create(:create, %{
      name: "Test Product Import Tenant",
      slug: "product-import-#{System.unique_integer([:positive])}",
      subdomain: "product-import-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!()
  end

  defp create_test_user(tenant) do
    User
    |> Ash.Changeset.for_create(:register, %{
      email: "product_import_#{System.unique_integer([:positive])}@example.com",
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

      {:ok, conn: conn, tenant: tenant, user: user}
    end

    test "renders focused layout with wizard", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/products/import")

      assert html =~ "Import Products"
      assert has_element?(view, "[data-testid='focused-layout']")
      assert has_element?(view, "[data-testid='wizard-progress']")
    end

    test "starts on upload step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/import")

      # Upload step should be active
      assert has_element?(view, "[data-testid='step-upload'].active")
      # Other steps should not be active
      refute has_element?(view, "[data-testid='step-mapping'].active")
      refute has_element?(view, "[data-testid='step-preview'].active")
      refute has_element?(view, "[data-testid='step-import'].active")
    end
  end

  describe "file upload step" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user(tenant)
      conn = create_authed_conn(tenant, user)

      {:ok, conn: conn, tenant: tenant, user: user}
    end

    test "shows upload form with file input", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/products/import")

      # Verify form exists with file input for CSV upload
      assert html =~ "import-form"
      assert has_element?(view, "form#import-form")
      assert has_element?(view, "form#import-form input[type='file']")
      assert html =~ "Drop your CSV file here"
    end

    test "proceeds to mapping step after simulated upload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/import")

      # Simulate file upload by triggering the test message
      send(view.pid, {:test_set_csv_data, mock_csv_data()})
      render(view)

      # Click next button to proceed to mapping step
      view
      |> element("[data-testid='next-btn']")
      |> render_click()

      # Should now be on mapping step
      assert has_element?(view, "[data-testid='step-mapping'].active")
      assert has_element?(view, "[data-testid='column-mapper']")
    end
  end

  describe "field mapping step" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user(tenant)
      conn = create_authed_conn(tenant, user)

      {:ok, conn: conn, tenant: tenant, user: user}
    end

    test "shows column mapping interface", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/import")

      # Simulate file upload and navigate to mapping step
      send(view.pid, {:test_set_csv_data, mock_csv_data()})
      render(view)

      view
      |> element("[data-testid='next-btn']")
      |> render_click()

      # Should show column mapper with detected columns
      assert has_element?(view, "[data-testid='column-mapper']")
      html = render(view)
      # Column headers from CSV should be visible
      assert html =~ "name"
      assert html =~ "sku"
      assert html =~ "price"
    end
  end

  describe "preview step" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user(tenant)
      conn = create_authed_conn(tenant, user)

      {:ok, conn: conn, tenant: tenant, user: user}
    end

    test "shows validation preview", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/import")

      # Simulate file upload
      send(view.pid, {:test_set_csv_data, mock_csv_data()})
      render(view)

      # Proceed through mapping to preview
      view |> element("[data-testid='next-btn']") |> render_click()
      view |> element("[data-testid='next-btn']") |> render_click()

      # Should show preview with validation results
      assert has_element?(view, "[data-testid='step-preview'].active")
      assert has_element?(view, "[data-testid='preview-table']")
      assert has_element?(view, "[data-testid='valid-count']")
    end
  end

  describe "import execution" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user(tenant)
      conn = create_authed_conn(tenant, user)

      {:ok, conn: conn, tenant: tenant, user: user}
    end

    test "imports valid products with progress", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/import")

      # Simulate file upload
      send(view.pid, {:test_set_csv_data, mock_csv_data()})
      render(view)

      # Navigate through wizard: upload -> mapping -> preview -> import
      view |> element("[data-testid='next-btn']") |> render_click()
      view |> element("[data-testid='next-btn']") |> render_click()

      # On preview step, click import button
      view
      |> element("[data-testid='import-btn']")
      |> render_click()

      # Should show import progress or completion
      html = render(view)

      assert has_element?(view, "[data-testid='import-progress']") or
               has_element?(view, "[data-testid='import-complete']")

      # Should show imported count
      assert html =~ "2" or has_element?(view, "[data-testid='imported-count']")
    end
  end

  describe "exit behavior" do
    setup do
      tenant = create_test_tenant()
      user = create_test_user(tenant)
      conn = create_authed_conn(tenant, user)

      {:ok, conn: conn, tenant: tenant, user: user}
    end

    test "exit button returns to product list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/import")

      assert has_element?(view, "[data-testid='exit-btn']")

      view
      |> element("[data-testid='exit-btn']")
      |> render_click()

      {path, _flash} = assert_redirect(view)
      assert path == "/app/products"
    end
  end

  # Helper to create mock CSV data for testing
  defp mock_csv_data do
    %{
      headers: ["name", "sku", "price"],
      rows: [
        %{values: ["Product A", "SKU-001", "29.99"]},
        %{values: ["Product B", "SKU-002", "19.99"]}
      ],
      row_count: 2,
      filename: "products.csv"
    }
  end
end
