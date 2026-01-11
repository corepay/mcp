defmodule McpWeb.Components.Pos.ProductGrid do
  @moduledoc """
  POS Product Grid component for product selection interface.

  Features:
  - Search input with barcode scanning
  - Category filtering tabs
  - Product grid with responsive layout
  - Custom item creation
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents

  attr :products, :list, required: true, doc: "List of products to display"
  attr :categories, :list, required: true, doc: "List of available categories"
  attr :selected_category, :string, default: nil, doc: "Currently selected category"
  attr :search_query, :string, default: "", doc: "Current search query"

  def product_grid(assigns) do
    ~H"""
    <div class="flex flex-col gap-4 h-full">
      <!-- Search Bar -->
      <div class="flex gap-2">
        <div class="flex-1 relative">
          <input
            type="text"
            class="input input-bordered w-full"
            placeholder="Search or scan..."
            value={@search_query}
            data-testid="product-search"
            phx-debounce="300"
          />
        </div>
        <button
          type="button"
          class="btn btn-outline"
          data-testid="barcode-scan-btn"
          phx-click="scan_barcode"
        >
          <.icon name="hero-qr-code" class="h-5 w-5" />
        </button>
      </div>
      
    <!-- Category Tabs -->
      <div class="tabs tabs-boxed">
        <button
          type="button"
          class={"tab #{if is_nil(@selected_category), do: "tab-active", else: ""}"}
          phx-click="select_category"
          phx-value-category=""
        >
          All
        </button>
        <%= for category <- @categories do %>
          <button
            type="button"
            class={"tab #{if @selected_category == category, do: "tab-active", else: ""}"}
            phx-click="select_category"
            phx-value-category={category}
          >
            {category}
          </button>
        <% end %>
      </div>
      
    <!-- Product Grid -->
      <div class="flex-1 overflow-y-auto">
        <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          <%= for product <- @products do %>
            <button
              type="button"
              class="card bg-base-200 hover:bg-base-300 cursor-pointer transition-colors p-4"
              phx-click="add_to_cart"
              phx-value-product-id={product.id}
              data-testid="product-tile"
            >
              <div class="flex flex-col gap-2">
                <!-- Image Placeholder -->
                <div class="aspect-square bg-base-300 rounded-lg flex items-center justify-center">
                  <%= if product.image_url do %>
                    <img
                      src={product.image_url}
                      alt={product.name}
                      class="w-full h-full object-cover rounded-lg"
                    />
                  <% else %>
                    <.icon name="hero-photo" class="h-12 w-12 text-base-content/20" />
                  <% end %>
                </div>
                
    <!-- Product Info -->
                <div class="text-left">
                  <h3 class="font-medium text-sm line-clamp-2">{product.name}</h3>
                  <p class="text-lg font-bold text-primary">${format_price(product.price)}</p>
                </div>
              </div>
            </button>
          <% end %>
        </div>
      </div>
      
    <!-- Custom Item Button -->
      <div class="mt-4">
        <button
          type="button"
          class="btn btn-outline w-full"
          data-testid="custom-item-btn"
          phx-click="add_custom_item"
        >
          + Custom Item
        </button>
      </div>
    </div>
    """
  end

  defp format_price(%Decimal{} = price) do
    price |> Decimal.round(2) |> Decimal.to_string()
  end
end
