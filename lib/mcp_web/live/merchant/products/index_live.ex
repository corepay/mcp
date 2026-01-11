defmodule McpWeb.Merchant.Products.IndexLive do
  @moduledoc """
  Merchant Products index page - displays product catalog with stats, filters, and actions.

  Uses PageLayout with list variant for 2/3 + 1/3 split layout with sidebar.
  """
  use McpWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    products = get_sample_products()
    stats = calculate_stats(products)

    socket =
      socket
      |> assign(:products, products)
      |> assign(:filtered_products, products)
      |> assign(:stats, stats)
      |> assign(:search, "")
      |> assign(:category_filter, "all")
      |> assign(:status_filter, "all")
      |> assign(:selected_ids, MapSet.new())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout variant={:list} title="Products">
      <:stats>
        <.stats_row>
          <.stat
            label="Total Products"
            value={@stats.total_products}
            icon="hero-cube"
          />
          <.stat
            label="Active"
            value={@stats.active_products}
            trend={@stats.active_trend}
            comparison="vs last month"
          />
          <.stat
            label="Draft"
            value={@stats.draft_products}
            icon="hero-pencil-square"
          />
          <.stat
            label="Low Stock"
            value={@stats.low_stock_count}
            trend={@stats.low_stock_trend}
            comparison="need reorder"
          />
        </.stats_row>
      </:stats>

      <:toolbar>
        <form phx-change="search" id="product-search-form" class="flex-1">
          <input
            type="search"
            name="search"
            value={@search}
            placeholder="Search products by name or SKU..."
            class="input input-bordered w-full max-w-xs"
          />
        </form>
        <.bulk_actions_bar :if={MapSet.size(@selected_ids) > 0} count={MapSet.size(@selected_ids)} />
      </:toolbar>

      <:content>
        <.data_table id="products-table" rows={@filtered_products} selectable>
          <:col :let={product} label="Name" field={:name}>
            <div class="flex items-center gap-3">
              <div class="avatar placeholder">
                <div class="bg-neutral text-neutral-content rounded w-10">
                  <%= if product.image_url do %>
                    <img src={product.image_url} alt={product.name} class="rounded" />
                  <% else %>
                    <.icon name="hero-cube" class="size-5" />
                  <% end %>
                </div>
              </div>
              <div>
                <p class="font-medium">{product.name}</p>
                <p class="text-sm text-base-content/60">{product.sku}</p>
              </div>
            </div>
          </:col>

          <:col :let={product} label="Status" field={:status}>
            <span class={["badge badge-sm", status_badge_class(product.status)]}>
              {format_status(product.status)}
            </span>
          </:col>

          <:col :let={product} label="Stock" field={:stock} align={:right}>
            <div class="flex items-center justify-end gap-2">
              <span class={[
                "font-semibold",
                product.quantity_on_hand < product.low_stock_threshold && "text-error"
              ]}>
                {product.quantity_on_hand}
              </span>
              <span
                :if={product.quantity_on_hand < product.low_stock_threshold}
                class="badge badge-error badge-xs"
              >
                Low
              </span>
            </div>
          </:col>

          <:col :let={product} label="Price" field={:price} align={:right}>
            <span class="font-semibold">{format_price(product.price)}</span>
          </:col>

          <:action :let={product}>
            <a href={"/app/products/#{product.id}"} class="btn btn-ghost btn-sm">
              View
            </a>
          </:action>

          <:empty>
            <div class="flex flex-col items-center justify-center py-12 text-base-content/60">
              <.icon name="hero-cube" class="size-12 mb-2" />
              <p>No products found</p>
              <button type="button" class="btn btn-primary btn-sm mt-4" phx-click="add_product">
                Add Your First Product
              </button>
            </div>
          </:empty>
        </.data_table>
      </:content>

      <:sidebar>
        <.action_sidebar>
          <:actions>
            <.sidebar_action icon="hero-plus" label="Add Product" phx-click="add_product" />
            <.sidebar_action
              icon="hero-arrow-up-tray"
              label="Import Products"
              phx-click="import_products"
            />
            <.sidebar_action
              icon="hero-arrow-down-tray"
              label="Export Catalog"
              phx-click="export_products"
            />
          </:actions>

          <:filters>
            <.sidebar_filter
              label="Category"
              options={category_options()}
              field={:category}
              value={@category_filter}
              phx-change="filter_category"
              data-testid="filter-category"
            />
            <.sidebar_filter
              label="Status"
              options={status_options()}
              field={:status}
              value={@status_filter}
              phx-change="filter_status"
              data-testid="filter-status"
            />
          </:filters>

          <:insights>
            <.ai_insight
              message="3 products are running low on stock"
              action="View low stock items"
              phx-click="view_low_stock"
            />
            <.ai_insight
              message="Widget Pro has 25% higher sales than similar products"
              action="Analyze performance"
              phx-click="analyze_performance"
            />
          </:insights>
        </.action_sidebar>
      </:sidebar>
    </.page_layout>
    """
  end

  # Bulk actions bar component
  defp bulk_actions_bar(assigns) do
    ~H"""
    <div class="flex items-center gap-2 bg-primary/10 rounded-lg px-4 py-2">
      <span class="text-sm font-medium">{@count} selected</span>
      <button type="button" class="btn btn-sm btn-ghost" phx-click="bulk_update_status">
        Update Status
      </button>
      <button type="button" class="btn btn-sm btn-ghost text-error" phx-click="bulk_delete">
        Delete
      </button>
    </div>
    """
  end

  @impl true
  def handle_event("search", %{"search" => search_term}, socket) do
    filtered = filter_products(socket.assigns.products, search_term, socket.assigns)

    {:noreply, assign(socket, search: search_term, filtered_products: filtered)}
  end

  @impl true
  def handle_event("filter_category", %{"category" => category}, socket) do
    socket = assign(socket, :category_filter, category)
    filtered = filter_products(socket.assigns.products, socket.assigns.search, socket.assigns)

    {:noreply, assign(socket, filtered_products: filtered)}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    socket = assign(socket, :status_filter, status)
    filtered = filter_products(socket.assigns.products, socket.assigns.search, socket.assigns)

    {:noreply, assign(socket, filtered_products: filtered)}
  end

  @impl true
  def handle_event("select-all", _params, socket) do
    current_selected = socket.assigns.selected_ids
    all_ids = Enum.map(socket.assigns.filtered_products, & &1.id) |> MapSet.new()

    new_selected =
      if MapSet.size(current_selected) == MapSet.size(all_ids) do
        MapSet.new()
      else
        all_ids
      end

    {:noreply, assign(socket, :selected_ids, new_selected)}
  end

  @impl true
  def handle_event("select-row", %{"id" => row_id}, socket) do
    # Extract actual ID from "row-{id}" format
    product_id = String.replace_prefix(row_id, "row-", "")

    new_selected =
      if MapSet.member?(socket.assigns.selected_ids, product_id) do
        MapSet.delete(socket.assigns.selected_ids, product_id)
      else
        MapSet.put(socket.assigns.selected_ids, product_id)
      end

    {:noreply, assign(socket, :selected_ids, new_selected)}
  end

  @impl true
  def handle_event("add_product", _params, socket) do
    # Placeholder for add product action - would navigate to new product form
    {:noreply, socket}
  end

  @impl true
  def handle_event("import_products", _params, socket) do
    # Placeholder for import products action
    {:noreply, socket}
  end

  @impl true
  def handle_event("export_products", _params, socket) do
    # Placeholder for export products action
    {:noreply, socket}
  end

  @impl true
  def handle_event("view_low_stock", _params, socket) do
    # Filter to show only low stock items
    socket = assign(socket, :status_filter, "low_stock")
    filtered = filter_products(socket.assigns.products, socket.assigns.search, socket.assigns)

    {:noreply, assign(socket, filtered_products: filtered)}
  end

  @impl true
  def handle_event("analyze_performance", _params, socket) do
    # Placeholder for AI performance analysis
    {:noreply, socket}
  end

  @impl true
  def handle_event("bulk_update_status", _params, socket) do
    # Placeholder for bulk status update
    {:noreply, socket}
  end

  @impl true
  def handle_event("bulk_delete", _params, socket) do
    # Placeholder for bulk delete
    {:noreply, socket}
  end

  # Private helper functions

  defp get_sample_products do
    [
      %{
        id: "1",
        name: "Widget Pro",
        sku: "SKU-WP-001",
        description: "Professional grade widget",
        price: Money.new(:USD, "49.99"),
        status: :active,
        category: :electronics,
        track_inventory: true,
        quantity_on_hand: 125,
        low_stock_threshold: 10,
        image_url: nil,
        inserted_at: ~U[2025-12-01 10:00:00Z]
      },
      %{
        id: "2",
        name: "Gadget Basic",
        sku: "SKU-GB-002",
        description: "Entry-level gadget for beginners",
        price: Money.new(:USD, "19.99"),
        status: :active,
        category: :electronics,
        track_inventory: true,
        quantity_on_hand: 8,
        low_stock_threshold: 10,
        image_url: nil,
        inserted_at: ~U[2025-11-15 09:00:00Z]
      },
      %{
        id: "3",
        name: "Premium Cable",
        sku: "SKU-PC-003",
        description: "High-quality braided cable",
        price: Money.new(:USD, "12.99"),
        status: :active,
        category: :accessories,
        track_inventory: true,
        quantity_on_hand: 250,
        low_stock_threshold: 20,
        image_url: nil,
        inserted_at: ~U[2025-10-20 16:45:00Z]
      },
      %{
        id: "4",
        name: "Smart Sensor",
        sku: "SKU-SS-004",
        description: "IoT-enabled smart sensor",
        price: Money.new(:USD, "89.99"),
        status: :draft,
        category: :electronics,
        track_inventory: true,
        quantity_on_hand: 0,
        low_stock_threshold: 5,
        image_url: nil,
        inserted_at: ~U[2025-09-10 12:00:00Z]
      },
      %{
        id: "5",
        name: "Travel Case",
        sku: "SKU-TC-005",
        description: "Protective travel case",
        price: Money.new(:USD, "34.99"),
        status: :active,
        category: :accessories,
        track_inventory: true,
        quantity_on_hand: 42,
        low_stock_threshold: 15,
        image_url: nil,
        inserted_at: ~U[2026-01-05 08:00:00Z]
      },
      %{
        id: "6",
        name: "Wireless Charger",
        sku: "SKU-WC-006",
        description: "Fast wireless charging pad",
        price: Money.new(:USD, "29.99"),
        status: :active,
        category: :electronics,
        track_inventory: true,
        quantity_on_hand: 75,
        low_stock_threshold: 10,
        image_url: nil,
        inserted_at: ~U[2026-01-08 14:30:00Z]
      }
    ]
  end

  defp calculate_stats(products) do
    total = length(products)
    active = Enum.count(products, fn p -> p.status == :active end)
    draft = Enum.count(products, fn p -> p.status == :draft end)

    low_stock =
      Enum.count(products, fn p ->
        p.track_inventory and p.quantity_on_hand < p.low_stock_threshold
      end)

    %{
      total_products: to_string(total),
      active_products: to_string(active),
      active_trend: 5,
      draft_products: to_string(draft),
      low_stock_count: to_string(low_stock),
      low_stock_trend: if(low_stock > 0, do: -low_stock, else: 0)
    }
  end

  defp filter_products(products, search_term, assigns) do
    products
    |> filter_by_search(search_term)
    |> filter_by_category(assigns.category_filter)
    |> filter_by_status(assigns.status_filter)
  end

  defp filter_by_search(products, "") do
    products
  end

  defp filter_by_search(products, search_term) do
    search_lower = String.downcase(search_term)

    Enum.filter(products, fn product ->
      String.contains?(String.downcase(product.name), search_lower) ||
        String.contains?(String.downcase(product.sku), search_lower)
    end)
  end

  defp filter_by_category(products, "all"), do: products

  defp filter_by_category(products, category) do
    category_atom = String.to_existing_atom(category)
    Enum.filter(products, fn product -> product.category == category_atom end)
  end

  defp filter_by_status(products, "all"), do: products

  defp filter_by_status(products, "low_stock") do
    Enum.filter(products, fn p ->
      p.track_inventory and p.quantity_on_hand < p.low_stock_threshold
    end)
  end

  defp filter_by_status(products, status) do
    status_atom = String.to_existing_atom(status)
    Enum.filter(products, fn product -> product.status == status_atom end)
  end

  defp category_options do
    [
      {"All Categories", "all"},
      {"Electronics", "electronics"},
      {"Accessories", "accessories"},
      {"Clothing", "clothing"},
      {"Food & Beverage", "food_beverage"}
    ]
  end

  defp status_options do
    [
      {"All Statuses", "all"},
      {"Active", "active"},
      {"Draft", "draft"},
      {"Archived", "archived"},
      {"Low Stock", "low_stock"}
    ]
  end

  defp format_status(:active), do: "Active"
  defp format_status(:draft), do: "Draft"
  defp format_status(:archived), do: "Archived"

  defp status_badge_class(:active), do: "badge-success"
  defp status_badge_class(:draft), do: "badge-warning"
  defp status_badge_class(:archived), do: "badge-ghost"

  defp format_price(%Money{} = money) do
    Money.to_string!(money)
  end

  defp format_price(_), do: "-"
end
