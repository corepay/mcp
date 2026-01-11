defmodule McpWeb.Components.Terminal.OrderSummary do
  @moduledoc """
  Order summary component for the Virtual Terminal.
  Shows individual line items, subtotal, discounts, tax, total, and action buttons.
  Per design contract lines 232-247.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  attr :items, :list, default: []
  attr :subtotal, :any, required: true
  attr :tax, :any, required: true
  attr :total, :any, required: true
  attr :tax_rate, :any, default: Decimal.new("0.0825")
  attr :can_charge, :boolean, default: false
  attr :can_send_link, :boolean, default: false
  attr :can_email, :boolean, default: false
  attr :on_charge, :string, default: "open_payment"
  attr :on_send_link, :string, default: "open_send_link"
  attr :on_email, :string, default: "open_email"
  attr :class, :string, default: nil

  def order_summary(assigns) do
    ~H"""
    <div class={["order-summary flex flex-col h-full", @class]}>
      <!-- INDIVIDUAL LINE ITEMS - PER DESIGN CONTRACT LINES 34-48 -->
    <!-- Per Design Contract Lines 34-40: Products aggregated, Fees/Discounts explicit -->
      <div class="flex-1 overflow-y-auto space-y-2 text-sm">
        <div class="flex justify-between">
          <span class="text-base-content/70">Subtotal</span>
          <span class="tabular-nums">{format_amount(product_total(@items))}</span>
        </div>

        <%= for item <- Enum.filter(@items, & &1.type in [:fee, :discount]) do %>
          <div class="flex justify-between">
            <span class="text-base-content/70">
              {item_name(item)}
            </span>
            <span class={["tabular-nums", item.type == :discount && "text-success"]}>
              {format_amount(item.line_total)}
            </span>
          </div>
        <% end %>

        <div class="flex justify-between">
          <span class="text-base-content/70">Tax ({format_percent(@tax_rate)})</span>
          <span class="tabular-nums">{format_amount(@tax)}</span>
        </div>

        <%= if has_tip?(@items) do %>
          <div class="flex justify-between">
            <span class="text-base-content/70">Tip</span>
            <span class="tabular-nums">{format_amount(tip_total(@items))}</span>
          </div>
        <% end %>

        <div class="divider my-2"></div>

        <div class="flex justify-between text-xl font-bold">
          <span>TOTAL</span>
          <span class="tabular-nums text-primary">{format_amount(@total)}</span>
        </div>
      </div>
      
    <!-- Action Buttons -->
      <div class="mt-4 space-y-3">
        <button
          type="button"
          class="btn btn-primary btn-lg w-full"
          phx-click={@on_charge}
          disabled={!@can_charge}
        >
          <.icon name="hero-credit-card" class="size-5" /> Charge Card {format_amount(@total)}
        </button>
        <p :if={!@can_charge} class="text-xs text-center text-base-content/50 -mt-1">
          Add items to charge
        </p>

        <div class="grid grid-cols-2 gap-3">
          <button
            type="button"
            class="btn btn-outline"
            phx-click={@on_send_link}
            disabled={!@can_send_link}
          >
            <.icon name="hero-link" class="size-4" />
            <span class="hidden sm:inline">Send Link</span>
          </button>

          <button
            type="button"
            class="btn btn-outline"
            phx-click={@on_email}
            disabled={!@can_email}
          >
            <.icon name="hero-envelope" class="size-4" />
            <span class="hidden sm:inline">Email</span>
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp item_name(item) do
    case item.type do
      :product -> item.name
      :fee -> item.name
      :discount -> item.name
      :tip -> "Tip"
    end
  end

  defp has_tip?(items) do
    Enum.any?(items, &(&1.type == :tip))
  end

  defp tip_total(items) do
    items
    |> Enum.filter(&(&1.type == :tip))
    |> Enum.reduce(Decimal.new("0"), &Decimal.add(&1.line_total, &2))
  end

  defp format_percent(rate) do
    rate
    |> Decimal.mult(100)
    |> Decimal.to_string(:normal)
    |> Kernel.<>("%")
  end

  defp product_total(items) do
    items
    |> Enum.filter(&(&1.type == :product))
    |> Enum.reduce(Decimal.new("0"), &Decimal.add(&1.line_total, &2))
  end

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
