defmodule McpWeb.Store.Products.IndexLive do
  @moduledoc """
  Store Products index page - READ-ONLY product search for store staff.

  Store staff can search and view products for POS reference,
  but cannot add, edit, or delete products (merchant-only actions).
  Uses PageLayout with list variant for 2/3 + 1/3 split layout with sidebar.
  """
  use McpWeb, :live_view

  @impl true
  def mount(%{"store_slug" => store_slug}, _session, socket) do
    products = get_sample_products()

    socket =
      socket
      |> assign(:page_title, "Products")
      |> assign(:store_slug, store_slug)
      |> assign(:products, products)
      |> assign(:filtered_products, products)
      |> assign(:search, "")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout variant={:list} title="Products" data-testid="page-layout-list">
      <:toolbar>
        <form phx-change="search" id="product-search-form" class="flex-1">
          <input
            type="search"
            name="search"
            value={@search}
            placeholder="Search products by name or SKU..."
            class="input input-bordered w-full max-w-md"
            phx-debounce="300"
            data-testid="product-search"
          />
        </form>
      </:toolbar>

      <:content>
        <.data_table
          id="products-table"
          rows={@filtered_products}
          row_click={true}
          row_testid="product-row"
        >
          <:col :let={product} label="Name" field={:name}>
            <div class="flex items-center gap-3">
              <div class="avatar placeholder">
                <div class="bg-neutral text-neutral-content rounded w-10">
                  <.icon name="hero-cube" class="size-5" />
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
            <div
              class={[
                "flex items-center justify-end gap-2",
                product.is_low_stock && "warning"
              ]}
              data-testid="stock-status"
            >
              <span class={[
                "font-semibold",
                product.is_low_stock && "text-warning"
              ]}>
                {product.quantity_on_hand}
              </span>
              <span
                :if={product.is_low_stock}
                class="badge badge-warning badge-xs"
              >
                Low
              </span>
            </div>
          </:col>

          <:col :let={product} label="Price" field={:price} align={:right}>
            <span class="font-semibold">{format_price(product.price)}</span>
          </:col>

          <:empty>
            <div class="flex flex-col items-center justify-center py-12 text-base-content/60">
              <.icon name="hero-cube" class="size-12 mb-2" />
              <p class="font-medium">No products found</p>
              <p class="text-sm">Try adjusting your search</p>
            </div>
          </:empty>
        </.data_table>
      </:content>

      <:sidebar>
        <.action_sidebar>
          <:filters>
            <.sidebar_filter
              label="Status"
              options={status_options()}
              field={:status}
              value=""
              phx-change="filter_status"
            />
          </:filters>

          <:insights>
            <.ai_insight
              message="2 products are running low on stock"
              action="View low stock"
              href="#"
            />
          </:insights>
        </.action_sidebar>
      </:sidebar>
    </.page_layout>
    """
  end

  @impl true
  def handle_event("search", %{"search" => search_term}, socket) do
    filtered = filter_products(socket.assigns.products, search_term)

    {:noreply, assign(socket, search: search_term, filtered_products: filtered)}
  end

  @impl true
  def handle_event("filter_status", %{"status" => _status}, socket) do
    # Placeholder for status filter
    {:noreply, socket}
  end

  @impl true
  def handle_event("row-click", %{"id" => id}, socket) do
    # Extract numeric ID from "row-N" format
    product_id = String.replace_prefix(id, "row-", "")
    store_slug = socket.assigns.store_slug

    # Product detail view to be implemented in future task
    {:noreply, push_navigate(socket, to: "/app/stores/#{store_slug}/products/#{product_id}")}
  end

  # Private helper functions

  defp get_sample_products do
    [
      %{
        id: "1",
        name: "Premium Tee",
        sku: "TEE-001",
        price: Money.new(:USD, "29.99"),
        status: :active,
        track_inventory: true,
        quantity_on_hand: 50,
        low_stock_threshold: 10,
        is_low_stock: false
      },
      %{
        id: "2",
        name: "Coffee Mug",
        sku: "MUG-001",
        price: Money.new(:USD, "14.99"),
        status: :active,
        track_inventory: true,
        quantity_on_hand: 3,
        low_stock_threshold: 10,
        is_low_stock: true
      }
    ]
  end

  defp filter_products(products, "") do
    products
  end

  defp filter_products(products, search_term) do
    search_lower = String.downcase(search_term)

    Enum.filter(products, fn product ->
      String.contains?(String.downcase(product.name), search_lower) ||
        String.contains?(String.downcase(product.sku), search_lower)
    end)
  end

  defp status_options do
    [
      {"All Statuses", ""},
      {"Active", "active"},
      {"Draft", "draft"},
      {"Archived", "archived"}
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
