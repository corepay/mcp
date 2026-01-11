defmodule McpWeb.Merchant.Products.IndexLiveTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Merchant.Products.IndexLive

  @endpoint McpWeb.Endpoint

  defp build_socket do
    %Phoenix.LiveView.Socket{
      endpoint: @endpoint,
      router: McpWeb.Router,
      assigns: %{
        __changed__: %{},
        flash: %{}
      }
    }
  end

  describe "mount/3" do
    test "loads sample products and stats" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)

      assert is_list(socket.assigns.products)
      assert length(socket.assigns.products) > 0
      assert socket.assigns.stats.total_products
      assert socket.assigns.search == ""
      assert socket.assigns.category_filter == "all"
      assert socket.assigns.status_filter == "all"
    end
  end

  describe "render/1" do
    setup do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)
      html = render_component(&IndexLive.render/1, socket.assigns)

      {:ok, html: html, socket: socket}
    end

    test "renders page with title 'Products'", %{html: html} do
      assert html =~ "Products"
    end

    test "renders page layout with list variant", %{html: html} do
      # The page layout has a grid with 2/3 + 1/3 split for list variant
      assert html =~ "page-layout"
    end

    test "displays product metrics in stats row", %{html: html} do
      assert html =~ "Total Products"
      assert html =~ "Active"
      assert html =~ "Draft"
    end

    test "displays product data table with correct columns", %{html: html} do
      assert html =~ "Name"
      assert html =~ "Status"
      assert html =~ "Stock"
      assert html =~ "Price"
    end

    test "displays sample product data in table", %{html: html} do
      # Check for some sample product data
      assert html =~ "SKU-"
    end

    test "action sidebar has 'Add Product' action", %{html: html} do
      assert html =~ "QUICK ACTIONS"
      assert html =~ "Add Product"
    end

    test "action sidebar has category filter", %{html: html} do
      assert html =~ "FILTERS"
      assert html =~ "Category"
    end

    test "action sidebar has status filter", %{html: html} do
      assert html =~ "Status"
    end

    test "action sidebar has AI Insights placeholder section", %{html: html} do
      assert html =~ "AI INSIGHTS"
    end
  end

  describe "handle_event/3 - search" do
    test "filters products by search term" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)
      initial_count = length(socket.assigns.filtered_products)

      {:noreply, socket} =
        IndexLive.handle_event("search", %{"search" => "Widget"}, socket)

      assert socket.assigns.search == "Widget"
      # Should have filtered results when search term is specific
      filtered_count = length(socket.assigns.filtered_products)
      assert filtered_count <= initial_count

      assert Enum.all?(socket.assigns.filtered_products, fn p ->
               String.contains?(String.downcase(p.name), "widget") ||
                 String.contains?(String.downcase(p.sku), "widget")
             end)
    end

    test "shows all products when search is empty" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)
      {:noreply, socket} = IndexLive.handle_event("search", %{"search" => "xyz"}, socket)

      # Should have filtered results
      assert length(socket.assigns.filtered_products) < length(socket.assigns.products)

      {:noreply, socket} = IndexLive.handle_event("search", %{"search" => ""}, socket)

      # Should show all again
      assert length(socket.assigns.filtered_products) == length(socket.assigns.products)
    end
  end

  describe "handle_event/3 - filter by category" do
    test "filters products by category" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)

      {:noreply, socket} =
        IndexLive.handle_event("filter_category", %{"category" => "electronics"}, socket)

      assert socket.assigns.category_filter == "electronics"

      assert Enum.all?(socket.assigns.filtered_products, fn p ->
               p.category == :electronics
             end)
    end

    test "shows all products when category filter is 'all'" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)
      total_products = length(socket.assigns.products)

      {:noreply, socket} =
        IndexLive.handle_event("filter_category", %{"category" => "electronics"}, socket)

      assert length(socket.assigns.filtered_products) < total_products

      {:noreply, socket} =
        IndexLive.handle_event("filter_category", %{"category" => "all"}, socket)

      assert length(socket.assigns.filtered_products) == total_products
    end
  end

  describe "handle_event/3 - filter by status" do
    test "filters products by status" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)

      {:noreply, socket} =
        IndexLive.handle_event("filter_status", %{"status" => "active"}, socket)

      assert socket.assigns.status_filter == "active"

      assert Enum.all?(socket.assigns.filtered_products, fn p ->
               p.status == :active
             end)
    end

    test "shows all products when status filter is 'all'" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)
      total_products = length(socket.assigns.products)

      {:noreply, socket} =
        IndexLive.handle_event("filter_status", %{"status" => "active"}, socket)

      assert length(socket.assigns.filtered_products) < total_products

      {:noreply, socket} =
        IndexLive.handle_event("filter_status", %{"status" => "all"}, socket)

      assert length(socket.assigns.filtered_products) == total_products
    end
  end

  describe "handle_event/3 - bulk selection" do
    test "select-all toggles all products selected" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)
      assert socket.assigns.selected_ids == MapSet.new()

      {:noreply, socket} = IndexLive.handle_event("select-all", %{}, socket)

      # Should have selected all products
      expected_count = length(socket.assigns.filtered_products)
      assert MapSet.size(socket.assigns.selected_ids) == expected_count

      # Toggle again to deselect all
      {:noreply, socket} = IndexLive.handle_event("select-all", %{}, socket)
      assert MapSet.size(socket.assigns.selected_ids) == 0
    end

    test "select-row toggles individual product selection" do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)
      product = List.first(socket.assigns.products)

      {:noreply, socket} =
        IndexLive.handle_event("select-row", %{"id" => "row-#{product.id}"}, socket)

      assert MapSet.member?(socket.assigns.selected_ids, product.id)

      # Toggle again to deselect
      {:noreply, socket} =
        IndexLive.handle_event("select-row", %{"id" => "row-#{product.id}"}, socket)

      refute MapSet.member?(socket.assigns.selected_ids, product.id)
    end
  end

  describe "handle_event/3 - actions" do
    setup do
      socket = build_socket()

      {:ok, socket} = IndexLive.mount(%{}, %{}, socket)
      {:ok, socket: socket}
    end

    test "handles add_product event", %{socket: socket} do
      {:noreply, _socket} = IndexLive.handle_event("add_product", %{}, socket)
    end

    test "handles import_products event", %{socket: socket} do
      {:noreply, _socket} = IndexLive.handle_event("import_products", %{}, socket)
    end

    test "handles export_products event", %{socket: socket} do
      {:noreply, _socket} = IndexLive.handle_event("export_products", %{}, socket)
    end

    test "handles view_low_stock event", %{socket: socket} do
      {:noreply, _socket} = IndexLive.handle_event("view_low_stock", %{}, socket)
    end

    test "handles bulk_update_status event", %{socket: socket} do
      {:noreply, _socket} = IndexLive.handle_event("bulk_update_status", %{}, socket)
    end
  end
end
