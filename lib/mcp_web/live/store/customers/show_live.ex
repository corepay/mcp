defmodule McpWeb.Store.Customers.ShowLive do
  @moduledoc """
  Customer detail page for store staff.

  READ-ONLY interface focused on quick customer lookup.
  Store staff can view customer details but cannot edit or contact customers.
  Shows only recent transactions (last 5).
  """
  use McpWeb, :live_view

  import McpWeb.Portal.PageLayout, only: [page_layout: 1]
  import McpWeb.Portal.DataTable, only: [data_table: 1]

  import McpWeb.Portal.ActionSidebar,
    only: [action_sidebar: 1, ai_insight: 1]

  import McpWeb.Core.CoreComponents, only: [icon: 1, card: 1]
  import McpWeb.Core.DataDisplay, only: [badge: 1]

  @impl true
  def mount(%{"store_slug" => store_slug, "id" => customer_id}, _session, socket) do
    customer = find_customer(customer_id)
    recent_transactions = get_recent_transactions(customer_id)
    insights = get_ai_insights(customer_id)

    socket =
      socket
      |> assign(:page_title, customer.name)
      |> assign(:store_slug, store_slug)
      |> assign(:customer, customer)
      |> assign(:recent_transactions, recent_transactions)
      |> assign(:insights, insights)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout
      variant={:detail}
      title={@customer.name}
      back={~p"/app/stores/#{@store_slug}/customers"}
    >
      <:content>
        <%!-- Customer Profile Card --%>
        <.card class="mb-6">
          <div class="flex items-start gap-6">
            <%!-- Avatar --%>
            <div class="avatar placeholder">
              <div class="bg-primary text-primary-content rounded-full w-16 h-16">
                <span class="text-xl font-semibold">
                  {get_initials(@customer.name)}
                </span>
              </div>
            </div>
            <%!-- Customer Info --%>
            <div class="flex-1">
              <div class="flex items-start justify-between mb-4">
                <div>
                  <h2 class="text-xl font-bold text-base-content">{@customer.name}</h2>
                  <p class="text-base-content/60 mt-1">
                    Member since {format_date(@customer.member_since)}
                  </p>
                </div>
                <.badge variant={loyalty_tier_variant(@customer.loyalty_tier)} size="lg">
                  {format_tier(@customer.loyalty_tier)}
                </.badge>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <%!-- Contact Information (Email only for store staff) --%>
                <div class="space-y-3">
                  <div class="flex items-center gap-2 text-base-content/80">
                    <.icon name="hero-envelope" class="size-5" />
                    <a href={"mailto:#{@customer.email}"} class="link link-hover">
                      {@customer.email}
                    </a>
                  </div>
                  <div class="flex items-center gap-2 text-base-content/80">
                    <.icon name="hero-phone" class="size-5" />
                    <a href={"tel:#{@customer.phone}"} class="link link-hover">
                      {@customer.phone}
                    </a>
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
                </div>
              </div>
            </div>
          </div>
        </.card>
        <%!-- Recent Transactions (last 5 only) --%>
        <.card>
          <h3 class="text-lg font-semibold text-base-content mb-4">Recent Transactions</h3>

          <div class="mt-4">
            <.data_table id="recent-transactions" rows={@recent_transactions}>
              <:col :let={txn} label="Date" field={:date}>
                {format_datetime(txn.date)}
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
          <:insights>
            <.ai_insight
              :for={insight <- @insights}
              message={insight.message}
              action={insight.action}
              href="#"
            />
          </:insights>
        </.action_sidebar>
      </:sidebar>
    </.page_layout>
    """
  end

  # Private helper functions

  defp find_customer(id) do
    # Mock data - replace with Ash resource query in Phase 3
    # Customer.get!(id)
    %{
      id: id,
      name: "John Doe",
      phone: "+1 555-0123",
      email: "john.doe@example.com",
      loyalty_points: 1250,
      loyalty_tier: :gold,
      member_since: ~U[2024-06-15 10:00:00Z],
      visit_count: 18
    }
  end

  defp get_recent_transactions(customer_id) do
    # Mock data - replace with Ash resource query in Phase 3
    # Transaction.for_customer!(customer_id, limit: 5)
    _ = customer_id

    [
      %{
        id: "txn_1",
        amount: Decimal.new("125.00"),
        status: :completed,
        date: ~U[2026-01-10 14:30:00Z]
      },
      %{
        id: "txn_2",
        amount: Decimal.new("89.50"),
        status: :completed,
        date: ~U[2026-01-08 16:45:00Z]
      },
      %{
        id: "txn_3",
        amount: Decimal.new("215.00"),
        status: :pending,
        date: ~U[2026-01-05 11:20:00Z]
      },
      %{
        id: "txn_4",
        amount: Decimal.new("45.00"),
        status: :completed,
        date: ~U[2026-01-03 09:15:00Z]
      },
      %{
        id: "txn_5",
        amount: Decimal.new("178.25"),
        status: :completed,
        date: ~U[2026-01-01 18:00:00Z]
      }
    ]
  end

  defp get_ai_insights(customer_id) do
    # Mock data - replace with AI insights service in Phase 3
    _ = customer_id

    [
      %{
        message: "Frequent visitor - visits every 3-4 days on average",
        action: "View visit pattern"
      },
      %{
        message: "Prefers afternoon purchases (2-5 PM)",
        action: "View purchase trends"
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
  defp format_tier(_), do: "Member"

  defp loyalty_tier_variant(:gold), do: "warning"
  defp loyalty_tier_variant(:silver), do: nil
  defp loyalty_tier_variant(:bronze), do: "accent"
  defp loyalty_tier_variant(_), do: nil

  defp format_status(:completed), do: "Completed"
  defp format_status(:pending), do: "Pending"
  defp format_status(:failed), do: "Failed"
  defp format_status(_), do: "Unknown"

  defp status_variant(:completed), do: "success"
  defp status_variant(:pending), do: "warning"
  defp status_variant(:failed), do: "error"
  defp status_variant(_), do: nil
end
