defmodule McpWeb.Store.Customers.IndexLive do
  @moduledoc """
  Customer lookup page for store staff.

  READ-ONLY interface focused on quick customer lookup by name or phone.
  Store staff can view customer details but cannot add or edit customers.
  """
  use McpWeb, :live_view

  @impl true
  def mount(%{"store_slug" => store_slug}, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Customer Lookup")
      |> assign(:store_slug, store_slug)
      |> assign(:search_query, "")
      |> assign(:loyalty_tier_filter, "")
      |> assign(:customers, get_sample_customers())

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> filter_customers()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_changed", %{"loyalty_tier" => tier}, socket) do
    socket =
      socket
      |> assign(:loyalty_tier_filter, tier)
      |> filter_customers()

    {:noreply, socket}
  end

  @impl true
  def handle_event("row-click", %{"id" => id}, socket) do
    # Extract numeric ID from "row-N" format
    customer_id = String.replace_prefix(id, "row-", "")
    store_slug = socket.assigns.store_slug

    {:noreply, push_navigate(socket, to: ~p"/app/stores/#{store_slug}/customers/#{customer_id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout variant={:list} title="Customer Lookup">
      <:toolbar>
        <form phx-change="search" class="flex-1">
          <input
            type="search"
            name="search[query]"
            value={@search_query}
            placeholder="Search customers by name or phone..."
            class="input input-bordered w-full max-w-md"
            autocomplete="off"
          />
        </form>
      </:toolbar>

      <:content>
        <.data_table
          id="customers-table"
          rows={@customers}
          row_click={true}
        >
          <:col :let={customer} label="Name" field={:name}>
            <div class="flex items-center gap-3">
              <div class="avatar placeholder">
                <div class="bg-primary/10 text-primary rounded-full w-10">
                  <span class="text-xs font-semibold">
                    {get_initials(customer.name)}
                  </span>
                </div>
              </div>
              <span class="font-medium">{customer.name}</span>
            </div>
          </:col>

          <:col :let={customer} label="Email" field={:email}>
            <a href={"mailto:#{customer.email}"} class="link link-hover">
              {customer.email}
            </a>
          </:col>

          <:col :let={customer} label="Phone" field={:phone}>
            <a href={"tel:#{customer.phone}"} class="link link-hover">
              {customer.phone}
            </a>
          </:col>

          <:col :let={customer} label="Loyalty Status" field={:loyalty_tier} align={:right}>
            <div class="flex items-center justify-end gap-2">
              <span class={loyalty_badge_classes(customer.loyalty_tier)}>
                {format_loyalty_tier(customer.loyalty_tier)}
              </span>
              <span class="text-sm text-base-content/60">
                {customer.loyalty_points} pts
              </span>
            </div>
          </:col>

          <:empty>
            <div class="flex flex-col items-center justify-center py-12 text-base-content/60">
              <.icon name="hero-users" class="size-12 mb-2" />
              <p class="font-medium">No customers found</p>
              <p class="text-sm">Try adjusting your search or filters</p>
            </div>
          </:empty>
        </.data_table>
      </:content>

      <:sidebar>
        <.action_sidebar>
          <:filters>
            <.sidebar_filter
              label="Loyalty Tier"
              options={[
                {"All Tiers", ""},
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
              message="3 customers haven't visited in 30+ days"
              action="View inactive"
              href="#"
            />
          </:insights>
        </.action_sidebar>
      </:sidebar>
    </.page_layout>
    """
  end

  # Private functions

  defp filter_customers(socket) do
    all_customers = get_sample_customers()
    query = String.downcase(socket.assigns.search_query)
    tier_filter = socket.assigns.loyalty_tier_filter

    filtered =
      all_customers
      |> filter_by_search(query)
      |> filter_by_loyalty_tier(tier_filter)

    assign(socket, :customers, filtered)
  end

  defp filter_by_search(customers, ""), do: customers

  defp filter_by_search(customers, query) do
    Enum.filter(customers, fn customer ->
      name_match = String.contains?(String.downcase(customer.name), query)
      phone_match = String.contains?(customer.phone, query)
      name_match or phone_match
    end)
  end

  defp filter_by_loyalty_tier(customers, ""), do: customers

  defp filter_by_loyalty_tier(customers, tier) do
    tier_atom = String.to_existing_atom(tier)
    Enum.filter(customers, fn customer -> customer.loyalty_tier == tier_atom end)
  end

  defp get_initials(name) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end

  defp loyalty_badge_classes(:gold) do
    "badge badge-warning badge-sm"
  end

  defp loyalty_badge_classes(:silver) do
    "badge badge-info badge-sm"
  end

  defp loyalty_badge_classes(:bronze) do
    "badge badge-accent badge-sm"
  end

  defp loyalty_badge_classes(_) do
    "badge badge-ghost badge-sm"
  end

  defp format_loyalty_tier(:gold), do: "Gold"
  defp format_loyalty_tier(:silver), do: "Silver"
  defp format_loyalty_tier(:bronze), do: "Bronze"
  defp format_loyalty_tier(_), do: "None"

  # Sample data - replace with Ash queries in Phase 3
  defp get_sample_customers do
    [
      %{
        id: "1",
        name: "John Doe",
        email: "john.doe@example.com",
        phone: "+1 555-0123",
        loyalty_points: 1250,
        loyalty_tier: :gold
      },
      %{
        id: "2",
        name: "Jane Smith",
        email: "jane.smith@example.com",
        phone: "+1 555-0124",
        loyalty_points: 850,
        loyalty_tier: :silver
      },
      %{
        id: "3",
        name: "Bob Johnson",
        email: "bob.johnson@example.com",
        phone: "+1 555-0125",
        loyalty_points: 420,
        loyalty_tier: :bronze
      },
      %{
        id: "4",
        name: "Alice Williams",
        email: "alice.williams@example.com",
        phone: "+1 555-0126",
        loyalty_points: 1500,
        loyalty_tier: :gold
      },
      %{
        id: "5",
        name: "Charlie Brown",
        email: "charlie.brown@example.com",
        phone: "+1 555-0127",
        loyalty_points: 0,
        loyalty_tier: :none
      }
    ]
  end
end
