defmodule McpWeb.Components.Terminal.PaymentDrawer do
  @moduledoc """
  Payment drawer component for the Virtual Terminal.
  Bottom slide-up drawer with backdrop-blur per design contract lines 256-285.
  Two-column layout: order recap on left, card form on right.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  attr :show, :boolean, default: true
  attr :state, :map, required: true
  attr :card_number, :string, default: ""
  attr :expiry, :string, default: ""
  attr :cvv, :string, default: ""
  attr :zip, :string, default: ""
  attr :save_card, :boolean, default: false
  attr :processing, :boolean, default: false
  attr :result, :map, default: nil
  attr :on_close, :string, default: "close_payment"
  attr :on_card_change, :string, default: "card_field_change"
  attr :on_submit, :string, default: "process_payment"
  attr :on_new_transaction, :string, default: "new_transaction"
  attr :class, :string, default: nil

  def payment_drawer(assigns) do
    ~H"""
    <div
      :if={@show}
      class={["fixed inset-0 z-50", @class]}
      data-testid="payment-drawer"
    >
      <!-- BACKDROP WITH BLUR - PER DESIGN CONTRACT LINE 291 -->
      <div
        class="absolute inset-0 bg-base-300/50 backdrop-blur-sm"
        phx-click={@on_close}
      />
      
    <!-- BOTTOM DRAWER PANEL - PER DESIGN CONTRACT LINES 256-285 -->
      <div class="absolute bottom-0 left-0 right-0 bg-base-100 shadow-xl rounded-t-2xl max-h-[85vh] overflow-hidden">
        <!-- DRAWER HANDLE -->
        <div class="flex justify-center py-2">
          <div class="w-12 h-1 rounded-full bg-base-300" />
        </div>
        
    <!-- HEADER -->
        <div class="flex items-center justify-between px-6 pb-4 border-b border-base-300">
          <h2 class="text-xl font-bold">Complete Payment</h2>
          <button
            type="button"
            class="btn btn-ghost btn-sm btn-circle"
            phx-click={@on_close}
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>
        
    <!-- CONTENT BASED ON STATE -->
        <%= cond do %>
          <% @result != nil -> %>
            <.payment_result result={@result} state={@state} on_new_transaction={@on_new_transaction} />
          <% @processing -> %>
            <.processing_state state={@state} />
          <% true -> %>
            <.payment_form
              state={@state}
              card_number={@card_number}
              expiry={@expiry}
              cvv={@cvv}
              zip={@zip}
              save_card={@save_card}
              on_card_change={@on_card_change}
              on_submit={@on_submit}
            />
        <% end %>
      </div>
    </div>
    """
  end

  defp payment_form(assigns) do
    ~H"""
    <!-- TWO-COLUMN CONTENT - PER DESIGN CONTRACT -->
    <div class="grid grid-cols-2 divide-x divide-base-300 max-h-[calc(85vh-80px)] overflow-y-auto">
      <!-- LEFT: Order Recap -->
      <.order_recap state={@state} />
      
    <!-- RIGHT: Card Form -->
      <div class="p-6">
        <h4 class="font-semibold mb-4">Card Information</h4>

        <div class="form-control">
          <label class="label"><span class="label-text">Card Number</span></label>
          <label class="input input-bordered flex items-center gap-2">
            <.icon name="hero-credit-card" class="size-4 opacity-50" />
            <input
              type="text"
              placeholder="4242 4242 4242 4242"
              class="grow border-none focus:ring-0"
              value={@card_number}
              phx-keyup={@on_card_change}
              phx-value-field="card_number"
              inputmode="numeric"
              maxlength="19"
              autocomplete="cc-number"
            />
            <.card_brand_icon card_number={@card_number} />
          </label>
        </div>
        
    <!-- AI RISK WARNING (Contract Lines 296-301) -->
        <div
          :if={risky_card?(@card_number)}
          class="mt-4 p-3 bg-warning/10 border border-warning/30 rounded-lg text-sm"
        >
          <div class="flex items-start gap-2">
            <.icon name="hero-exclamation-triangle" class="size-4 text-warning mt-0.5 flex-shrink-0" />
            <div>
              <p class="font-medium text-warning-content">Card declined 2 times today</p>
              <p class="text-base-content/70 text-xs mt-0.5">
                Insufficient funds reported by issuer.
              </p>
              <div class="flex gap-2 mt-2">
                <button type="button" class="btn btn-xs btn-outline">Send Payment Link</button>
                <button type="button" class="btn btn-xs btn-outline">Try Different Card</button>
              </div>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-3 gap-4 mt-4">
          <div class="form-control">
            <label class="label"><span class="label-text">Expiry</span></label>
            <input
              type="text"
              placeholder="MM/YY"
              class="input input-bordered"
              value={@expiry}
              phx-keyup={@on_card_change}
              phx-value-field="expiry"
              inputmode="numeric"
              maxlength="5"
              autocomplete="cc-exp"
            />
          </div>
          <div class="form-control">
            <label class="label"><span class="label-text">CVC</span></label>
            <input
              type="text"
              placeholder="123"
              class="input input-bordered"
              value={@cvv}
              phx-keyup={@on_card_change}
              phx-value-field="cvv"
              inputmode="numeric"
              maxlength="4"
              autocomplete="cc-csc"
            />
          </div>
          <div class="form-control">
            <label class="label"><span class="label-text">ZIP</span></label>
            <input
              type="text"
              placeholder="12345"
              class="input input-bordered"
              value={@zip}
              phx-keyup={@on_card_change}
              phx-value-field="zip"
              inputmode="numeric"
              maxlength="5"
              autocomplete="postal-code"
            />
          </div>
        </div>

        <div class="form-control mt-4">
          <label class="label cursor-pointer justify-start gap-3">
            <input
              type="checkbox"
              class="checkbox checkbox-primary"
              checked={@save_card}
              phx-click="toggle_save_card"
            />
            <span class="label-text">
              Save card for {(@state.customer && @state.customer.name) || "future"}
            </span>
          </label>
        </div>

        <button
          type="button"
          class="btn btn-primary btn-lg w-full mt-6"
          phx-click={@on_submit}
          disabled={!card_valid?(@card_number, @expiry, @cvv)}
        >
          <.icon name="hero-lock-closed" class="size-5" /> Pay {format_amount(@state.total)}
        </button>
      </div>
    </div>
    """
  end

  defp processing_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-12 max-h-[85vh]">
      <div class="loading loading-spinner loading-lg text-primary mb-4"></div>
      <h3 class="text-xl font-semibold mb-2">Processing Payment</h3>
      <p class="text-base-content/70">{format_amount(@state.total)}</p>
    </div>
    """
  end

  defp payment_result(assigns) do
    ~H"""
    <!-- TWO-COLUMN RESULT - PER DESIGN CONTRACT LINE 306 -->
    <div class="grid grid-cols-2 divide-x divide-base-300 max-h-[calc(85vh-80px)] overflow-y-auto">
      <!-- LEFT: Order Recap (Preserved) -->
      <.order_recap state={@state} />
      
    <!-- RIGHT: Success & Insight -->
      <div class="p-6">
        <div class="flex flex-col items-center justify-center text-center py-4">
          <div class={[
            "inline-flex items-center justify-center w-16 h-16 rounded-full mb-4",
            if(@result.status == :approved, do: "bg-success/20", else: "bg-error/20")
          ]}>
            <.icon
              name={if @result.status == :approved, do: "hero-check", else: "hero-x-mark"}
              class={"size-8 #{if @result.status == :approved, do: "text-success", else: "text-error"}"}
            />
          </div>

          <h3 class={[
            "text-2xl font-bold mb-1",
            if(@result.status == :approved, do: "text-success", else: "text-error")
          ]}>
            {if @result.status == :approved, do: "Approved", else: "Declined"}
          </h3>
          <p class="text-xl font-medium mb-4">{format_amount(@state.total)}</p>

          <p class="text-base-content/60">Visa •••• 4242</p>
          <p class="text-sm text-base-content/50 mt-1">
            TXN-{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d-%H%M")}
          </p>
          
    <!-- AI POST-TRANSACTION INSIGHT (Contract Lines 338-344) -->
          <%= if @result.status == :approved and @state.customer do %>
            <div class="mt-6 w-full text-left">
              <div class="p-3 bg-info/5 border border-info/20 rounded-lg">
                <div class="flex items-start gap-2">
                  <.icon name="hero-light-bulb" class="size-4 text-info mt-0.5 flex-shrink-0" />
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium">
                      {@state.customer.name}'s 24th order · Now in top 5%
                    </p>
                    <div class="flex gap-2 mt-2">
                      <button type="button" class="btn btn-xs btn-outline bg-base-100">
                        Send Thank You Email
                      </button>
                      <button type="button" class="btn btn-xs btn-outline bg-base-100">
                        Add 50 Loyalty Points
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% end %>

          <div class="space-y-3 w-full max-w-xs mt-8">
            <button class="btn btn-outline w-full gap-2">
              <.icon name="hero-envelope" class="size-4" /> Email Receipt
            </button>
            <button class="btn btn-outline w-full gap-2">
              <.icon name="hero-printer" class="size-4" /> Print Receipt
            </button>
            <button class="btn btn-primary w-full gap-2" phx-click={@on_new_transaction}>
              <.icon name="hero-plus" class="size-4" /> New Transaction
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp order_recap(assigns) do
    ~H"""
    <div class="p-6">
      <div :if={@state.customer} class="flex items-center gap-3 p-3 bg-base-200 rounded-lg mb-4">
        <div class="avatar placeholder">
          <div class="bg-primary text-primary-content rounded-full w-10">
            <span>{initials(@state.customer.name)}</span>
          </div>
        </div>
        <div>
          <p class="font-medium">{@state.customer.name}</p>
          <p :if={@state.customer[:email]} class="text-sm text-base-content/70">
            {@state.customer.email}
          </p>
        </div>
      </div>

      <div class="space-y-2">
        <div
          :for={item <- @state.line_items}
          class="flex items-center gap-3 py-2 border-b border-base-300 last:border-0"
        >
          <div class="w-10 h-10 bg-base-200 rounded flex items-center justify-center text-sm">
            {item_icon(item.type)}
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex justify-between">
              <span class="font-medium truncate">{item.name}</span>
              <span class={["tabular-nums", item.type == :discount && "text-success"]}>
                {format_amount(item.line_total)}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div class="pt-4 space-y-2 border-t border-base-300">
        <div class="flex justify-between text-sm">
          <span class="text-base-content/70">Subtotal</span>
          <span class="tabular-nums">{format_amount(@state.subtotal)}</span>
        </div>
        <div class="flex justify-between text-sm">
          <span class="text-base-content/70">Tax</span>
          <span class="tabular-nums">{format_amount(@state.tax)}</span>
        </div>
        <div class="flex justify-between text-lg font-bold pt-2 border-t border-base-300">
          <span>Total</span>
          <span class="tabular-nums">{format_amount(@state.total)}</span>
        </div>
      </div>
    </div>
    """
  end

  defp card_brand_icon(assigns) do
    brand = detect_card_brand(assigns.card_number)
    assigns = assign(assigns, :brand, brand)

    ~H"""
    <span :if={@brand} class="text-lg">
      <%= case @brand do %>
        <% :visa -> %>
          <span class="text-primary font-bold text-sm">VISA</span>
        <% :mastercard -> %>
          <span class="text-accent font-bold text-sm">MC</span>
        <% :amex -> %>
          <span class="text-primary font-bold text-sm">AMEX</span>
        <% :discover -> %>
          <span class="text-accent font-bold text-sm">DISC</span>
        <% _ -> %>
          <span></span>
      <% end %>
    </span>
    """
  end

  defp item_icon(:product), do: "📦"
  defp item_icon(:fee), do: "🚚"
  defp item_icon(:discount), do: "🏷️"
  defp item_icon(:tip), do: "💰"

  defp detect_card_brand(number) when is_binary(number) do
    clean = String.replace(number, ~r/\s/, "")

    cond do
      String.starts_with?(clean, "4") -> :visa
      String.starts_with?(clean, ["51", "52", "53", "54", "55"]) -> :mastercard
      String.starts_with?(clean, ["34", "37"]) -> :amex
      String.starts_with?(clean, "6011") -> :discover
      true -> nil
    end
  end

  defp detect_card_brand(_), do: nil

  defp card_valid?(card_number, expiry, cvv) do
    clean_card = String.replace(card_number, ~r/\s/, "")
    String.length(clean_card) >= 13 and String.length(expiry) == 5 and String.length(cvv) >= 3
  end

  defp initials(nil), do: "?"

  defp initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
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

  defp risky_card?(number), do: String.ends_with?(number || "", "0000")
end
