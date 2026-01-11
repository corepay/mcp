defmodule McpWeb.Merchant.Customers.ShowLive do
  @moduledoc """
  Customer detail page for the merchant portal.

  Displays comprehensive customer information including:
  - Customer profile (avatar, name, email, phone)
  - Loyalty tier and points
  - Transaction history
  - AI-powered insights and recommendations
  """
  use McpWeb, :live_view

  import McpWeb.Portal.PageLayout, only: [page_layout: 1]
  import McpWeb.Portal.DataTable, only: [data_table: 1]

  import McpWeb.Portal.ActionSidebar,
    only: [action_sidebar: 1, sidebar_action: 1, ai_insight: 1]

  import McpWeb.Core.CoreComponents, only: [icon: 1, card: 1, header: 1]
  import McpWeb.Core.DataDisplay, only: [badge: 1]

  @impl true
  def mount(%{"id" => customer_id}, _session, socket) do
    customer = find_customer(customer_id)
    transactions = get_customer_transactions(customer_id)
    insights = get_ai_insights(customer_id)

    socket =
      socket
      |> assign(:page_title, customer.name)
      |> assign(:customer, customer)
      |> assign(:transactions, transactions)
      |> assign(:insights, insights)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout variant={:detail} title={@customer.name} back={~p"/app/customers"}>
      <:content>
        <%!-- Customer Profile Card --%>
        <.card class="mb-6">
          <div class="flex items-start gap-6">
            <%!-- Avatar --%>
            <div class="avatar placeholder">
              <div class="bg-primary text-primary-content rounded-full w-20 h-20">
                <span class="text-2xl font-semibold">
                  {get_initials(@customer.name)}
                </span>
              </div>
            </div>

            <%!-- Customer Info --%>
            <div class="flex-1">
              <div class="flex items-start justify-between mb-4">
                <div>
                  <h2 class="text-2xl font-bold text-base-content">{@customer.name}</h2>
                  <p class="text-base-content/60 mt-1">
                    Member since {format_date(@customer.member_since)}
                  </p>
                </div>
                <.badge variant={loyalty_tier_variant(@customer.loyalty_tier)} size="lg">
                  {format_tier(@customer.loyalty_tier)}
                </.badge>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <%!-- Contact Information --%>
                <div class="space-y-3">
                  <div class="flex items-center gap-2 text-base-content/80">
                    <.icon name="hero-envelope" class="size-5" />
                    <span>{@customer.email}</span>
                  </div>
                  <div class="flex items-center gap-2 text-base-content/80">
                    <.icon name="hero-phone" class="size-5" />
                    <span>{@customer.phone}</span>
                  </div>
                </div>

                <%!-- Loyalty & Stats --%>
                <div class="space-y-3">
                  <div class="flex items-center gap-2 text-base-content/80">
                    <.icon name="hero-star" class="size-5 text-warning" />
                    <span>{format_number(@customer.loyalty_points)} points</span>
                  </div>
                  <div class="flex items-center gap-2 text-base-content/80">
                    <.icon name="hero-shopping-bag" class="size-5" />
                    <span>{@customer.visit_count} visits</span>
                  </div>
                  <div class="flex items-center gap-2 text-base-content/80">
                    <.icon name="hero-currency-dollar" class="size-5" />
                    <span>${format_money(@customer.total_spent)} lifetime</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </.card>

        <%!-- Transaction History --%>
        <.card>
          <.header>Transaction History</.header>

          <div class="mt-4">
            <.data_table id="customer-transactions" rows={@transactions}>
              <:col :let={txn} label="Date" field={:date}>
                {format_datetime(txn.date)}
              </:col>
              <:col :let={txn} label="Reference" field={:reference}>
                <span class="font-mono text-sm">{txn.reference}</span>
              </:col>
              <:col :let={txn} label="Amount" field={:amount} align={:right}>
                <span class="font-semibold">${format_money(txn.amount)}</span>
              </:col>
              <:col :let={txn} label="Status" field={:status}>
                <.badge variant={status_variant(txn.status)} size="sm">
                  {format_status(txn.status)}
                </.badge>
              </:col>
            </.data_table>
          </div>
        </.card>
      </:content>

      <:sidebar>
        <.action_sidebar>
          <:actions>
            <.sidebar_action
              icon="hero-pencil"
              label="Edit Customer"
              phx-click="edit_customer"
            />
            <.sidebar_action
              icon="hero-envelope"
              label="Contact Customer"
              phx-click="contact_customer"
            />
            <.sidebar_action icon="hero-document-text" label="View Notes" phx-click="view_notes" />
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
  def handle_event("edit_customer", _params, socket) do
    # Placeholder for edit customer action
    {:noreply, socket}
  end

  @impl true
  def handle_event("contact_customer", _params, socket) do
    # Placeholder for contact customer action
    {:noreply, socket}
  end

  @impl true
  def handle_event("view_notes", _params, socket) do
    # Placeholder for view notes action
    {:noreply, socket}
  end

  @impl true
  def handle_event("view_engagement_history", _params, socket) do
    # Placeholder for AI insight action
    {:noreply, socket}
  end

  @impl true
  def handle_event("view_recommendations", _params, socket) do
    # Placeholder for AI insight action
    {:noreply, socket}
  end

  # Private helper functions

  defp find_customer(id) do
    # Mock data - replace with Ash resource query
    # Customer.get!(id)
    %{
      id: id,
      name: "John Doe",
      email: "john@example.com",
      phone: "+1 555-0123",
      loyalty_points: 1250,
      loyalty_tier: :gold,
      member_since: ~U[2024-06-15 10:00:00Z],
      total_spent: Decimal.new("2450.00"),
      visit_count: 18
    }
  end

  defp get_customer_transactions(customer_id) do
    # Mock data - replace with Ash resource query
    # Transaction.for_customer!(customer_id)
    _ = customer_id

    [
      %{
        id: "txn_1",
        reference: "TXN-2026-001",
        amount: Decimal.new("125.00"),
        status: :completed,
        date: ~U[2026-01-10 14:30:00Z]
      },
      %{
        id: "txn_2",
        reference: "TXN-2026-002",
        amount: Decimal.new("89.50"),
        status: :completed,
        date: ~U[2026-01-08 16:45:00Z]
      },
      %{
        id: "txn_3",
        reference: "TXN-2026-003",
        amount: Decimal.new("215.00"),
        status: :pending,
        date: ~U[2026-01-05 11:20:00Z]
      }
    ]
  end

  defp get_ai_insights(customer_id) do
    # Mock data - replace with AI insights service
    _ = customer_id

    [
      %{
        message: "High-value customer with strong engagement trend",
        action: "View engagement history",
        event: "view_engagement_history"
      },
      %{
        message: "Recommended for loyalty program upgrade",
        action: "View recommendations",
        event: "view_recommendations"
      }
    ]
  end

  defp get_initials(name) do
    name
    |> String.split()
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y")
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %I:%M %p")
  end

  defp format_number(number) when is_integer(number) do
    Mcp.NumberHelper.number_to_delimited(number, precision: 0)
  end

  defp format_money(%Decimal{} = amount) do
    amount
    |> Decimal.to_string(:normal)
    |> String.to_float()
    |> Mcp.NumberHelper.number_to_currency()
  end

  defp format_tier(:gold), do: "Gold"
  defp format_tier(:silver), do: "Silver"
  defp format_tier(:bronze), do: "Bronze"
  defp format_tier(:platinum), do: "Platinum"
  defp format_tier(_), do: "Member"

  defp loyalty_tier_variant(:platinum), do: "info"
  defp loyalty_tier_variant(:gold), do: "warning"
  defp loyalty_tier_variant(:silver), do: nil
  defp loyalty_tier_variant(:bronze), do: "accent"
  defp loyalty_tier_variant(_), do: nil

  defp format_status(:completed), do: "Completed"
  defp format_status(:pending), do: "Pending"
  defp format_status(:failed), do: "Failed"
  defp format_status(:refunded), do: "Refunded"
  defp format_status(_), do: "Unknown"

  defp status_variant(:completed), do: "success"
  defp status_variant(:pending), do: "warning"
  defp status_variant(:failed), do: "error"
  defp status_variant(:refunded), do: "info"
  defp status_variant(_), do: nil
end
