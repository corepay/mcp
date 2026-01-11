defmodule McpWeb.Components.Terminal.AmountEntry do
  @moduledoc """
  Terminal amount entry component with numeric keypad.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents

  @doc """
  Renders an amount entry screen with numeric keypad.

  ## Examples

      <.amount_entry amount={Decimal.new("0.00")} />
  """
  attr :amount, :any, required: true, doc: "Current amount as Decimal"
  attr :class, :string, default: nil

  def amount_entry(assigns) do
    ~H"""
    <div class={["flex flex-col h-full bg-base-100", @class]}>
      <!-- Amount Display -->
      <div class="flex-1 flex items-center justify-center p-8">
        <div
          data-testid="amount-display"
          class="text-6xl font-bold text-primary tabular-nums"
        >
          ${format_amount(@amount)}
        </div>
      </div>
      
    <!-- Keypad Section -->
      <div class="p-6 bg-base-200">
        <div data-testid="keypad" class="grid grid-cols-3 gap-4 mb-4">
          <!-- Row 1: 1, 2, 3 -->
          <button
            phx-click="digit"
            phx-value-digit="1"
            class="btn btn-lg btn-outline text-2xl h-20"
          >
            1
          </button>
          <button
            phx-click="digit"
            phx-value-digit="2"
            class="btn btn-lg btn-outline text-2xl h-20"
          >
            2
          </button>
          <button
            phx-click="digit"
            phx-value-digit="3"
            class="btn btn-lg btn-outline text-2xl h-20"
          >
            3
          </button>
          
    <!-- Row 2: 4, 5, 6 -->
          <button
            phx-click="digit"
            phx-value-digit="4"
            class="btn btn-lg btn-outline text-2xl h-20"
          >
            4
          </button>
          <button
            phx-click="digit"
            phx-value-digit="5"
            class="btn btn-lg btn-outline text-2xl h-20"
          >
            5
          </button>
          <button
            phx-click="digit"
            phx-value-digit="6"
            class="btn btn-lg btn-outline text-2xl h-20"
          >
            6
          </button>
          
    <!-- Row 3: 7, 8, 9 -->
          <button
            phx-click="digit"
            phx-value-digit="7"
            class="btn btn-lg btn-outline text-2xl h-20"
          >
            7
          </button>
          <button
            phx-click="digit"
            phx-value-digit="8"
            class="btn btn-lg btn-outline text-2xl h-20"
          >
            8
          </button>
          <button
            phx-click="digit"
            phx-value-digit="9"
            class="btn btn-lg btn-outline text-2xl h-20"
          >
            9
          </button>
          
    <!-- Row 4: 00, 0, backspace -->
          <button
            phx-click="digit"
            phx-value-digit="00"
            class="btn btn-lg btn-outline text-2xl h-20"
          >
            00
          </button>
          <button
            phx-click="digit"
            phx-value-digit="0"
            class="btn btn-lg btn-outline text-2xl h-20"
          >
            0
          </button>
          <button phx-click="backspace" class="btn btn-lg btn-outline h-20">
            <.icon name="hero-backspace" class="h-8 w-8" />
          </button>
        </div>
        
    <!-- Clear and Continue buttons -->
        <div class="grid grid-cols-2 gap-4">
          <button phx-click="clear_amount" class="btn btn-lg btn-outline">
            Clear
          </button>
          <button
            phx-click="continue_to_card"
            data-testid="continue-btn"
            class={[
              "btn btn-lg btn-primary",
              zero?(@amount) && "btn-disabled"
            ]}
            disabled={zero?(@amount)}
          >
            Continue
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp format_amount(amount) do
    amount
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
  end

  defp zero?(amount) do
    Decimal.eq?(amount, Decimal.new("0"))
  end
end
