defmodule McpWeb.Components.Terminal.Receipt do
  @moduledoc """
  Terminal receipt component showing transaction results.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents

  @doc """
  Renders a transaction receipt.

  ## Examples

      <.receipt
        status={:success}
        amount={Decimal.new("50.00")}
        last_four="1111"
        transaction_id="txn_123"
      />
  """
  attr :status, :atom, required: true, doc: "Transaction status (:success or :failed)"
  attr :amount, :any, required: true, doc: "Transaction amount as Decimal"
  attr :last_four, :string, required: true, doc: "Last 4 digits of card"
  attr :transaction_id, :string, required: true, doc: "Transaction ID"
  attr :class, :string, default: nil

  def receipt(assigns) do
    ~H"""
    <div class={["flex flex-col h-full bg-base-100 p-6", @class]}>
      <!-- Status Icon and Message -->
      <div class="flex-1 flex flex-col items-center justify-center gap-6">
        <div :if={@status == :success} class="text-success">
          <.icon name="hero-check-circle" class="h-24 w-24" />
        </div>
        <div :if={@status == :failed} class="text-error">
          <.icon name="hero-x-circle" class="h-24 w-24" />
        </div>

        <h2 class="text-3xl font-bold">
          {if @status == :success, do: "Payment Successful", else: "Payment Failed"}
        </h2>
        
    <!-- Transaction Details Card -->
        <div class="card bg-base-200 w-full max-w-md">
          <div class="card-body">
            <div class="space-y-4">
              <!-- Amount -->
              <div class="flex justify-between items-center">
                <span class="text-base-content/70">Amount</span>
                <span class="text-2xl font-bold tabular-nums">
                  ${format_amount(@amount)}
                </span>
              </div>

              <div class="divider my-2"></div>
              
    <!-- Card -->
              <div class="flex justify-between items-center">
                <span class="text-base-content/70">Card</span>
                <span class="font-mono">•••• {[@last_four]}</span>
              </div>

              <div class="divider my-2"></div>
              
    <!-- Transaction ID -->
              <div class="flex justify-between items-center">
                <span class="text-base-content/70">Transaction ID</span>
                <span class="font-mono text-sm">{[@transaction_id]}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Action Buttons -->
      <div class="grid grid-cols-2 gap-4 mt-8">
        <button phx-click="print_receipt" class="btn btn-lg btn-outline">
          <.icon name="hero-printer" class="h-5 w-5" /> Print Receipt
        </button>
        <button
          phx-click="new_transaction"
          data-testid="new-transaction-btn"
          class="btn btn-lg btn-primary"
        >
          <.icon name="hero-plus" class="h-5 w-5" /> New Transaction
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
end
