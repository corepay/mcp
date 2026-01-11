defmodule McpWeb.Store.TerminalLive do
  @moduledoc """
  Virtual Terminal LiveView for processing card-present and card-not-present transactions.

  Provides a focused, step-by-step interface for entering payment amounts, card details,
  processing transactions, and displaying receipts.

  ## Steps
  1. Amount entry - Keypad-based amount input
  2. Card details - Card number, expiry, CVV entry
  3. Processing - Transaction processing with loading state
  4. Receipt - Transaction result and receipt display
  """
  use McpWeb, :live_view
  import McpWeb.Portal.FocusedLayout

  @impl Phoenix.LiveView
  def mount(%{"store_slug" => store_slug}, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Virtual Terminal")
      |> assign(:store_slug, store_slug)
      |> assign(:current_step, :amount)
      |> assign(:amount, Decimal.new("0.00"))
      |> assign(:amount_string, "")
      |> assign(:card_number, "")
      |> assign(:expiry, "")
      |> assign(:cvv, "")
      |> assign(:transaction_id, nil)
      |> assign(:last_four, nil)
      |> assign(:status, nil)

    {:ok, socket, layout: {McpWeb.Layouts, :focused}}
  end

  @impl Phoenix.LiveView
  def handle_event("keypad_press", %{"value" => value}, socket) do
    # Append digit to amount_string
    new_amount_string = socket.assigns.amount_string <> value
    # Limit to reasonable length (e.g., 10 digits = $999,999.99)
    new_amount_string = String.slice(new_amount_string, 0, 10)
    amount = parse_amount(new_amount_string)

    {:noreply, assign(socket, amount_string: new_amount_string, amount: amount)}
  end

  def handle_event("clear_amount", _params, socket) do
    {:noreply, assign(socket, amount_string: "", amount: Decimal.new("0.00"))}
  end

  def handle_event("backspace", _params, socket) do
    amount_string = socket.assigns.amount_string
    new_amount_string = String.slice(amount_string, 0..-2//1)
    amount = parse_amount(new_amount_string)

    {:noreply, assign(socket, amount_string: new_amount_string, amount: amount)}
  end

  def handle_event("continue_to_card", _params, socket) do
    {:noreply, assign(socket, current_step: :card)}
  end

  def handle_event("card_field_change", %{"field" => field, "value" => value}, socket) do
    case field do
      "card_number" -> {:noreply, assign(socket, card_number: value)}
      "expiry" -> {:noreply, assign(socket, expiry: value)}
      "cvv" -> {:noreply, assign(socket, cvv: value)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("charge_card", _params, socket) do
    # Move to processing step
    socket = assign(socket, current_step: :processing)

    # Simulate async payment processing
    Process.send_after(self(), :process_payment, 2000)

    {:noreply, socket}
  end

  def handle_event("new_transaction", _params, socket) do
    socket =
      socket
      |> assign(:current_step, :amount)
      |> assign(:amount, Decimal.new("0.00"))
      |> assign(:amount_string, "")
      |> assign(:card_number, "")
      |> assign(:expiry, "")
      |> assign(:cvv, "")
      |> assign(:transaction_id, nil)
      |> assign(:last_four, nil)
      |> assign(:status, nil)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(:process_payment, socket) do
    # Simulate successful payment
    transaction_id = "TXN#{:rand.uniform(999_999)}"
    last_four = String.slice(socket.assigns.card_number, -4..-1//1)

    socket =
      socket
      |> assign(:current_step, :receipt)
      |> assign(:transaction_id, transaction_id)
      |> assign(:last_four, last_four)
      |> assign(:status, :approved)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.focused_layout
      title="Virtual Terminal"
      exit={~p"/app/stores/#{@store_slug}/dashboard"}
      variant={:centered}
    >
      <:progress>
        <.step_indicator current_step={@current_step} />
      </:progress>

      <:content>
        <div class="terminal-container">
          <%= case @current_step do %>
            <% :amount -> %>
              <.amount_entry
                amount={@amount}
                amount_string={@amount_string}
              />
            <% :card -> %>
              <.card_entry
                card_number={@card_number}
                expiry={@expiry}
                cvv={@cvv}
                amount={@amount}
              />
            <% :processing -> %>
              <.processing_step />
            <% :receipt -> %>
              <.receipt
                transaction_id={@transaction_id}
                last_four={@last_four}
                amount={@amount}
                status={@status}
              />
          <% end %>
        </div>
      </:content>
    </.focused_layout>
    """
  end

  # Step indicator component
  defp step_indicator(assigns) do
    ~H"""
    <div class="steps w-full">
      <div class={["step", step_class(@current_step, :amount)]}>Amount</div>
      <div class={["step", step_class(@current_step, :card)]}>Card Details</div>
      <div class={["step", step_class(@current_step, :processing)]}>Processing</div>
      <div class={["step", step_class(@current_step, :receipt)]}>Receipt</div>
    </div>
    """
  end

  defp step_class(current, target) do
    step_order = %{amount: 1, card: 2, processing: 3, receipt: 4}

    cond do
      current == target -> "step-primary"
      step_order[current] > step_order[target] -> "step-primary"
      true -> ""
    end
  end

  # Amount entry component
  defp amount_entry(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-xl p-8">
      <h2 class="text-2xl font-bold text-center mb-6">Enter Amount</h2>

      <div class="mb-8">
        <div class="text-center mb-2 text-sm text-base-content/70">Amount to charge</div>
        <div
          class="text-5xl font-bold text-center text-primary mb-8"
          data-testid="amount-display"
        >
          {format_amount(@amount)}
        </div>
      </div>

      <.keypad />

      <div class="flex gap-4 mt-6">
        <button
          phx-click="clear_amount"
          class="btn btn-outline btn-error flex-1"
        >
          Clear
        </button>
        <button
          phx-click="continue_to_card"
          class="btn btn-primary flex-1"
          disabled={Decimal.eq?(@amount, Decimal.new("0.00"))}
        >
          Continue
        </button>
      </div>
    </div>
    """
  end

  # Keypad component
  defp keypad(assigns) do
    ~H"""
    <div class="grid grid-cols-3 gap-3" data-testid="keypad">
      <%= for digit <- ["1", "2", "3", "4", "5", "6", "7", "8", "9"] do %>
        <button
          phx-click="keypad_press"
          phx-value-value={digit}
          class="btn btn-lg btn-outline"
        >
          {digit}
        </button>
      <% end %>
      <button
        phx-click="keypad_press"
        phx-value-value="00"
        class="btn btn-lg btn-outline"
      >
        00
      </button>
      <button
        phx-click="keypad_press"
        phx-value-value="0"
        class="btn btn-lg btn-outline"
      >
        0
      </button>
      <button
        phx-click="backspace"
        class="btn btn-lg btn-outline"
      >
        ⌫
      </button>
    </div>
    """
  end

  # Card entry component
  defp card_entry(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-xl p-8">
      <h2 class="text-2xl font-bold text-center mb-6">Card Details</h2>

      <div class="mb-6 text-center">
        <div class="text-sm text-base-content/70">Amount</div>
        <div class="text-3xl font-bold text-primary">{format_amount(@amount)}</div>
      </div>

      <div class="space-y-4 mb-6">
        <div class="form-control">
          <label class="label">
            <span class="label-text">Card Number</span>
          </label>
          <input
            type="text"
            placeholder="1234 5678 9012 3456"
            class="input input-bordered"
            value={@card_number}
            phx-change="card_field_change"
            phx-value-field="card_number"
            maxlength="19"
          />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div class="form-control">
            <label class="label">
              <span class="label-text">Expiry</span>
            </label>
            <input
              type="text"
              placeholder="MM/YY"
              class="input input-bordered"
              value={@expiry}
              phx-change="card_field_change"
              phx-value-field="expiry"
              maxlength="5"
            />
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text">CVV</span>
            </label>
            <input
              type="text"
              placeholder="123"
              class="input input-bordered"
              value={@cvv}
              phx-change="card_field_change"
              phx-value-field="cvv"
              maxlength="4"
            />
          </div>
        </div>
      </div>

      <div class="flex gap-4">
        <button
          phx-click="new_transaction"
          class="btn btn-outline flex-1"
        >
          Cancel
        </button>
        <button
          phx-click="charge_card"
          class="btn btn-primary flex-1"
          disabled={@card_number == "" or @expiry == "" or @cvv == ""}
        >
          Charge Card
        </button>
      </div>
    </div>
    """
  end

  # Processing step component
  defp processing_step(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-xl p-8">
      <div class="text-center">
        <div class="loading loading-spinner loading-lg text-primary mb-4"></div>
        <h2 class="text-2xl font-bold mb-2">Processing Payment</h2>
        <p class="text-base-content/70">Please wait...</p>
      </div>
    </div>
    """
  end

  # Receipt component
  defp receipt(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-xl p-8">
      <div class="text-center mb-6">
        <div class={[
          "inline-block p-4 rounded-full mb-4",
          if(@status == :approved, do: "bg-success/20", else: "bg-error/20")
        ]}>
          <.icon
            name={if @status == :approved, do: "hero-check-circle", else: "hero-x-circle"}
            class={"size-16 " <> if(@status == :approved, do: "text-success", else: "text-error")}
          />
        </div>
        <h2 class="text-2xl font-bold mb-2">
          {if @status == :approved, do: "Payment Approved", else: "Payment Declined"}
        </h2>
      </div>

      <div class="divider"></div>

      <div class="space-y-3 mb-6">
        <div class="flex justify-between">
          <span class="text-base-content/70">Transaction ID</span>
          <span class="font-mono font-semibold">{@transaction_id}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-base-content/70">Card</span>
          <span class="font-mono">•••• {@last_four}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-base-content/70">Amount</span>
          <span class="text-xl font-bold text-primary">{format_amount(@amount)}</span>
        </div>
      </div>

      <div class="divider"></div>

      <button
        phx-click="new_transaction"
        class="btn btn-primary btn-block"
      >
        New Transaction
      </button>
    </div>
    """
  end

  # Helper function to parse amount string to Decimal
  # Amount is stored as cents, so "1234" becomes 12.34
  defp parse_amount(""), do: Decimal.new("0.00")

  defp parse_amount(amount_string) do
    case Integer.parse(amount_string) do
      {cents, _} ->
        cents
        |> Decimal.new()
        |> Decimal.div(100)

      :error ->
        Decimal.new("0.00")
    end
  end

  # Helper function to format Decimal amount as currency
  defp format_amount(amount) do
    amount
    |> Decimal.to_string(:normal)
    |> String.split(".")
    |> case do
      [dollars] -> "$#{dollars}.00"
      [dollars, cents] -> "$#{dollars}.#{String.pad_trailing(cents, 2, "0")}"
    end
  end
end
