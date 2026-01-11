defmodule McpWeb.Components.Terminal.SearchDropdown do
  @moduledoc """
  Search dropdown component for the Virtual Terminal.
  Shows grouped search results with browse links and create options.
  Per design contract lines 139-165.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  attr :query, :string, required: true
  attr :products, :list, default: []
  attr :fees, :list, default: []
  attr :discounts, :list, default: []
  attr :show_dropdown, :boolean, default: false
  attr :class, :string, default: nil

  attr :on_search, :string, default: "search"
  attr :on_select, :string, default: "add_product"
  attr :on_browse, :string, default: "open_browse"
  attr :on_create, :string, default: "show_create_modal"

  attr :ai_interpretation, :map, default: nil
  attr :on_ai_add_all, :string, default: "ai_add_all"
  attr :on_ai_edit_first, :string, default: "ai_edit_first"
  attr :on_ai_dismiss, :string, default: "ai_dismiss"

  def search_dropdown(assigns) do
    ~H"""
    <div class={["search-dropdown relative", @class]}>
      <label class="input input-bordered flex items-center gap-2">
        <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
        <input
          type="text"
          placeholder="Search items or type '2 coffees and a sandwich'..."
          class="grow border-none focus:ring-0"
          value={@query}
          phx-keyup={@on_search}
          phx-debounce="200"
          name="item_query"
          phx-focus="show_search_dropdown"
          autocomplete="off"
        />
        <button
          :if={@query != ""}
          type="button"
          class="btn btn-ghost btn-xs btn-circle"
          phx-click="hide_search_dropdown"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </label>

      <div
        :if={@show_dropdown}
        class="absolute top-full left-0 right-0 mt-1 bg-base-100 rounded-lg shadow-xl border border-base-300 z-50 max-h-96 overflow-y-auto"
      >
        <!-- AI INTERPRETATION (Lines 478-491) -->
        <div :if={@ai_interpretation} class="p-3 bg-info/5 border-b border-info/20">
          <div class="flex items-start gap-2 mb-2">
            <.icon name="hero-sparkles" class="size-4 text-info mt-0.5 flex-shrink-0" />
            <div class="flex-1 min-w-0">
              <p class="text-xs text-base-content/60 mb-1">AI understood:</p>
              <div class="space-y-1">
                <div
                  :for={item <- @ai_interpretation.items}
                  class="flex items-center justify-between text-sm"
                >
                  <span class="flex items-center gap-2">
                    <.icon name="hero-check" class="size-3 text-success" />
                    <span class="font-medium">{item.quantity}×</span>
                    <span>{item.name}</span>
                  </span>
                  <span class="font-medium tabular-nums">{format_price_amount(item.total)}</span>
                </div>
              </div>
              <div class="flex items-center justify-between mt-2 pt-2 border-t border-base-300">
                <span class="text-xs text-base-content/60">
                  Total:
                  <span class="font-semibold">{format_price_amount(@ai_interpretation.total)}</span>
                </span>
              </div>
            </div>
          </div>
          <div class="flex gap-2 mt-2">
            <button
              type="button"
              class="btn btn-primary btn-sm flex-1"
              phx-click={@on_ai_add_all}
            >
              Add All
            </button>
            <button
              type="button"
              class="btn btn-outline btn-sm flex-1"
              phx-click={@on_ai_edit_first}
            >
              Edit First
            </button>
          </div>
        </div>
        
    <!-- PRODUCTS SECTION (Lines 146-150) -->
        <.result_section
          title="Products"
          items={@products}
          type="products"
          on_select={@on_select}
          on_browse={@on_browse}
          query={@query}
        />
        
    <!-- FEES SECTION (Lines 152-155) -->
        <.result_section
          title="Fees"
          items={@fees}
          type="fees"
          on_select={@on_select}
          on_browse={@on_browse}
          query={@query}
        />
        
    <!-- DISCOUNTS SECTION (Lines 157-160) -->
        <.result_section
          title="Discounts"
          items={@discounts}
          type="discounts"
          on_select={@on_select}
          on_browse={@on_browse}
          query={@query}
        />

        <div
          :if={
            length(@products) == 0 && length(@fees) == 0 && length(@discounts) == 0 &&
              !@ai_interpretation && @query != ""
          }
          class="p-4 text-center text-base-content/60"
        >
          <p>No results for "{@query}"</p>
          <p class="text-xs mt-1">Try browsing categories above or create a custom item.</p>
        </div>
        
    <!-- CREATE CUSTOM ITEM FOOTER (Lines 162-163) -->
        <button
          type="button"
          class="w-full flex items-center gap-2 p-3 text-sm font-medium text-primary hover:bg-base-200 border-t border-base-300 transition-colors text-left"
          phx-click={@on_create}
        >
          <.icon name="hero-plus" class="size-4" /> Create custom line item...
        </button>
        
    <!-- Duplicate footer removed -->
      </div>
    </div>
    """
  end

  defp format_price_amount(amount) do
    amount
    |> Decimal.to_string(:normal)
    |> String.split(".")
    |> case do
      [dollars] ->
        "$#{dollars}.00"

      [dollars, cents] ->
        "$#{dollars}.#{String.pad_trailing(cents, 2, "0") |> String.slice(0, 2)}"
    end
  end

  defp result_section(assigns) do
    items = assigns[:items] || []
    query = assigns[:query] || ""

    # Only Render if we have items OR if the user is in "browse mode" (empty query)
    should_show? = length(items) > 0 || query == ""

    assigns =
      assigns
      |> assign(:items, items)
      |> assign(:query, query)
      |> assign(:should_show?, should_show?)

    ~H"""
    <div :if={@should_show?} class="p-2 border-b border-base-300 last:border-0">
      <div class="flex justify-between items-center mb-1 px-2">
        <span class="text-xs font-semibold uppercase text-base-content/50">{@title}</span>
        <!-- BROWSE LINK - PER DESIGN CONTRACT LINE 146 -->
        <button
          type="button"
          class="btn btn-ghost btn-xs"
          phx-click={@on_browse}
          phx-value-type={@type}
        >
          Browse →
        </button>
      </div>

      <div :if={length(@items) == 0} class="px-2 py-1 text-xs text-base-content/40 italic">
        Type to search {@title} or click Browse...
      </div>

      <button
        :for={item <- Enum.take(@items, 5)}
        type="button"
        class="w-full flex items-center gap-2 p-2 rounded hover:bg-base-200 transition-colors text-left"
        phx-click={@on_select}
        phx-value-type={@type}
        phx-value-id={item.id}
      >
        <span class="flex-1 truncate">{item.name}</span>
        <span class="text-sm text-base-content/70 tabular-nums">
          {format_price(item, @type)}
        </span>
      </button>
    </div>
    """
  end

  defp format_price(item, "products"), do: "$#{format_decimal(item.price)}"
  defp format_price(item, "fees"), do: "$#{format_decimal(item.amount)}"

  defp format_price(item, "discounts") do
    if item[:percent] do
      "#{format_decimal(item.amount)}% off"
    else
      "$#{format_decimal(item.amount)} off"
    end
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
