defmodule McpWeb.Store.DashboardLive do
  @moduledoc """
  Store portal dashboard with quick actions, shift context, and pending items.
  """
  use McpWeb, :live_view
  import McpWeb.Core.DataDisplay, only: [stat_card: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1, card: 1, header: 1]

  @impl true
  def mount(%{"store_slug" => store_slug}, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Store Dashboard")
      |> assign(:store_slug, store_slug)
      |> assign(:store_name, "Downtown Store")
      |> assign(:shift_start, "2:00 PM")
      |> assign(:stats, get_mock_stats())
      |> assign(:quick_actions, get_quick_actions(store_slug))
      |> assign(:recent_transactions, get_mock_transactions())
      |> assign(:pending_items, get_mock_pending())

    {:ok, socket}
  end

  @impl true
  def mount(_params, _session, socket) do
    # Fallback for routes without store_slug
    store_slug = "default"

    socket =
      socket
      |> assign(:page_title, "Store Dashboard")
      |> assign(:store_slug, store_slug)
      |> assign(:store_name, "Default Store")
      |> assign(:shift_start, "2:00 PM")
      |> assign(:stats, get_mock_stats())
      |> assign(:quick_actions, get_quick_actions(store_slug))
      |> assign(:recent_transactions, get_mock_transactions())
      |> assign(:pending_items, get_mock_pending())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header with shift info --%>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-base-content">Good afternoon</h1>
          <p class="text-base-content/60 mt-1">{@store_name}</p>
        </div>
        <div class="flex items-center gap-2 text-sm text-base-content/70">
          <.icon name="hero-clock" class="size-4" />
          <span>Shift: {@shift_start} - Close</span>
        </div>
      </div>

      <%!-- Stats --%>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <.stat_card
          :for={stat <- @stats}
          value={stat.value}
          label={stat.label}
          icon={stat.icon}
        />
      </div>

      <%!-- Quick Actions --%>
      <.card>
        <.header class="mb-4">Quick Actions</.header>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <a
            :for={action <- @quick_actions}
            href={action.href}
            class={[
              "flex flex-col items-center justify-center gap-3 p-6",
              "bg-base-200/50 rounded-xl",
              "border-2 border-transparent",
              "hover:border-primary hover:bg-base-200",
              "transition-all duration-200",
              "group"
            ]}
          >
            <div class={[
              "p-4 rounded-full",
              "bg-primary/10 text-primary",
              "group-hover:bg-primary group-hover:text-primary-content",
              "transition-colors duration-200"
            ]}>
              <.icon name={action.icon} class="size-8" />
            </div>
            <span class="font-medium text-base-content">{action.label}</span>
          </a>
        </div>
      </.card>

      <%!-- Bottom Row --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Recent Transactions --%>
        <.card>
          <.header>
            Recent Transactions
            <:actions>
              <a href={"/app/stores/#{@store_slug}/transactions"} class="btn btn-ghost btn-xs">
                View All
              </a>
            </:actions>
          </.header>
          <div class="space-y-2 mt-4">
            <div
              :for={txn <- @recent_transactions}
              class="flex items-center justify-between p-3 bg-base-200/30 rounded-lg"
            >
              <div class="flex items-center gap-3">
                <span class="text-sm text-base-content/60">{txn.time}</span>
                <span class="font-medium">{txn.customer}</span>
              </div>
              <div class="flex items-center gap-3">
                <span class="font-semibold">{txn.amount}</span>
                <.icon name="hero-check-circle" class="size-5 text-success" />
              </div>
            </div>
          </div>
        </.card>

        <%!-- Pending Items --%>
        <.card>
          <.header>Pending</.header>
          <div class="space-y-3 mt-4">
            <a
              :for={item <- @pending_items}
              href={item.href}
              class="flex items-center gap-3 p-3 rounded-lg bg-base-200/50 hover:bg-base-200 transition-colors"
            >
              <div class={[
                "p-2 rounded-lg",
                item.type == :order && "bg-info/20 text-info",
                item.type == :invoice && "bg-warning/20 text-warning",
                item.type == :refund && "bg-error/20 text-error"
              ]}>
                <.icon name={item.icon} class="size-5" />
              </div>
              <div class="flex-1">
                <p class="font-medium text-sm">{item.title}</p>
              </div>
              <.icon name="hero-chevron-right" class="size-4 text-base-content/40" />
            </a>

            <div
              :if={@pending_items == []}
              class="text-center py-8 text-base-content/50"
            >
              <.icon name="hero-check-circle" class="size-12 mx-auto mb-2 opacity-50" />
              <p>All caught up!</p>
            </div>
          </div>
        </.card>
      </div>
    </div>
    """
  end

  # Mock data - replace with Ash queries
  defp get_mock_stats do
    [
      %{value: "$2,847", label: "Today's Sales", icon: "hero-currency-dollar"},
      %{value: "34", label: "Transactions", icon: "hero-receipt-percent"},
      %{value: "$83.74", label: "Avg Ticket", icon: "hero-shopping-cart"}
    ]
  end

  defp get_quick_actions(store_slug) do
    base = "/app/stores/#{store_slug}"

    [
      %{label: "New Sale", icon: "hero-credit-card", href: "#{base}/pos"},
      %{label: "Invoice", icon: "hero-document-text", href: "#{base}/invoices/new"},
      %{label: "Customer Lookup", icon: "hero-user", href: "#{base}/customers"},
      %{label: "Refund", icon: "hero-receipt-refund", href: "#{base}/refunds/new"}
    ]
  end

  defp get_mock_transactions do
    [
      %{time: "2:34 PM", customer: "J. Smith", amount: "$124.00"},
      %{time: "2:21 PM", customer: "M. Lee", amount: "$89.50"},
      %{time: "2:15 PM", customer: "Guest", amount: "$42.00"}
    ]
  end

  defp get_mock_pending do
    [
      %{
        type: :order,
        icon: "hero-truck",
        title: "2 orders ready to ship",
        href: "#"
      },
      %{
        type: :invoice,
        icon: "hero-document-text",
        title: "1 invoice awaiting payment",
        href: "#"
      },
      %{
        type: :refund,
        icon: "hero-receipt-refund",
        title: "1 refund request",
        href: "#"
      }
    ]
  end
end
