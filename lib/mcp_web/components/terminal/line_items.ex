defmodule McpWeb.Components.Terminal.LineItems do
  @moduledoc """
  Line items list component for the Virtual Terminal.
  Shows products, fees, discounts, and tips with quantity controls.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  attr :items, :list, default: []
  attr :on_remove, :string, default: "remove_item"
  attr :on_increment, :string, default: "increment_item"
  attr :on_decrement, :string, default: "decrement_item"
  attr :class, :string, default: nil

  def line_items(assigns) do
    ~H"""
    <div class={["line-items", @class]}>
      <%= if length(@items) == 0 do %>
        <.empty_state />
      <% else %>
        <div class="space-y-2">
          <.line_item
            :for={item <- @items}
            item={item}
            on_remove={@on_remove}
            on_increment={@on_increment}
            on_decrement={@on_decrement}
          />
        </div>
      <% end %>
    </div>
    """
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="text-center py-12 text-base-content/50">
      <.icon name="hero-shopping-cart" class="size-12 mx-auto mb-3 opacity-30" />
      <p>No items added yet</p>
      <p class="text-sm">Search or add products, fees, and discounts to build an order</p>
    </div>
    """
  end

  defp line_item(assigns) do
    ~H"""
    <div class="flex items-center gap-3 p-3 bg-base-200/50 rounded-lg">
      <div class="w-10 h-10 bg-base-200 rounded flex items-center justify-center text-lg">
        {item_icon(@item.type)}
      </div>

      <div class="flex-1 min-w-0">
        <div class="flex justify-between items-start">
          <span class="font-medium truncate">{@item.name}</span>
          <span class={["tabular-nums font-semibold ml-2", @item.type == :discount && "text-success"]}>
            {format_amount(@item.line_total)}
          </span>
        </div>
        <div :if={@item.type == :product && @item.quantity > 1} class="text-sm text-base-content/60">
          {format_amount(@item.unit_price)} × {@item.quantity}
        </div>
      </div>

      <%= if @item.type == :product do %>
        <.quantity_controls item={@item} on_increment={@on_increment} on_decrement={@on_decrement} />
      <% end %>

      <button
        type="button"
        class="btn btn-ghost btn-xs btn-circle"
        phx-click={@on_remove}
        phx-value-id={@item.id}
        aria-label="Remove item"
      >
        <.icon name="hero-x-mark" class="size-4" />
      </button>
    </div>
    """
  end

  defp quantity_controls(assigns) do
    ~H"""
    <div class="join">
      <button
        type="button"
        class="btn btn-ghost btn-xs join-item"
        phx-click={@on_decrement}
        phx-value-id={@item.id}
        disabled={@item.quantity <= 1}
      >
        <.icon name="hero-minus" class="size-3" />
      </button>
      <span class="btn btn-ghost btn-xs join-item no-animation cursor-default tabular-nums">
        {@item.quantity}
      </span>
      <button
        type="button"
        class="btn btn-ghost btn-xs join-item"
        phx-click={@on_increment}
        phx-value-id={@item.id}
      >
        <.icon name="hero-plus" class="size-3" />
      </button>
    </div>
    """
  end

  defp item_icon(:product), do: "📦"
  defp item_icon(:fee), do: "🚚"
  defp item_icon(:discount), do: "🏷️"
  defp item_icon(:tip), do: "💰"

  defp format_amount(amount) do
    sign = if Decimal.negative?(amount), do: "-", else: ""
    abs_amount = Decimal.abs(amount)

    formatted =
      abs_amount
      |> Decimal.to_string(:normal)
      |> String.split(".")
      |> case do
        [dollars] ->
          "#{dollars}.00"

        [dollars, cents] ->
          "#{dollars}.#{String.pad_trailing(cents, 2, "0") |> String.slice(0, 2)}"
      end

    "#{sign}$#{formatted}"
  end
end
