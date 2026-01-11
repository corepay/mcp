defmodule McpWeb.Merchant.DashboardLive do
  @moduledoc """
  Merchant portal dashboard with stats, charts, and activity feeds.
  """
  use McpWeb, :live_view
  import McpWeb.Core.DataDisplay, only: [stat_card: 1, badge: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1, card: 1, header: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:merchant_name, "Acme Corp")
      |> assign(:user_name, "Ryan")
      |> assign(:stats, get_mock_stats())
      |> assign(:stores_performance, get_mock_stores())
      |> assign(:recent_transactions, get_mock_transactions())
      |> assign(:alerts, get_mock_alerts())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header --%>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-base-content">
            Welcome back, {@user_name}
          </h1>
          <p class="text-base-content/60 mt-1">
            Here's what's happening with your business today.
          </p>
        </div>
        <div class="flex gap-2">
          <select class="select select-bordered select-sm">
            <option>Today</option>
            <option>Yesterday</option>
            <option>Last 7 days</option>
            <option>Last 30 days</option>
          </select>
          <button class="btn btn-outline btn-sm gap-2">
            <.icon name="hero-arrow-down-tray" class="size-4" /> Export
          </button>
        </div>
      </div>

      <%!-- Stats Grid --%>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <.stat_card
          :for={stat <- @stats}
          value={stat.value}
          label={stat.label}
          trend={stat.trend}
          trend_direction={stat.trend_direction}
          icon={stat.icon}
        />
      </div>

      <%!-- Charts Row --%>
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <%!-- Revenue Chart (2/3 width) --%>
        <.card class="lg:col-span-2">
          <.header>
            Revenue (7 days)
            <:actions>
              <button class="btn btn-ghost btn-xs">View Details</button>
            </:actions>
          </.header>
          <div class="h-64 flex items-center justify-center bg-base-200/50 rounded-lg mt-4">
            <span class="text-base-content/40">Chart placeholder</span>
          </div>
        </.card>

        <%!-- Stores Performance --%>
        <.card>
          <.header>Stores Performance</.header>
          <div class="space-y-4 mt-4">
            <div :for={store <- @stores_performance} class="flex items-center gap-3">
              <div class="flex-1">
                <div class="flex justify-between text-sm">
                  <span class="font-medium">{store.name}</span>
                  <span class="text-base-content/70">{store.revenue}</span>
                </div>
                <progress
                  class="progress progress-primary w-full h-2 mt-1"
                  value={store.percent}
                  max="100"
                >
                </progress>
              </div>
            </div>
          </div>
        </.card>
      </div>

      <%!-- Bottom Row --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Recent Transactions --%>
        <.card>
          <.header>
            Recent Transactions
            <:actions>
              <a href="/app/payments" class="btn btn-ghost btn-xs">View All</a>
            </:actions>
          </.header>
          <div class="overflow-x-auto mt-4">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Time</th>
                  <th>Customer</th>
                  <th>Amount</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={txn <- @recent_transactions}>
                  <td class="text-base-content/70">{txn.time}</td>
                  <td>{txn.customer}</td>
                  <td class="font-medium">{txn.amount}</td>
                  <td>
                    <.badge variant={status_variant(txn.status)} size="sm">
                      {txn.status}
                    </.badge>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </.card>

        <%!-- Needs Attention --%>
        <.card>
          <.header>Needs Attention</.header>
          <div class="space-y-3 mt-4">
            <a
              :for={alert <- @alerts}
              href={alert.href}
              class="flex items-center gap-3 p-3 rounded-lg bg-base-200/50 hover:bg-base-200 transition-colors"
            >
              <div class={[
                "p-2 rounded-lg",
                alert.type == :warning && "bg-warning/20 text-warning",
                alert.type == :error && "bg-error/20 text-error",
                alert.type == :info && "bg-info/20 text-info"
              ]}>
                <.icon name={alert.icon} class="size-5" />
              </div>
              <div class="flex-1">
                <p class="font-medium text-sm">{alert.title}</p>
                <p class="text-xs text-base-content/60">{alert.description}</p>
              </div>
              <.icon name="hero-chevron-right" class="size-4 text-base-content/40" />
            </a>
          </div>
        </.card>
      </div>
    </div>
    """
  end

  defp status_variant("completed"), do: "success"
  defp status_variant("pending"), do: "warning"
  defp status_variant("failed"), do: "error"
  defp status_variant(_), do: nil

  # Mock data functions - replace with Ash resource queries
  defp get_mock_stats do
    [
      %{
        value: "$12,847",
        label: "Today's Revenue",
        trend: "+12% vs yesterday",
        trend_direction: :up,
        icon: "hero-currency-dollar"
      },
      %{
        value: "156",
        label: "Transactions",
        trend: "+8% vs yesterday",
        trend_direction: :up,
        icon: "hero-receipt-percent"
      },
      %{
        value: "89",
        label: "Customers",
        trend: "-3% vs yesterday",
        trend_direction: :down,
        icon: "hero-users"
      },
      %{
        value: "$82.35",
        label: "Avg Order",
        trend: "+5% vs yesterday",
        trend_direction: :up,
        icon: "hero-shopping-cart"
      }
    ]
  end

  defp get_mock_stores do
    [
      %{name: "Downtown", revenue: "$6,420", percent: 100},
      %{name: "Online", revenue: "$4,890", percent: 76},
      %{name: "Warehouse", revenue: "$1,537", percent: 24}
    ]
  end

  defp get_mock_transactions do
    [
      %{time: "2:34 PM", customer: "J. Smith", amount: "$124.00", status: "completed"},
      %{time: "2:21 PM", customer: "M. Lee", amount: "$89.50", status: "completed"},
      %{time: "2:15 PM", customer: "Guest", amount: "$42.00", status: "completed"},
      %{time: "2:08 PM", customer: "A. Johnson", amount: "$215.00", status: "pending"},
      %{time: "1:55 PM", customer: "C. Williams", amount: "$67.25", status: "completed"}
    ]
  end

  defp get_mock_alerts do
    [
      %{
        type: :warning,
        icon: "hero-exclamation-triangle",
        title: "3 failed transactions",
        description: "Review and retry or refund",
        href: "/app/payments?status=failed"
      },
      %{
        type: :warning,
        icon: "hero-credit-card",
        title: "MID approaching limit",
        description: "QorPay at 85% of monthly volume",
        href: "/app/payments/mids"
      },
      %{
        type: :info,
        icon: "hero-document-text",
        title: "5 invoices overdue",
        description: "Send reminders to customers",
        href: "/app/invoices?status=overdue"
      }
    ]
  end
end
