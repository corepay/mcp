defmodule McpWeb.Merchant.Customers.IndexLive do
  @moduledoc """
  Merchant Customers index page - displays customer list with stats, filters, and actions.
  """
  use McpWeb, :live_view

  import McpWeb.Portal.PageLayout
  import McpWeb.Portal.StatsRow
  import McpWeb.Portal.DataTable
  import McpWeb.Portal.ActionSidebar

  @impl true
  def mount(_params, _session, socket) do
    customers = get_sample_customers()
    stats = calculate_stats(customers)

    socket =
      socket
      |> assign(:customers, customers)
      |> assign(:filtered_customers, customers)
      |> assign(:stats, stats)
      |> assign(:search, "")
      |> assign(:loyalty_tier_filter, "all")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout variant={:list} title="Customers">
      <:stats>
        <.stats_row>
          <.stat
            label="Total Customers"
            value={@stats.total_customers}
            icon="hero-users"
          />
          <.stat
            label="Active This Month"
            value={@stats.active_this_month}
            trend={@stats.active_trend}
            comparison="vs last month"
          />
          <.stat
            label="Loyalty Members"
            value={@stats.loyalty_members}
            icon="hero-star"
          />
          <.stat
            label="Avg Loyalty Points"
            value={@stats.avg_loyalty_points}
            trend={@stats.points_trend}
            comparison="vs last month"
          />
        </.stats_row>
      </:stats>

      <:toolbar>
        <form phx-change="search" class="flex-1">
          <input
            type="search"
            name="search"
            value={@search}
            placeholder="Search customers..."
            class="input input-bordered w-full max-w-xs"
          />
        </form>
      </:toolbar>

      <:content>
        <.data_table id="customers-table" rows={@filtered_customers}>
          <:col :let={customer} label="Name" field={:name}>
            <div class="flex items-center gap-2">
              <div class="avatar placeholder">
                <div class="bg-primary text-primary-content rounded-full w-8">
                  <span class="text-xs">{get_initials(customer.name)}</span>
                </div>
              </div>
              <span class="font-medium">{customer.name}</span>
            </div>
          </:col>

          <:col :let={customer} label="Email" field={:email}>
            {customer.email}
          </:col>

          <:col :let={customer} label="Phone" field={:phone}>
            {customer.phone}
          </:col>

          <:col :let={customer} label="Loyalty Points" field={:loyalty_points} align={:right}>
            <div class="flex items-center justify-end gap-2">
              <span class="font-semibold">{customer.loyalty_points}</span>
              <span class="badge badge-sm" class={loyalty_badge_class(customer.loyalty_tier)}>
                {format_tier(customer.loyalty_tier)}
              </span>
            </div>
          </:col>

          <:action :let={customer}>
            <a href={"/app/customers/#{customer.id}"} class="btn btn-ghost btn-sm">
              View
            </a>
          </:action>

          <:empty>
            <div class="flex flex-col items-center justify-center py-12 text-base-content/60">
              <svg
                class="size-12 mb-2"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
                />
              </svg>
              <p>No customers found</p>
            </div>
          </:empty>
        </.data_table>
      </:content>

      <:sidebar>
        <.action_sidebar>
          <:actions>
            <.sidebar_action icon="hero-plus" label="Add Customer" phx-click="add_customer" />
            <.sidebar_action icon="hero-arrow-up-tray" label="Import CSV" phx-click="import_csv" />
            <.sidebar_action
              icon="hero-arrow-down-tray"
              label="Export List"
              phx-click="export_list"
            />
          </:actions>

          <:filters>
            <.sidebar_filter
              label="Loyalty Tier"
              options={[
                {"All Tiers", "all"},
                {"Gold", "gold"},
                {"Silver", "silver"},
                {"Bronze", "bronze"},
                {"None", "none"}
              ]}
              field={:loyalty_tier}
              value={@loyalty_tier_filter}
              phx-change="filter_changed"
            />
          </:filters>

          <:insights>
            <.ai_insight
              message="Top 20% of customers generate 75% of revenue"
              action="View high-value segment"
              phx-click="view_segment"
            />
            <.ai_insight
              message="12 customers haven't visited in 30+ days"
              action="Send re-engagement campaign"
              phx-click="reengage"
            />
          </:insights>
        </.action_sidebar>
      </:sidebar>
    </.page_layout>
    """
  end

  @impl true
  def handle_event("search", %{"search" => search_term}, socket) do
    customers = socket.assigns.customers
    filtered = filter_customers(customers, search_term, socket.assigns.loyalty_tier_filter)

    {:noreply, assign(socket, search: search_term, filtered_customers: filtered)}
  end

  @impl true
  def handle_event("filter_changed", %{"loyalty_tier" => tier}, socket) do
    customers = socket.assigns.customers
    filtered = filter_customers(customers, socket.assigns.search, tier)

    {:noreply, assign(socket, loyalty_tier_filter: tier, filtered_customers: filtered)}
  end

  @impl true
  def handle_event("add_customer", _params, socket) do
    # Placeholder for add customer action
    {:noreply, socket}
  end

  @impl true
  def handle_event("import_csv", _params, socket) do
    # Placeholder for import CSV action
    {:noreply, socket}
  end

  @impl true
  def handle_event("export_list", _params, socket) do
    # Placeholder for export list action
    {:noreply, socket}
  end

  @impl true
  def handle_event("view_segment", _params, socket) do
    # Placeholder for view segment action
    {:noreply, socket}
  end

  @impl true
  def handle_event("reengage", _params, socket) do
    # Placeholder for re-engagement campaign action
    {:noreply, socket}
  end

  # Private helper functions

  defp get_sample_customers do
    [
      %{
        id: "1",
        name: "John Doe",
        email: "john@example.com",
        phone: "+1 555-0123",
        loyalty_points: 1250,
        loyalty_tier: :gold,
        created_at: ~U[2025-12-01 10:00:00Z],
        last_visit: ~U[2026-01-10 14:30:00Z]
      },
      %{
        id: "2",
        name: "Jane Smith",
        email: "jane@example.com",
        phone: "+1 555-0124",
        loyalty_points: 850,
        loyalty_tier: :silver,
        created_at: ~U[2025-11-15 09:00:00Z],
        last_visit: ~U[2026-01-09 11:00:00Z]
      },
      %{
        id: "3",
        name: "Bob Johnson",
        email: "bob@example.com",
        phone: "+1 555-0125",
        loyalty_points: 420,
        loyalty_tier: :bronze,
        created_at: ~U[2025-10-20 16:45:00Z],
        last_visit: ~U[2026-01-08 10:15:00Z]
      },
      %{
        id: "4",
        name: "Alice Williams",
        email: "alice@example.com",
        phone: "+1 555-0126",
        loyalty_points: 1580,
        loyalty_tier: :gold,
        created_at: ~U[2025-09-10 12:00:00Z],
        last_visit: ~U[2026-01-11 09:30:00Z]
      },
      %{
        id: "5",
        name: "Charlie Brown",
        email: "charlie@example.com",
        phone: "+1 555-0127",
        loyalty_points: 0,
        loyalty_tier: :none,
        created_at: ~U[2026-01-05 08:00:00Z],
        last_visit: ~U[2026-01-05 08:00:00Z]
      }
    ]
  end

  defp calculate_stats(customers) do
    total = length(customers)
    loyalty_members = Enum.count(customers, fn c -> c.loyalty_tier != :none end)

    avg_points =
      if total > 0 do
        customers
        |> Enum.map(& &1.loyalty_points)
        |> Enum.sum()
        |> div(total)
        |> to_string()
      else
        "0"
      end

    %{
      total_customers: to_string(total),
      active_this_month: "#{total}",
      active_trend: 12,
      loyalty_members: to_string(loyalty_members),
      avg_loyalty_points: avg_points,
      points_trend: 8
    }
  end

  defp filter_customers(customers, search_term, tier_filter) do
    customers
    |> filter_by_search(search_term)
    |> filter_by_tier(tier_filter)
  end

  defp filter_by_search(customers, "") do
    customers
  end

  defp filter_by_search(customers, search_term) do
    search_lower = String.downcase(search_term)

    Enum.filter(customers, fn customer ->
      String.contains?(String.downcase(customer.name), search_lower) ||
        String.contains?(String.downcase(customer.email), search_lower) ||
        String.contains?(String.downcase(customer.phone), search_lower)
    end)
  end

  defp filter_by_tier(customers, "all"), do: customers

  defp filter_by_tier(customers, tier) do
    tier_atom = String.to_existing_atom(tier)
    Enum.filter(customers, fn customer -> customer.loyalty_tier == tier_atom end)
  end

  defp get_initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  defp format_tier(:gold), do: "Gold"
  defp format_tier(:silver), do: "Silver"
  defp format_tier(:bronze), do: "Bronze"
  defp format_tier(:none), do: "None"

  defp loyalty_badge_class(:gold), do: "badge-warning"
  defp loyalty_badge_class(:silver), do: "badge-info"
  defp loyalty_badge_class(:bronze), do: "badge-accent"
  defp loyalty_badge_class(:none), do: "badge-ghost"
end
