defmodule McpWeb.Merchant.Payments.Transactions.ShowLive do
  @moduledoc """
  Transaction detail page for the merchant portal.

  Displays comprehensive transaction information including:
  - Transaction summary (amount, status, payment method, date)
  - Customer information with link to profile
  - Transaction timeline showing status changes
  - Refund actions and other transaction operations
  - AI-powered insights
  """
  use McpWeb, :live_view

  @impl true
  def mount(%{"id" => transaction_id}, _session, socket) do
    transaction = find_transaction(transaction_id)
    timeline_events = get_timeline_events(transaction_id)
    insights = get_ai_insights(transaction_id)
    available_actions = compute_available_actions(transaction)

    socket =
      socket
      |> assign(:page_title, transaction.reference)
      |> assign(:transaction, transaction)
      |> assign(:timeline_events, timeline_events)
      |> assign(:insights, insights)
      |> assign(:available_actions, available_actions)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout
      variant={:detail}
      title={@transaction.reference}
      back={~p"/app/payments/transactions"}
    >
      <:content>
        <%!-- Transaction Summary Card --%>
        <.card class="mb-6">
          <.header>Transaction Summary</.header>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-4">
            <%!-- Amount --%>
            <div>
              <p class="text-sm text-base-content/60 mb-1">Amount</p>
              <p class="text-3xl font-bold text-base-content">
                ${format_money(@transaction.amount)}
              </p>
            </div>

            <%!-- Status --%>
            <div>
              <p class="text-sm text-base-content/60 mb-1">Status</p>
              <.badge variant={status_variant(@transaction.status)} size="lg">
                {format_status(@transaction.status)}
              </.badge>
            </div>

            <%!-- Payment Method --%>
            <div>
              <p class="text-sm text-base-content/60 mb-1">Payment Method</p>
              <div class="flex items-center gap-2">
                <.icon name="hero-credit-card" class="size-5 text-base-content/60" />
                <span class="text-base-content">
                  {format_card_brand(@transaction.card_brand)} •••• {@transaction.card_last_four}
                </span>
              </div>
            </div>

            <%!-- Date --%>
            <div>
              <p class="text-sm text-base-content/60 mb-1">Date</p>
              <div class="flex items-center gap-2">
                <.icon name="hero-calendar" class="size-5 text-base-content/60" />
                <span class="text-base-content">{format_datetime(@transaction.created_at)}</span>
              </div>
            </div>
          </div>
        </.card>

        <%!-- Customer Info Card --%>
        <.card class="mb-6">
          <.header>Customer Information</.header>

          <div class="mt-4">
            <div class="flex items-center gap-3">
              <div class="avatar placeholder">
                <div class="bg-primary text-primary-content rounded-full w-12 h-12">
                  <span class="text-lg font-semibold">
                    {get_initials(@transaction.customer.name)}
                  </span>
                </div>
              </div>

              <div>
                <a
                  href={~p"/app/customers/#{@transaction.customer.id}"}
                  class="link link-hover text-base-content font-semibold"
                >
                  {@transaction.customer.name}
                </a>
                <p class="text-sm text-base-content/60">{@transaction.customer.email}</p>
              </div>
            </div>
          </div>
        </.card>

        <%!-- Transaction Timeline --%>
        <.card>
          <.header>Transaction Timeline</.header>

          <div class="mt-4">
            <ol class="relative border-l border-base-300 ml-3">
              <li :for={event <- @timeline_events} class="mb-8 ml-6">
                <span class={[
                  "absolute flex items-center justify-center w-8 h-8 rounded-full -left-4",
                  timeline_event_bg(event.type)
                ]}>
                  <.icon name={timeline_event_icon(event.type)} class="size-4 text-white" />
                </span>

                <h3 class="flex items-center gap-2 mb-1 text-base font-semibold text-base-content">
                  {format_event_type(event.type)}
                </h3>
                <time class="block mb-2 text-sm font-normal leading-none text-base-content/60">
                  {format_datetime(event.timestamp)}
                </time>
                <p class="text-base-content/80">{event.description}</p>
              </li>
            </ol>
          </div>
        </.card>
      </:content>

      <:sidebar>
        <.action_sidebar>
          <:actions>
            <.sidebar_action
              icon="hero-arrow-uturn-left"
              label="Refund (Full)"
              phx-click="refund_full"
              disabled={!@available_actions.can_refund}
            />
            <.sidebar_action
              icon="hero-calculator"
              label="Partial Refund"
              phx-click="refund_partial"
              disabled={!@available_actions.can_refund}
            />
            <.sidebar_action
              icon="hero-envelope"
              label="Send Receipt"
              phx-click="send_receipt"
            />
            <.sidebar_action
              icon="hero-arrow-top-right-on-square"
              label="View in Stripe"
              href="https://dashboard.stripe.com/test/payments"
            />
          </:actions>

          <:insights>
            <.ai_insight
              :for={insight <- @insights}
              message={insight.message}
              action={insight.action}
              phx-click={insight.event}
            />
          </:insights>
        </.action_sidebar>
      </:sidebar>
    </.page_layout>
    """
  end

  @impl true
  def handle_event("refund_full", _params, socket) do
    # Placeholder for full refund action
    {:noreply, socket}
  end

  @impl true
  def handle_event("refund_partial", _params, socket) do
    # Placeholder for partial refund action
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_receipt", _params, socket) do
    # Placeholder for send receipt action
    {:noreply, socket}
  end

  @impl true
  def handle_event("view_similar_transactions", _params, socket) do
    # Placeholder for AI insight action
    {:noreply, socket}
  end

  @impl true
  def handle_event("check_fraud_indicators", _params, socket) do
    # Placeholder for AI insight action
    {:noreply, socket}
  end

  # Private helper functions

  defp find_transaction(id) do
    # Mock data - replace with Ash resource query
    # Transaction.get!(id)
    case id do
      "txn_1" ->
        %{
          id: "txn_1",
          reference: "TXN-2026-0001",
          amount: Decimal.new("125.00"),
          status: :completed,
          payment_method: "card",
          card_last_four: "4242",
          card_brand: "visa",
          created_at: ~U[2026-01-10 14:30:00Z],
          customer: %{
            id: "cust_1",
            name: "John Doe",
            email: "john@example.com"
          }
        }

      "txn_2" ->
        %{
          id: "txn_2",
          reference: "TXN-2026-0002",
          amount: Decimal.new("89.50"),
          status: :refunded,
          payment_method: "card",
          card_last_four: "5555",
          card_brand: "mastercard",
          created_at: ~U[2026-01-08 16:45:00Z],
          customer: %{
            id: "cust_2",
            name: "Jane Smith",
            email: "jane@example.com"
          }
        }

      _ ->
        %{
          id: id,
          reference: "TXN-2026-0001",
          amount: Decimal.new("125.00"),
          status: :completed,
          payment_method: "card",
          card_last_four: "4242",
          card_brand: "visa",
          created_at: ~U[2026-01-10 14:30:00Z],
          customer: %{
            id: "cust_1",
            name: "John Doe",
            email: "john@example.com"
          }
        }
    end
  end

  defp get_timeline_events(transaction_id) do
    # Mock data - replace with timeline events query
    _ = transaction_id

    [
      %{
        id: "evt_1",
        type: :created,
        timestamp: ~U[2026-01-10 14:30:00Z],
        description: "Transaction created"
      },
      %{
        id: "evt_2",
        type: :authorized,
        timestamp: ~U[2026-01-10 14:30:15Z],
        description: "Payment authorized"
      },
      %{
        id: "evt_3",
        type: :captured,
        timestamp: ~U[2026-01-10 14:30:30Z],
        description: "Payment captured"
      },
      %{
        id: "evt_4",
        type: :completed,
        timestamp: ~U[2026-01-10 14:31:00Z],
        description: "Transaction completed"
      }
    ]
  end

  defp get_ai_insights(transaction_id) do
    # Mock data - replace with AI insights service
    _ = transaction_id

    [
      %{
        message: "Similar transactions detected from this customer",
        action: "View similar transactions",
        event: "view_similar_transactions"
      },
      %{
        message: "No fraud indicators detected for this transaction",
        action: "Check fraud indicators",
        event: "check_fraud_indicators"
      }
    ]
  end

  defp compute_available_actions(transaction) do
    %{
      can_refund: transaction.status == :completed,
      can_send_receipt: true,
      can_view_stripe: true
    }
  end

  defp get_initials(name) do
    name
    |> String.split()
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %I:%M %p")
  end

  defp format_money(%Decimal{} = amount) do
    amount
    |> Decimal.to_string(:normal)
    |> String.to_float()
    |> Mcp.NumberHelper.number_to_currency()
  end

  defp format_status(:completed), do: "Completed"
  defp format_status(:pending), do: "Pending"
  defp format_status(:failed), do: "Failed"
  defp format_status(:refunded), do: "Refunded"
  defp format_status(:authorized), do: "Authorized"
  defp format_status(:captured), do: "Captured"
  defp format_status(_), do: "Unknown"

  defp status_variant(:completed), do: "success"
  defp status_variant(:pending), do: "warning"
  defp status_variant(:failed), do: "error"
  defp status_variant(:refunded), do: "info"
  defp status_variant(:authorized), do: "info"
  defp status_variant(:captured), do: "success"
  defp status_variant(_), do: nil

  defp format_card_brand("visa"), do: "Visa"
  defp format_card_brand("mastercard"), do: "Mastercard"
  defp format_card_brand("amex"), do: "American Express"
  defp format_card_brand("discover"), do: "Discover"
  defp format_card_brand(_), do: "Card"

  defp format_event_type(:created), do: "Transaction Created"
  defp format_event_type(:authorized), do: "Payment Authorized"
  defp format_event_type(:captured), do: "Payment Captured"
  defp format_event_type(:completed), do: "Transaction Completed"
  defp format_event_type(:failed), do: "Transaction Failed"
  defp format_event_type(:refunded), do: "Transaction Refunded"
  defp format_event_type(_), do: "Event"

  defp timeline_event_icon(:created), do: "hero-plus-circle"
  defp timeline_event_icon(:authorized), do: "hero-shield-check"
  defp timeline_event_icon(:captured), do: "hero-banknotes"
  defp timeline_event_icon(:completed), do: "hero-check-circle"
  defp timeline_event_icon(:failed), do: "hero-x-circle"
  defp timeline_event_icon(:refunded), do: "hero-arrow-uturn-left"
  defp timeline_event_icon(_), do: "hero-information-circle"

  defp timeline_event_bg(:created), do: "bg-primary"
  defp timeline_event_bg(:authorized), do: "bg-info"
  defp timeline_event_bg(:captured), do: "bg-success"
  defp timeline_event_bg(:completed), do: "bg-success"
  defp timeline_event_bg(:failed), do: "bg-error"
  defp timeline_event_bg(:refunded), do: "bg-warning"
  defp timeline_event_bg(_), do: "bg-base-300"
end
