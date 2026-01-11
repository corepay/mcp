defmodule McpWeb.Components.Pos.PaymentModal do
  @moduledoc """
  POS Payment Modal Component

  A full-screen payment processing modal for point-of-sale transactions.
  Provides payment method selection, tip options, and loyalty point redemption.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  @doc """
  Renders a payment modal for POS transactions.

  ## Examples

      <.payment_modal
        total={Decimal.new("58.44")}
        customer={%{name: "John Smith", loyalty_points: 580, loyalty_value: Decimal.new("58.00")}}
        show={true}
        selected_tip={:fifteen}
      />
  """
  attr :total, :any, required: true, doc: "Total amount due as a Decimal"
  attr :customer, :map, default: nil, doc: "Customer map with loyalty_points and loyalty_value"
  attr :show, :boolean, default: false, doc: "Whether to show the modal"

  attr :selected_tip, :atom,
    default: nil,
    doc: "Selected tip option (:none, :fifteen, :eighteen, :twenty, :custom)"

  def payment_modal(assigns) do
    ~H"""
    <%= if @show do %>
      <div class="modal modal-open" data-testid="payment-modal">
        <div class="modal-box max-w-4xl w-full h-screen max-h-screen p-0 rounded-none">
          <!-- Header -->
          <div class="flex items-center justify-between px-6 py-4 border-b border-base-300 bg-base-100">
            <button
              type="button"
              phx-click="cancel_payment"
              class="btn btn-ghost btn-sm gap-2"
              data-testid="back-button"
            >
              <.icon name="hero-arrow-left" class="size-5" />
              <span>Back</span>
            </button>
            <h2 class="text-xl font-bold">PAYMENT</h2>
            <div class="w-24"></div>
          </div>
          
    <!-- Content -->
          <div class="p-6 space-y-6 overflow-y-auto" style="max-height: calc(100vh - 80px);">
            <!-- Total Due -->
            <div class="text-center py-6 bg-base-200 rounded-lg" data-testid="total-due">
              <div class="text-sm text-base-content/70 font-medium mb-2">Total Due:</div>
              <div class="text-5xl font-bold text-primary">
                ${format_decimal(@total)}
              </div>
            </div>
            
    <!-- Payment Methods Grid -->
            <div>
              <h3 class="text-lg font-semibold mb-4">Payment Method</h3>
              <div class="grid grid-cols-3 gap-4">
                <.payment_method_button
                  icon="hero-credit-card"
                  label="CARD READER"
                  sublabel="Tap or Insert"
                  event="pay_card_reader"
                />
                <.payment_method_button
                  icon="hero-banknotes"
                  label="CASH"
                  sublabel="Quick Cash"
                  event="pay_cash"
                />
                <.payment_method_button
                  icon="hero-scissors"
                  label="SPLIT"
                  sublabel="Multiple Payments"
                  event="pay_split"
                />
                <.payment_method_button
                  icon="hero-command-line"
                  label="MANUAL ENTRY"
                  sublabel="Key in Card"
                  event="pay_manual"
                />
                <.payment_method_button
                  icon="hero-device-phone-mobile"
                  label="PAYMENT LINK"
                  sublabel="Send to Customer"
                  event="pay_link"
                />
                <.payment_method_button
                  icon="hero-gift"
                  label="OTHER"
                  sublabel="Alternative Methods"
                  event="pay_other"
                />
              </div>
            </div>
            
    <!-- Loyalty Section (conditional) -->
            <%= if @customer && Map.get(@customer, :loyalty_points, 0) > 0 do %>
              <div class="border border-base-300 rounded-lg p-4" data-testid="loyalty-section">
                <h3 class="text-lg font-semibold mb-3">LOYALTY</h3>
                <div class="flex items-center justify-between">
                  <div>
                    <div class="text-sm text-base-content/70">
                      {Map.get(@customer, :loyalty_points, 0)} points available
                    </div>
                    <div class="text-lg font-semibold text-success">
                      ${format_decimal(Map.get(@customer, :loyalty_value, Decimal.new("0")))} value
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="apply_loyalty_points"
                    class="btn btn-outline btn-success"
                    data-testid="apply-points-button"
                  >
                    Apply points
                  </button>
                </div>
              </div>
            <% end %>
            
    <!-- Tip Section -->
            <div data-testid="tip-section">
              <h3 class="text-lg font-semibold mb-4">TIP</h3>
              <div class="grid grid-cols-5 gap-3">
                <button
                  type="button"
                  phx-click="select_tip"
                  phx-value-tip="none"
                  class={[
                    "btn",
                    if(@selected_tip == :none, do: "btn-primary", else: "btn-outline")
                  ]}
                  data-testid="tip-none"
                >
                  No Tip
                </button>
                <button
                  type="button"
                  phx-click="select_tip"
                  phx-value-tip="fifteen"
                  class={[
                    "btn",
                    if(@selected_tip == :fifteen, do: "btn-primary", else: "btn-outline")
                  ]}
                  data-testid="tip-fifteen"
                >
                  15%
                </button>
                <button
                  type="button"
                  phx-click="select_tip"
                  phx-value-tip="eighteen"
                  class={[
                    "btn",
                    if(@selected_tip == :eighteen, do: "btn-primary", else: "btn-outline")
                  ]}
                  data-testid="tip-eighteen"
                >
                  18%
                </button>
                <button
                  type="button"
                  phx-click="select_tip"
                  phx-value-tip="twenty"
                  class={[
                    "btn",
                    if(@selected_tip == :twenty, do: "btn-primary", else: "btn-outline")
                  ]}
                  data-testid="tip-twenty"
                >
                  20%
                </button>
                <button
                  type="button"
                  phx-click="select_tip"
                  phx-value-tip="custom"
                  class={[
                    "btn",
                    if(@selected_tip == :custom, do: "btn-primary", else: "btn-outline")
                  ]}
                  data-testid="tip-custom"
                >
                  Custom
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # Private component for payment method buttons
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :sublabel, :string, required: true
  attr :event, :string, required: true

  defp payment_method_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@event}
      class="btn btn-outline h-auto flex-col gap-2 py-4 bg-base-200 hover:bg-base-300"
      data-testid={"payment-method-#{@event}"}
    >
      <.icon name={@icon} class="size-8" />
      <div class="text-center">
        <div class="font-bold text-sm">{@label}</div>
        <div class="text-xs text-base-content/70">{@sublabel}</div>
      </div>
    </button>
    """
  end

  # Helper function to format Decimal as currency string
  defp format_decimal(%Decimal{} = decimal) do
    decimal
    |> Decimal.round(2)
    |> Decimal.to_string()
  end

  defp format_decimal(value) when is_binary(value) do
    value
    |> Decimal.new()
    |> format_decimal()
  end

  defp format_decimal(_), do: "0.00"
end
