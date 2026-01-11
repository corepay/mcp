defmodule McpWeb.Components.Terminal.CardEntry do
  @moduledoc """
  Terminal card entry component for payment processing.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents

  @doc """
  Renders a card entry form for payment processing.

  ## Examples

      <.card_entry
        card_number=""
        expiry=""
        cvv=""
        amount={Decimal.new("50.00")}
      />
  """
  attr :card_number, :string, required: true
  attr :expiry, :string, required: true
  attr :cvv, :string, required: true
  attr :amount, :any, required: true, doc: "Amount to charge as Decimal"
  attr :class, :string, default: nil

  def card_entry(assigns) do
    ~H"""
    <div class={["flex flex-col h-full bg-base-100 p-6", @class]}>
      <!-- Amount Display -->
      <div class="mb-8 text-center">
        <div class="text-sm text-base-content/70 mb-2">Amount to Charge</div>
        <div class="text-5xl font-bold text-primary tabular-nums">
          ${format_amount(@amount)}
        </div>
      </div>
      
    <!-- Card Entry Form -->
      <div class="flex-1 flex flex-col gap-6 max-w-md mx-auto w-full">
        <!-- Card Number -->
        <div class="form-control">
          <label class="label">
            <span class="label-text">Card Number</span>
          </label>
          <input
            type="text"
            placeholder="1234 5678 9012 3456"
            maxlength="19"
            value={@card_number}
            phx-change="update_card_number"
            data-testid="card-number-input"
            class="input input-lg input-bordered"
          />
        </div>
        
    <!-- Expiry and CVV Row -->
        <div class="grid grid-cols-2 gap-4">
          <div class="form-control">
            <label class="label">
              <span class="label-text">Expiry</span>
            </label>
            <input
              type="text"
              placeholder="MM/YY"
              maxlength="5"
              value={@expiry}
              phx-change="update_expiry"
              data-testid="expiry-input"
              class="input input-lg input-bordered"
            />
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text">CVV</span>
            </label>
            <input
              type="text"
              placeholder="123"
              maxlength="4"
              value={@cvv}
              phx-change="update_cvv"
              data-testid="cvv-input"
              class="input input-lg input-bordered"
            />
          </div>
        </div>
      </div>
      
    <!-- Action Buttons -->
      <div class="grid grid-cols-2 gap-4 mt-8">
        <button phx-click="back_to_amount" class="btn btn-lg btn-outline">
          <.icon name="hero-arrow-left" class="h-5 w-5" /> Back
        </button>
        <button
          phx-click="charge_card"
          data-testid="charge-btn"
          class={[
            "btn btn-lg btn-primary",
            !card_valid?(@card_number, @expiry, @cvv) && "btn-disabled"
          ]}
          disabled={!card_valid?(@card_number, @expiry, @cvv)}
        >
          Charge ${format_amount(@amount)}
        </button>
      </div>
    </div>
    """
  end

  defp format_amount(amount) do
    amount
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
  end

  defp card_valid?(card_number, expiry, cvv) do
    String.length(card_number) >= 13 and
      String.length(expiry) == 5 and
      String.length(cvv) >= 3
  end
end
