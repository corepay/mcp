defmodule McpWeb.Components.Terminal.BrowseDrawer do
  @moduledoc """
  Browse drawer for exploring products, fees, and discounts from catalog.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  attr :type, :atom, required: true, values: [:products, :fees, :discounts]
  attr :items, :list, default: []
  attr :categories, :list, default: []
  attr :selected_category, :string, default: nil
  attr :search, :string, default: ""
  attr :category_filter, :string, default: nil
  attr :price_filter, :string, default: nil

  attr :search_query, :string, default: ""
  attr :loading, :boolean, default: false
  attr :on_search, :string, default: "browse_search"
  attr :on_category_filter, :string, default: "browse_category"
  attr :on_select, :string, default: "browse_select"
  attr :on_create, :string, default: "create_new_item"
  attr :class, :string, default: nil

  def browse_drawer(assigns) do
    ~H"""
    <div class={["browse-drawer flex flex-col h-full", @class]}>
      <div class="flex-shrink-0 space-y-4 pb-4 border-b border-base-300">
        <div class="flex items-center justify-between">
          <h3 class="text-lg font-semibold">{type_title(@type)}</h3>
          <button
            type="button"
            class="btn btn-primary btn-sm"
            phx-click={@on_create}
            phx-value-type={@type}
          >
            <.icon name="hero-plus" class="size-4" /> Create New
          </button>
        </div>

        <div class="form-control">
          <label class="input input-bordered flex items-center gap-2">
            <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
            <input
              type="text"
              placeholder={"Search #{type_label(@type)}..."}
              class="grow border-none focus:ring-0"
              value={@search_query}
              phx-keyup={@on_search}
              phx-debounce="300"
              name="browse_query"
            />
          </label>
        </div>
      </div>

      <div class="flex-1 overflow-y-auto py-4">
        <%= if @loading do %>
          <.loading_state />
        <% else %>
          <%= if length(@items) == 0 do %>
            <.empty_state type={@type} search_query={@search_query} />
          <% else %>
            <.items_list items={@items} type={@type} on_select={@on_select} />
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp items_list(assigns) do
    ~H"""
    <div class="space-y-2">
      <button
        :for={item <- @items}
        type="button"
        class="w-full flex items-center gap-3 p-3 rounded-lg hover:bg-base-200 transition-colors text-left"
        phx-click={@on_select}
        phx-value-id={item.id}
        phx-value-type={@type}
      >
        <div class="w-12 h-12 bg-base-200 rounded-lg flex items-center justify-center flex-shrink-0">
          <span class="text-2xl">{type_icon(@type)}</span>
        </div>

        <div class="flex-1 min-w-0">
          <p class="font-medium truncate">{item.name}</p>
          <p :if={item[:description]} class="text-sm text-base-content/60 truncate">
            {item.description}
          </p>
        </div>

        <div class="text-right flex-shrink-0">
          <p class="font-semibold tabular-nums">{format_price(item, @type)}</p>
        </div>
      </button>
    </div>
    """
  end

  defp loading_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-12">
      <div class="loading loading-spinner loading-lg text-primary mb-2"></div>
      <p class="text-sm text-base-content/70">Loading...</p>
    </div>
    """
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-12 text-center">
      <div class="w-16 h-16 bg-base-200 rounded-full flex items-center justify-center mb-4">
        <.icon name="hero-inbox" class="size-8 text-base-content/30" />
      </div>
      <%= if @search_query != "" do %>
        <p class="font-medium">No results found</p>
        <p class="text-sm text-base-content/70">Try a different search term</p>
      <% else %>
        <p class="font-medium">No {type_label(@type)}</p>
      <% end %>
    </div>
    """
  end

  defp type_title(:products), do: "Browse Products"
  defp type_title(:fees), do: "Browse Fees"
  defp type_title(:discounts), do: "Browse Discounts"

  defp type_label(:products), do: "products"
  defp type_label(:fees), do: "fees"
  defp type_label(:discounts), do: "discounts"

  defp type_icon(:products), do: "📦"
  defp type_icon(:fees), do: "🚚"
  defp type_icon(:discounts), do: "🏷️"

  defp format_price(item, :products), do: "$#{format_decimal(item.price)}"

  defp format_price(item, :fees) do
    if item[:percent],
      do: "#{format_decimal(item.amount)}%",
      else: "$#{format_decimal(item.amount)}"
  end

  defp format_price(item, :discounts) do
    if item[:percent],
      do: "#{format_decimal(item.amount)}% off",
      else: "$#{format_decimal(item.amount)} off"
  end

  defp format_decimal(decimal) do
    decimal
    |> Decimal.to_string(:normal)
    |> String.split(".")
    |> case do
      [dollars] -> "#{dollars}.00"
      [dollars, cents] -> "#{dollars}.#{String.pad_trailing(cents, 2, "0") |> String.slice(0, 2)}"
    end
  end
end
