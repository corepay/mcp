# Phase 4: Orders & Reports Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete order management for both Merchant and Store portals, plus comprehensive reporting and analytics dashboards.

**Architecture:** Build on Phase 1-3 foundation. Orders flow from POS/Terminal to Order Queue for fulfillment, then to completed history. Reports aggregate transaction and order data into actionable insights.

**Tech Stack:** Phoenix LiveView, Phase 1 layout components, DaisyUI, Ash Framework, Charting library (e.g., Chart.js via hooks)

**Reference Documents:**
- `2026-01-11-merchant-portal-features.md` - Sections 3 (Orders), 4 (Reports)
- `2026-01-11-store-portal-features.md` - Section 3 (Orders)
- `docs/DESIGN_GUIDE.md` - Component patterns

---

## Pre-Implementation: Quality Gate

Before starting Phase 4, verify Phase 1-3 are complete:

```bash
mix test
mix precommit
```

If any failures, complete prior phase remediation first.

---

## Overview: Features to Build

| # | Feature | Portal | Layout | Priority |
|---|---------|--------|--------|----------|
| 1 | Order List | Merchant | B (2/3+1/3 List) | P0 |
| 2 | Order Detail | Merchant | C (2/3+1/3 Detail) | P0 |
| 3 | Fulfillment Queue | Store | E (Focused) | P0 |
| 4 | Order Queue | Store | Custom Kanban | P0 |
| 5 | Order Detail (Store) | Store | C (2/3+1/3 Detail) | P1 |
| 6 | Sales Report | Merchant | D (Full-Width Table) | P1 |
| 7 | Payments Report | Merchant | D (Full-Width Table) | P1 |
| 8 | Daily Summary | Store | A (Dashboard) | P1 |
| 9 | Refund Processing | Merchant | Modal | P1 |
| 10 | Export System | Merchant | Background Job | P2 |

---

## Task 1: Order Ash Resource

**Files:**
- Create: `lib/mcp/commerce/order.ex`
- Create: `lib/mcp/commerce/order_item.ex`
- Create: `lib/mcp/commerce/order_status_history.ex`
- Test: `test/mcp/commerce/order_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/commerce/order_test.exs
defmodule Mcp.Commerce.OrderTest do
  use Mcp.DataCase, async: true

  alias Mcp.Commerce.Order
  alias Mcp.Commerce.OrderItem

  describe "create/1" do
    test "creates an order with items" do
      product = insert(:product, price: Money.new(2999, :USD))

      attrs = %{
        status: :pending,
        items: [
          %{product_id: product.id, quantity: 2, unit_price: product.price}
        ],
        payment_method: :card
      }

      assert {:ok, order} = Order.create(attrs)
      assert order.status == :pending
      assert length(order.items) == 1
      assert order.subtotal == Money.new(5998, :USD)
    end

    test "generates order number" do
      {:ok, order} = Order.create(%{status: :pending, items: []})

      assert order.order_number =~ ~r/^ORD-\d{8}-[A-Z0-9]{4}$/
    end

    test "calculates totals correctly" do
      p1 = insert(:product, price: Money.new(1000, :USD))
      p2 = insert(:product, price: Money.new(2000, :USD))

      {:ok, order} = Order.create(%{
        status: :pending,
        items: [
          %{product_id: p1.id, quantity: 2, unit_price: p1.price},
          %{product_id: p2.id, quantity: 1, unit_price: p2.price}
        ],
        tax_rate: Decimal.new("0.08")
      })

      assert order.subtotal == Money.new(4000, :USD)
      assert order.tax == Money.new(320, :USD)
      assert order.total == Money.new(4320, :USD)
    end
  end

  describe "list_orders/1" do
    test "returns orders with pagination" do
      for _ <- 1..15, do: insert(:order)

      {:ok, result} = Order.list_orders(%{page: 1, page_size: 10})

      assert length(result.results) == 10
      assert result.has_next_page == true
    end

    test "filters by status" do
      insert(:order, status: :pending)
      insert(:order, status: :completed)
      insert(:order, status: :completed)

      {:ok, result} = Order.list_orders(%{status: :completed})

      assert length(result.results) == 2
    end

    test "filters by date range" do
      insert(:order, inserted_at: ~U[2026-01-01 10:00:00Z])
      insert(:order, inserted_at: ~U[2026-01-10 10:00:00Z])
      insert(:order, inserted_at: ~U[2026-01-15 10:00:00Z])

      {:ok, result} = Order.list_orders(%{
        start_date: ~D[2026-01-05],
        end_date: ~D[2026-01-12]
      })

      assert length(result.results) == 1
    end

    test "searches by order number" do
      insert(:order, order_number: "ORD-20260111-ABCD")
      insert(:order, order_number: "ORD-20260111-EFGH")

      {:ok, result} = Order.list_orders(%{search: "ABCD"})

      assert length(result.results) == 1
    end
  end

  describe "status transitions" do
    test "can transition pending -> processing" do
      order = insert(:order, status: :pending)

      {:ok, updated} = Order.update_status(order, :processing)

      assert updated.status == :processing
    end

    test "can transition processing -> ready" do
      order = insert(:order, status: :processing)

      {:ok, updated} = Order.update_status(order, :ready)

      assert updated.status == :ready
    end

    test "can transition ready -> completed" do
      order = insert(:order, status: :ready)

      {:ok, updated} = Order.update_status(order, :completed)

      assert updated.status == :completed
      assert updated.completed_at != nil
    end

    test "cannot transition completed -> pending" do
      order = insert(:order, status: :completed)

      {:error, _} = Order.update_status(order, :pending)
    end
  end

  describe "refunds" do
    test "can refund entire order" do
      order = insert(:order, status: :completed, total: Money.new(5000, :USD))

      {:ok, refunded} = Order.refund(order, %{amount: Money.new(5000, :USD), reason: "Customer request"})

      assert refunded.refund_status == :full
      assert refunded.refunded_amount == Money.new(5000, :USD)
    end

    test "can partially refund order" do
      order = insert(:order, status: :completed, total: Money.new(5000, :USD))

      {:ok, refunded} = Order.refund(order, %{amount: Money.new(2000, :USD), reason: "Item returned"})

      assert refunded.refund_status == :partial
      assert refunded.refunded_amount == Money.new(2000, :USD)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp/commerce/order_test.exs -v`
Expected: FAIL

**Step 3: Write minimal implementation**

```elixir
# lib/mcp/commerce/order.ex
defmodule Mcp.Commerce.Order do
  @moduledoc """
  Order resource for commerce transactions.

  Orders are created from POS or Terminal and flow through:
  pending -> processing -> ready -> completed

  Supports partial and full refunds.
  """
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Mcp.Commerce

  postgres do
    table "orders"
    repo Mcp.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :order_number, :string, allow_nil?: false
    attribute :status, :atom do
      constraints one_of: [:pending, :processing, :ready, :completed, :cancelled]
      default :pending
    end

    attribute :payment_method, :atom do
      constraints one_of: [:card, :cash, :split]
    end

    attribute :subtotal, Mcp.Types.Money, default: Money.new(0, :USD)
    attribute :tax, Mcp.Types.Money, default: Money.new(0, :USD)
    attribute :tax_rate, :decimal, default: Decimal.new("0")
    attribute :discount, Mcp.Types.Money, default: Money.new(0, :USD)
    attribute :total, Mcp.Types.Money, default: Money.new(0, :USD)

    attribute :refund_status, :atom do
      constraints one_of: [:none, :partial, :full]
      default :none
    end
    attribute :refunded_amount, Mcp.Types.Money, default: Money.new(0, :USD)
    attribute :refund_reason, :string

    attribute :notes, :string
    attribute :metadata, :map, default: %{}

    attribute :completed_at, :utc_datetime

    timestamps()
  end

  relationships do
    belongs_to :tenant, Mcp.Platform.Tenant
    belongs_to :store, Mcp.Platform.Store
    belongs_to :customer, Mcp.CRM.Customer
    belongs_to :cashier, Mcp.Accounts.User

    has_many :items, Mcp.Commerce.OrderItem
    has_many :status_history, Mcp.Commerce.OrderStatusHistory
  end

  identities do
    identity :unique_order_number, [:order_number, :tenant_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:status, :payment_method, :tax_rate, :discount, :notes, :metadata, :customer_id, :store_id]

      argument :items, {:array, :map}

      change fn changeset, _ ->
        # Generate order number
        date = Date.utc_today() |> Date.to_iso8601(:basic) |> String.replace("-", "")
        suffix = :crypto.strong_rand_bytes(2) |> Base.encode16()
        order_number = "ORD-#{date}-#{suffix}"
        Ash.Changeset.change_attribute(changeset, :order_number, order_number)
      end

      change relate_actor(:tenant)
      change relate_actor(:cashier)

      change fn changeset, _ ->
        items = Ash.Changeset.get_argument(changeset, :items) || []

        subtotal = Enum.reduce(items, Money.new(0, :USD), fn item, acc ->
          line_total = Money.multiply(item.unit_price, item.quantity)
          Money.add(acc, line_total)
        end)

        tax_rate = Ash.Changeset.get_attribute(changeset, :tax_rate) || Decimal.new("0")
        tax = Money.multiply(subtotal, tax_rate)
        discount = Ash.Changeset.get_attribute(changeset, :discount) || Money.new(0, :USD)
        total = subtotal |> Money.add(tax) |> Money.subtract(discount)

        changeset
        |> Ash.Changeset.change_attribute(:subtotal, subtotal)
        |> Ash.Changeset.change_attribute(:tax, tax)
        |> Ash.Changeset.change_attribute(:total, total)
      end
    end

    update :update_status do
      argument :new_status, :atom, allow_nil?: false

      change fn changeset, _ ->
        current = Ash.Changeset.get_data(changeset).status
        new_status = Ash.Changeset.get_argument(changeset, :new_status)

        valid_transitions = %{
          pending: [:processing, :cancelled],
          processing: [:ready, :cancelled],
          ready: [:completed, :cancelled],
          completed: [],
          cancelled: []
        }

        if new_status in Map.get(valid_transitions, current, []) do
          changeset
          |> Ash.Changeset.change_attribute(:status, new_status)
          |> maybe_set_completed_at(new_status)
        else
          Ash.Changeset.add_error(changeset, :status, "Invalid status transition from #{current} to #{new_status}")
        end
      end
    end

    update :refund do
      argument :amount, Mcp.Types.Money, allow_nil?: false
      argument :reason, :string

      change fn changeset, _ ->
        amount = Ash.Changeset.get_argument(changeset, :amount)
        reason = Ash.Changeset.get_argument(changeset, :reason)
        order = Ash.Changeset.get_data(changeset)

        cond do
          order.status != :completed ->
            Ash.Changeset.add_error(changeset, :status, "Can only refund completed orders")

          Money.compare(amount, order.total) == :gt ->
            Ash.Changeset.add_error(changeset, :amount, "Refund amount exceeds order total")

          true ->
            existing_refund = order.refunded_amount || Money.new(0, :USD)
            new_refund_total = Money.add(existing_refund, amount)

            refund_status =
              if Money.compare(new_refund_total, order.total) == :eq do
                :full
              else
                :partial
              end

            changeset
            |> Ash.Changeset.change_attribute(:refunded_amount, new_refund_total)
            |> Ash.Changeset.change_attribute(:refund_status, refund_status)
            |> Ash.Changeset.change_attribute(:refund_reason, reason)
        end
      end
    end

    read :list_orders do
      pagination offset?: true, default_limit: 25, max_limit: 100

      argument :status, :atom
      argument :start_date, :date
      argument :end_date, :date
      argument :search, :string
      argument :store_id, :uuid

      prepare build(sort: [inserted_at: :desc])

      filter expr(
        if is_nil(^arg(:status)) do
          true
        else
          status == ^arg(:status)
        end
      )

      filter expr(
        if is_nil(^arg(:search)) do
          true
        else
          contains(order_number, ^arg(:search))
        end
      )

      filter expr(
        if is_nil(^arg(:start_date)) do
          true
        else
          inserted_at >= ^arg(:start_date)
        end
      )

      filter expr(
        if is_nil(^arg(:end_date)) do
          true
        else
          inserted_at <= ^arg(:end_date)
        end
      )
    end

    read :queue do
      argument :store_id, :uuid

      filter expr(status in [:pending, :processing, :ready])
      prepare build(sort: [inserted_at: :asc], load: [:items, :customer])
    end
  end

  calculations do
    calculate :item_count, :integer do
      calculation expr(count(items))
    end
  end

  aggregates do
    sum :items_total, :items, :line_total
    count :item_count, :items
  end

  defp maybe_set_completed_at(changeset, :completed) do
    Ash.Changeset.change_attribute(changeset, :completed_at, DateTime.utc_now())
  end
  defp maybe_set_completed_at(changeset, _), do: changeset

  code_interface do
    domain Mcp.Commerce

    define :create
    define :update_status, args: [:new_status]
    define :refund, args: [:amount, :reason]
    define :list_orders
    define :queue, args: [:store_id]
    define :get, args: [:id]
  end
end
```

```elixir
# lib/mcp/commerce/order_item.ex
defmodule Mcp.Commerce.OrderItem do
  @moduledoc """
  Line item within an order.
  """
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Mcp.Commerce

  postgres do
    table "order_items"
    repo Mcp.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :integer, allow_nil?: false, default: 1
    attribute :unit_price, Mcp.Types.Money, allow_nil?: false
    attribute :line_total, Mcp.Types.Money
    attribute :notes, :string

    timestamps()
  end

  relationships do
    belongs_to :order, Mcp.Commerce.Order, allow_nil?: false
    belongs_to :product, Mcp.Catalog.Product
    belongs_to :variant, Mcp.Catalog.ProductVariant
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:quantity, :unit_price, :notes, :product_id, :variant_id]

      change fn changeset, _ ->
        quantity = Ash.Changeset.get_attribute(changeset, :quantity) || 1
        unit_price = Ash.Changeset.get_attribute(changeset, :unit_price)

        line_total = Money.multiply(unit_price, quantity)
        Ash.Changeset.change_attribute(changeset, :line_total, line_total)
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp/commerce/order_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp/commerce/order.ex lib/mcp/commerce/order_item.ex test/mcp/commerce/order_test.exs
git commit -m "feat(commerce): add Order resource with items, status flow, refunds"
```

---

## Task 2: Merchant Order List LiveView

**Files:**
- Create: `lib/mcp_web/live/merchant/orders/index_live.ex`
- Test: `test/mcp_web/live/merchant/orders/index_live_test.exs`

**Design Reference:** Merchant Features §3.1 Order List

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/merchant/orders/index_live_test.exs
defmodule McpWeb.Merchant.Orders.IndexLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "mount/3" do
    test "renders order list with page layout", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/orders")

      assert html =~ "Orders"
      assert has_element?(view, "[data-testid='page-layout-list']")
      assert has_element?(view, "[data-testid='action-sidebar']")
    end

    test "displays order stats", %{conn: conn} do
      insert(:order, status: :completed, total: Money.new(5000, :USD))
      insert(:order, status: :completed, total: Money.new(3000, :USD))
      insert(:order, status: :pending)

      {:ok, view, _html} = live(conn, ~p"/app/orders")

      assert has_element?(view, "[data-testid='stat-total-orders']", "3")
      assert has_element?(view, "[data-testid='stat-revenue']", "$80.00")
    end
  end

  describe "filtering" do
    test "filters by status", %{conn: conn} do
      insert(:order, order_number: "ORD-PENDING", status: :pending)
      insert(:order, order_number: "ORD-COMPLETED", status: :completed)

      {:ok, view, _html} = live(conn, ~p"/app/orders")

      view |> element("[data-testid='filter-status']") |> render_change(%{status: "pending"})

      assert has_element?(view, "[data-testid='order-row']", "ORD-PENDING")
      refute has_element?(view, "[data-testid='order-row']", "ORD-COMPLETED")
    end

    test "filters by date range", %{conn: conn} do
      insert(:order, order_number: "OLD", inserted_at: ~U[2026-01-01 10:00:00Z])
      insert(:order, order_number: "NEW", inserted_at: ~U[2026-01-10 10:00:00Z])

      {:ok, view, _html} = live(conn, ~p"/app/orders")

      view
      |> form("#date-filter", %{start_date: "2026-01-05", end_date: "2026-01-15"})
      |> render_change()

      assert has_element?(view, "[data-testid='order-row']", "NEW")
      refute has_element?(view, "[data-testid='order-row']", "OLD")
    end

    test "searches by order number", %{conn: conn} do
      insert(:order, order_number: "ORD-20260111-ABCD")
      insert(:order, order_number: "ORD-20260111-EFGH")

      {:ok, view, _html} = live(conn, ~p"/app/orders")

      view
      |> form("#search-form", %{search: "ABCD"})
      |> render_change()

      assert has_element?(view, "[data-testid='order-row']", "ABCD")
      refute has_element?(view, "[data-testid='order-row']", "EFGH")
    end
  end

  describe "navigation" do
    test "clicking order opens detail", %{conn: conn} do
      order = insert(:order)

      {:ok, view, _html} = live(conn, ~p"/app/orders")

      {:ok, _view, html} =
        view
        |> element("[data-testid='order-row'][phx-value-id='#{order.id}']")
        |> render_click()
        |> follow_redirect(conn, ~p"/app/orders/#{order.id}")

      assert html =~ order.order_number
    end
  end

  describe "export" do
    test "can export orders", %{conn: conn} do
      insert(:order)

      {:ok, view, _html} = live(conn, ~p"/app/orders")

      view |> element("[data-testid='export-btn']") |> render_click()

      # Would trigger download
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/live/merchant/orders/index_live_test.exs -v`
Expected: FAIL

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/live/merchant/orders/index_live.ex
defmodule McpWeb.Merchant.Orders.IndexLive do
  @moduledoc """
  Merchant portal order list with search, filters, and export.

  Uses PageLayout with list variant (2/3+1/3 split).

  Design reference: Merchant Features §3.1 Order List
  """
  use McpWeb, :live_view

  import McpWeb.Portal.PageLayout, only: [page_layout: 1]
  import McpWeb.Portal.StatsRow, only: [stats_row: 1, stat: 1]
  import McpWeb.Portal.ActionSidebar, only: [action_sidebar: 1, sidebar_action: 1, sidebar_filter: 1, ai_insight: 1]
  import McpWeb.Portal.DataTable, only: [data_table: 1, pagination: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1, button: 1]
  import McpWeb.Core.DataDisplay, only: [badge: 1]

  alias Mcp.Commerce.Order
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    {:ok, result} = Order.list_orders(%{page: 1, page_size: 25})
    stats = calculate_order_stats()

    socket =
      socket
      |> assign(:page_title, "Orders")
      |> assign(:orders, result.results)
      |> assign(:stats, stats)
      |> assign(:page, 1)
      |> assign(:total_pages, ceil(result.total_count / 25))
      |> assign(:total_count, result.total_count)
      |> assign(:search_query, "")
      |> assign(:filters, %{status: nil, start_date: nil, end_date: nil, store_id: nil})

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout variant={:list} title="Orders" data-testid="page-layout-list">
      <:stats>
        <.stats_row>
          <.stat
            data-testid="stat-total-orders"
            label="Total Orders"
            value={to_string(@stats.total_count)}
            icon="hero-shopping-bag"
          />
          <.stat
            data-testid="stat-revenue"
            label="Revenue"
            value={Money.to_string(@stats.total_revenue)}
            icon="hero-currency-dollar"
            trend={@stats.revenue_trend}
            comparison="vs last period"
          />
          <.stat
            label="Pending"
            value={to_string(@stats.pending_count)}
            icon="hero-clock"
            variant={if @stats.pending_count > 0, do: "warning"}
          />
          <.stat
            label="Avg Order"
            value={Money.to_string(@stats.avg_order_value)}
            icon="hero-chart-bar"
          />
        </.stats_row>
      </:stats>

      <:toolbar>
        <form id="search-form" phx-change="search" class="flex-1 max-w-md">
          <input
            type="text"
            name="search"
            value={@search_query}
            placeholder="Search orders..."
            class="input input-bordered w-full"
            phx-debounce="300"
          />
        </form>
        <form id="date-filter" phx-change="date_filter" class="flex gap-2">
          <input type="date" name="start_date" class="input input-bordered input-sm" />
          <input type="date" name="end_date" class="input input-bordered input-sm" />
        </form>
        <.button variant="ghost" phx-click="export" data-testid="export-btn">
          <.icon name="hero-arrow-down-tray" class="size-4 mr-2" /> Export
        </.button>
      </:toolbar>

      <:content>
        <.data_table
          id="orders-table"
          rows={@orders}
          row_click={fn order -> JS.navigate(~p"/app/orders/#{order.id}") end}
        >
          <:col :let={order} label="Order" field={:order_number}>
            <div data-testid="order-row" phx-value-id={order.id}>
              <div class="font-medium font-mono">{order.order_number}</div>
              <div class="text-sm text-base-content/50">{format_datetime(order.inserted_at)}</div>
            </div>
          </:col>

          <:col :let={order} label="Customer">
            <div :if={order.customer}>
              <div>{order.customer.name}</div>
              <div class="text-sm text-base-content/50">{order.customer.email}</div>
            </div>
            <span :if={!order.customer} class="text-base-content/50">Walk-in</span>
          </:col>

          <:col :let={order} label="Status">
            <.badge variant={status_variant(order.status)}>
              {order.status}
            </.badge>
          </:col>

          <:col :let={order} label="Items" align={:right}>
            {order.item_count} items
          </:col>

          <:col :let={order} label="Total" align={:right}>
            <div class="font-medium">{Money.to_string(order.total)}</div>
            <div :if={order.refund_status != :none} class="text-sm text-error">
              -{Money.to_string(order.refunded_amount)} refunded
            </div>
          </:col>

          <:col :let={order} label="Payment">
            <.badge variant="ghost">{order.payment_method}</.badge>
          </:col>
        </.data_table>

        <.pagination
          page={@page}
          total_pages={@total_pages}
          total_count={@total_count}
          per_page={25}
        />
      </:content>

      <:sidebar>
        <.action_sidebar data-testid="action-sidebar">
          <:actions>
            <.sidebar_action
              icon="hero-arrow-down-tray"
              label="Export Orders"
              phx-click="export"
            />
            <.sidebar_action
              icon="hero-chart-bar"
              label="View Reports"
              href={~p"/app/reports/sales"}
            />
          </:actions>

          <:filters>
            <.sidebar_filter
              label="Status"
              options={[
                {"All Statuses", ""},
                {"Pending", "pending"},
                {"Processing", "processing"},
                {"Ready", "ready"},
                {"Completed", "completed"},
                {"Cancelled", "cancelled"}
              ]}
              field={:status}
              value={@filters.status}
              phx-change="filter"
              data-testid="filter-status"
            />
            <.sidebar_filter
              label="Store"
              options={[{"All Stores", ""} | store_options()]}
              field={:store_id}
              value={@filters.store_id}
              phx-change="filter"
            />
          </:filters>

          <:insights>
            <.ai_insight
              :if={@stats.pending_count > 5}
              message="#{@stats.pending_count} orders awaiting processing"
              action="View queue"
              href={~p"/app/orders?status=pending"}
            />
            <div class="text-center text-sm text-base-content/50 py-4">
              AI insights coming in Phase 5
            </div>
          </:insights>
        </.action_sidebar>
      </:sidebar>
    </.page_layout>
    """
  end

  # Event handlers

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:ok, result} = Order.list_orders(%{
      search: query,
      status: socket.assigns.filters.status,
      page: 1
    })

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:orders, result.results)
     |> assign(:page, 1)
     |> assign(:total_count, result.total_count)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = %{
      status: get_filter_value(params, "status") |> maybe_to_atom(),
      store_id: get_filter_value(params, "store_id"),
      start_date: socket.assigns.filters.start_date,
      end_date: socket.assigns.filters.end_date
    }

    {:ok, result} = Order.list_orders(Map.merge(%{page: 1}, filters))

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:orders, result.results)
     |> assign(:page, 1)}
  end

  @impl true
  def handle_event("date_filter", %{"start_date" => start_date, "end_date" => end_date}, socket) do
    filters = %{
      socket.assigns.filters
      | start_date: parse_date(start_date),
        end_date: parse_date(end_date)
    }

    {:ok, result} = Order.list_orders(Map.merge(%{page: 1}, filters))

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:orders, result.results)
     |> assign(:page, 1)}
  end

  @impl true
  def handle_event("export", _params, socket) do
    {:noreply, put_flash(socket, :info, "Export started")}
  end

  # Helpers

  defp calculate_order_stats do
    # Would query aggregates
    %{
      total_count: 0,
      total_revenue: Money.new(0, :USD),
      revenue_trend: 5,
      pending_count: 0,
      avg_order_value: Money.new(0, :USD)
    }
  end

  defp status_variant(:pending), do: "warning"
  defp status_variant(:processing), do: "info"
  defp status_variant(:ready), do: "success"
  defp status_variant(:completed), do: "ghost"
  defp status_variant(:cancelled), do: "error"
  defp status_variant(_), do: nil

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%b %d, %Y %I:%M %p")
  end

  defp store_options do
    # Would load stores
    []
  end

  defp get_filter_value(params, key) do
    case Map.get(params, key) do
      "" -> nil
      nil -> nil
      value -> value
    end
  end

  defp maybe_to_atom(nil), do: nil
  defp maybe_to_atom(str) when is_binary(str), do: String.to_existing_atom(str)
  defp maybe_to_atom(other), do: other

  defp parse_date(""), do: nil
  defp parse_date(nil), do: nil
  defp parse_date(str), do: Date.from_iso8601!(str)
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/live/merchant/orders/index_live_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp_web/live/merchant/orders/index_live.ex test/mcp_web/live/merchant/orders/index_live_test.exs
git commit -m "feat(merchant): add Order List with search, filters, stats"
```

---

## Task 3: Merchant Order Detail LiveView

**Files:**
- Create: `lib/mcp_web/live/merchant/orders/show_live.ex`
- Test: `test/mcp_web/live/merchant/orders/show_live_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/merchant/orders/show_live_test.exs
defmodule McpWeb.Merchant.Orders.ShowLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "mount/3" do
    test "renders order detail", %{conn: conn} do
      order = insert(:order, order_number: "ORD-TEST-1234")

      {:ok, view, html} = live(conn, ~p"/app/orders/#{order.id}")

      assert html =~ "ORD-TEST-1234"
      assert has_element?(view, "[data-testid='page-layout-detail']")
    end

    test "displays order items", %{conn: conn} do
      product = insert(:product, name: "Premium Tee")
      order = insert(:order)
      insert(:order_item, order: order, product: product, quantity: 2, unit_price: Money.new(2999, :USD))

      {:ok, view, _html} = live(conn, ~p"/app/orders/#{order.id}")

      assert has_element?(view, "[data-testid='order-item']", "Premium Tee")
      assert has_element?(view, "[data-testid='item-quantity']", "2")
    end

    test "displays customer info when present", %{conn: conn} do
      customer = insert(:customer, name: "John Doe", email: "john@example.com")
      order = insert(:order, customer: customer)

      {:ok, view, _html} = live(conn, ~p"/app/orders/#{order.id}")

      assert has_element?(view, "[data-testid='customer-name']", "John Doe")
      assert has_element?(view, "[data-testid='customer-email']", "john@example.com")
    end
  end

  describe "status updates" do
    test "can advance order status", %{conn: conn} do
      order = insert(:order, status: :pending)

      {:ok, view, _html} = live(conn, ~p"/app/orders/#{order.id}")

      view |> element("[data-testid='advance-status-btn']") |> render_click()

      assert has_element?(view, "[data-testid='status-badge']", "processing")
    end
  end

  describe "refunds" do
    test "opens refund modal", %{conn: conn} do
      order = insert(:order, status: :completed)

      {:ok, view, _html} = live(conn, ~p"/app/orders/#{order.id}")

      view |> element("[data-testid='refund-btn']") |> render_click()

      assert has_element?(view, "[data-testid='refund-modal']")
    end

    test "processes full refund", %{conn: conn} do
      order = insert(:order, status: :completed, total: Money.new(5000, :USD))

      {:ok, view, _html} = live(conn, ~p"/app/orders/#{order.id}")

      view |> element("[data-testid='refund-btn']") |> render_click()

      view
      |> form("#refund-form", refund: %{type: "full", reason: "Customer request"})
      |> render_submit()

      assert has_element?(view, "[data-testid='refund-status']", "Full Refund")
    end

    test "processes partial refund", %{conn: conn} do
      order = insert(:order, status: :completed, total: Money.new(5000, :USD))

      {:ok, view, _html} = live(conn, ~p"/app/orders/#{order.id}")

      view |> element("[data-testid='refund-btn']") |> render_click()

      view
      |> form("#refund-form", refund: %{type: "partial", amount: "20.00", reason: "Item returned"})
      |> render_submit()

      assert has_element?(view, "[data-testid='refund-status']", "Partial Refund")
      assert has_element?(view, "[data-testid='refunded-amount']", "$20.00")
    end
  end

  describe "order timeline" do
    test "shows status history", %{conn: conn} do
      order = insert(:order)
      insert(:order_status_history, order: order, status: :pending, changed_at: ~U[2026-01-01 10:00:00Z])
      insert(:order_status_history, order: order, status: :processing, changed_at: ~U[2026-01-01 10:05:00Z])

      {:ok, view, _html} = live(conn, ~p"/app/orders/#{order.id}")

      assert has_element?(view, "[data-testid='status-timeline']")
      assert has_element?(view, "[data-testid='timeline-event']", "pending")
      assert has_element?(view, "[data-testid='timeline-event']", "processing")
    end
  end
end
```

**Step 2-5:** Follow TDD pattern with full implementation.

**Step 5: Commit**

```bash
git add lib/mcp_web/live/merchant/orders/show_live.ex test/mcp_web/live/merchant/orders/show_live_test.exs
git commit -m "feat(merchant): add Order Detail with timeline, refunds"
```

---

## Task 4: Store Order Queue LiveView

**Files:**
- Create: `lib/mcp_web/live/store/orders/queue_live.ex`
- Test: `test/mcp_web/live/store/orders/queue_live_test.exs`

**Design Reference:** Store Features §3.1 Order Queue

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/store/orders/queue_live_test.exs
defmodule McpWeb.Store.Orders.QueueLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_store_user

  describe "mount/3" do
    test "renders order queue in kanban style", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/store/orders")

      assert html =~ "Order Queue"
      assert has_element?(view, "[data-testid='queue-column-pending']")
      assert has_element?(view, "[data-testid='queue-column-processing']")
      assert has_element?(view, "[data-testid='queue-column-ready']")
    end

    test "displays orders in correct columns", %{conn: conn} do
      insert(:order, order_number: "PENDING-1", status: :pending)
      insert(:order, order_number: "PROCESSING-1", status: :processing)
      insert(:order, order_number: "READY-1", status: :ready)

      {:ok, view, _html} = live(conn, ~p"/store/orders")

      assert has_element?(view, "[data-testid='queue-column-pending'] [data-testid='order-card']", "PENDING-1")
      assert has_element?(view, "[data-testid='queue-column-processing'] [data-testid='order-card']", "PROCESSING-1")
      assert has_element?(view, "[data-testid='queue-column-ready'] [data-testid='order-card']", "READY-1")
    end
  end

  describe "order actions" do
    test "can start processing order", %{conn: conn} do
      order = insert(:order, status: :pending)

      {:ok, view, _html} = live(conn, ~p"/store/orders")

      view |> element("[data-testid='start-btn-#{order.id}']") |> render_click()

      assert has_element?(view, "[data-testid='queue-column-processing'] [data-testid='order-card']", order.order_number)
    end

    test "can mark order ready", %{conn: conn} do
      order = insert(:order, status: :processing)

      {:ok, view, _html} = live(conn, ~p"/store/orders")

      view |> element("[data-testid='ready-btn-#{order.id}']") |> render_click()

      assert has_element?(view, "[data-testid='queue-column-ready'] [data-testid='order-card']", order.order_number)
    end

    test "can complete order", %{conn: conn} do
      order = insert(:order, status: :ready)

      {:ok, view, _html} = live(conn, ~p"/store/orders")

      view |> element("[data-testid='complete-btn-#{order.id}']") |> render_click()

      refute has_element?(view, "[data-testid='order-card']", order.order_number)
    end
  end

  describe "real-time updates" do
    test "receives new orders via pubsub", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/store/orders")

      # Simulate new order being created
      order = insert(:order, status: :pending)
      Phoenix.PubSub.broadcast(Mcp.PubSub, "orders:queue", {:new_order, order})

      # Wait for update
      :timer.sleep(50)

      assert has_element?(view, "[data-testid='order-card']", order.order_number)
    end
  end

  describe "order details" do
    test "clicking order shows detail panel", %{conn: conn} do
      order = insert(:order)
      insert(:order_item, order: order, quantity: 2)

      {:ok, view, _html} = live(conn, ~p"/store/orders")

      view |> element("[data-testid='order-card-#{order.id}']") |> render_click()

      assert has_element?(view, "[data-testid='order-detail-panel']")
      assert has_element?(view, "[data-testid='order-items']")
    end
  end
end
```

**Step 2-5:** Follow TDD pattern.

**Step 5: Commit**

```bash
git add lib/mcp_web/live/store/orders/queue_live.ex test/mcp_web/live/store/orders/queue_live_test.exs
git commit -m "feat(store): add Order Queue kanban with real-time updates"
```

---

## Task 5: Sales Report LiveView

**Files:**
- Create: `lib/mcp_web/live/merchant/reports/sales_live.ex`
- Test: `test/mcp_web/live/merchant/reports/sales_live_test.exs`

**Design Reference:** Merchant Features §4.1 Sales Report

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/merchant/reports/sales_live_test.exs
defmodule McpWeb.Merchant.Reports.SalesLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "mount/3" do
    test "renders sales report with chart", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/reports/sales")

      assert html =~ "Sales Report"
      assert has_element?(view, "[data-testid='page-layout-table']")
      assert has_element?(view, "[data-testid='sales-chart']")
    end

    test "displays summary metrics", %{conn: conn} do
      # Create some orders
      insert(:order, status: :completed, total: Money.new(5000, :USD))
      insert(:order, status: :completed, total: Money.new(3000, :USD))

      {:ok, view, _html} = live(conn, ~p"/app/reports/sales")

      assert has_element?(view, "[data-testid='metric-total-sales']")
      assert has_element?(view, "[data-testid='metric-order-count']")
      assert has_element?(view, "[data-testid='metric-avg-order']")
    end
  end

  describe "date range" do
    test "defaults to last 30 days", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/reports/sales")

      assert has_element?(view, "[data-testid='period-selector'] option[selected]", "Last 30 Days")
    end

    test "can change to custom date range", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/reports/sales")

      view
      |> form("#period-form", %{period: "custom", start_date: "2026-01-01", end_date: "2026-01-15"})
      |> render_change()

      # Chart should update
      assert has_element?(view, "[data-testid='sales-chart']")
    end
  end

  describe "grouping" do
    test "can group by day", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/reports/sales")

      view |> element("[data-testid='group-by-day']") |> render_click()

      assert has_element?(view, "[data-testid='grouping-indicator']", "Daily")
    end

    test "can group by week", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/reports/sales")

      view |> element("[data-testid='group-by-week']") |> render_click()

      assert has_element?(view, "[data-testid='grouping-indicator']", "Weekly")
    end
  end

  describe "breakdown table" do
    test "shows sales breakdown by category", %{conn: conn} do
      category = insert(:category, name: "Apparel")
      product = insert(:product, category: category)
      order = insert(:order, status: :completed)
      insert(:order_item, order: order, product: product, quantity: 5, unit_price: Money.new(2000, :USD))

      {:ok, view, _html} = live(conn, ~p"/app/reports/sales")

      assert has_element?(view, "[data-testid='breakdown-row']", "Apparel")
    end
  end

  describe "export" do
    test "can export to CSV", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/reports/sales")

      view |> element("[data-testid='export-csv']") |> render_click()

      # Would trigger download
    end

    test "can export to PDF", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/reports/sales")

      view |> element("[data-testid='export-pdf']") |> render_click()

      # Would trigger download
    end
  end
end
```

**Step 2-5:** Follow TDD pattern.

**Step 5: Commit**

```bash
git add lib/mcp_web/live/merchant/reports/sales_live.ex test/mcp_web/live/merchant/reports/sales_live_test.exs
git commit -m "feat(merchant): add Sales Report with charts, date ranges, export"
```

---

## Task 6: Payments Report LiveView

**Files:**
- Create: `lib/mcp_web/live/merchant/reports/payments_live.ex`
- Test: `test/mcp_web/live/merchant/reports/payments_live_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/merchant/reports/payments_live_test.exs
defmodule McpWeb.Merchant.Reports.PaymentsLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "mount/3" do
    test "renders payments report", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/reports/payments")

      assert html =~ "Payments Report"
      assert has_element?(view, "[data-testid='page-layout-table']")
    end

    test "shows payment method breakdown", %{conn: conn} do
      insert(:order, status: :completed, payment_method: :card, total: Money.new(5000, :USD))
      insert(:order, status: :completed, payment_method: :card, total: Money.new(3000, :USD))
      insert(:order, status: :completed, payment_method: :cash, total: Money.new(2000, :USD))

      {:ok, view, _html} = live(conn, ~p"/app/reports/payments")

      assert has_element?(view, "[data-testid='payment-method-card']")
      assert has_element?(view, "[data-testid='payment-method-cash']")
    end
  end

  describe "settlement info" do
    test "shows pending settlements", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/reports/payments")

      assert has_element?(view, "[data-testid='pending-settlements']")
    end

    test "shows settlement history", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/reports/payments")

      assert has_element?(view, "[data-testid='settlement-history']")
    end
  end

  describe "refunds" do
    test "shows refund summary", %{conn: conn} do
      insert(:order, status: :completed, refund_status: :full, refunded_amount: Money.new(5000, :USD))
      insert(:order, status: :completed, refund_status: :partial, refunded_amount: Money.new(2000, :USD))

      {:ok, view, _html} = live(conn, ~p"/app/reports/payments")

      assert has_element?(view, "[data-testid='refund-summary']")
      assert has_element?(view, "[data-testid='total-refunded']", "$70.00")
    end
  end
end
```

**Step 2-5:** Follow TDD pattern.

**Step 5: Commit**

```bash
git add lib/mcp_web/live/merchant/reports/payments_live.ex test/mcp_web/live/merchant/reports/payments_live_test.exs
git commit -m "feat(merchant): add Payments Report with settlement tracking"
```

---

## Task 7: Store Daily Summary Dashboard

**Files:**
- Create: `lib/mcp_web/live/store/dashboard_live.ex`
- Test: `test/mcp_web/live/store/dashboard_live_test.exs`

**Design Reference:** Store Features §4.1 Daily Summary

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/store/dashboard_live_test.exs
defmodule McpWeb.Store.DashboardLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_store_user

  describe "mount/3" do
    test "renders daily summary dashboard", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/store")

      assert html =~ "Daily Summary"
      assert has_element?(view, "[data-testid='page-layout-dashboard']")
    end

    test "shows today's metrics", %{conn: conn} do
      # Create today's orders
      insert(:order, status: :completed, total: Money.new(5000, :USD), inserted_at: DateTime.utc_now())
      insert(:order, status: :completed, total: Money.new(3000, :USD), inserted_at: DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/store")

      assert has_element?(view, "[data-testid='today-sales']")
      assert has_element?(view, "[data-testid='today-orders']", "2")
    end
  end

  describe "quick actions" do
    test "has POS link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/store")

      assert has_element?(view, "[data-testid='pos-link']")
    end

    test "has terminal link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/store")

      assert has_element?(view, "[data-testid='terminal-link']")
    end

    test "has order queue link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/store")

      assert has_element?(view, "[data-testid='queue-link']")
    end
  end

  describe "pending orders widget" do
    test "shows count of pending orders", %{conn: conn} do
      insert(:order, status: :pending)
      insert(:order, status: :pending)
      insert(:order, status: :processing)

      {:ok, view, _html} = live(conn, ~p"/store")

      assert has_element?(view, "[data-testid='pending-count']", "3")
    end
  end

  describe "recent transactions" do
    test "lists recent completed orders", %{conn: conn} do
      insert(:order, order_number: "ORD-RECENT", status: :completed)

      {:ok, view, _html} = live(conn, ~p"/store")

      assert has_element?(view, "[data-testid='recent-transactions']")
      assert has_element?(view, "[data-testid='transaction-row']", "ORD-RECENT")
    end
  end
end
```

**Step 2-5:** Follow TDD pattern.

**Step 5: Commit**

```bash
git add lib/mcp_web/live/store/dashboard_live.ex test/mcp_web/live/store/dashboard_live_test.exs
git commit -m "feat(store): add Daily Summary dashboard with metrics, quick actions"
```

---

## Task 8: Add Routes

**Step 1: Update router.ex**

```elixir
# In merchant scope
scope "/app", McpWeb.Merchant, as: :merchant do
  pipe_through [:browser, :require_authenticated_user, :require_merchant]

  # Orders
  live "/orders", Orders.IndexLive, :index
  live "/orders/:id", Orders.ShowLive, :show

  # Reports
  live "/reports/sales", Reports.SalesLive, :sales
  live "/reports/payments", Reports.PaymentsLive, :payments
end

# In store scope
scope "/store", McpWeb.Store, as: :store do
  pipe_through [:browser, :require_authenticated_user, :require_store_staff]

  # Dashboard
  live "/", DashboardLive, :index

  # Orders
  live "/orders", Orders.QueueLive, :queue
  live "/orders/:id", Orders.ShowLive, :show
end
```

**Step 2: Verify compile**

Run: `mix compile --warnings-as-errors`
Expected: No warnings

**Step 3: Commit**

```bash
git add lib/mcp_web/router.ex
git commit -m "feat(routes): add Phase 4 order and report routes"
```

---

## Success Criteria

Phase 4 is complete when:

- [ ] All tests pass (`mix test`)
- [ ] `mix precommit` passes
- [ ] Order CRUD works end-to-end
- [ ] Order status flow works (pending -> processing -> ready -> completed)
- [ ] Refunds work (partial and full)
- [ ] Order Queue shows real-time updates
- [ ] Sales Report displays charts and breakdown
- [ ] Payments Report shows settlement info
- [ ] Store Dashboard shows daily metrics
- [ ] All pages use Phase 1 layout components correctly

---

## Quality Gates Between Tasks

After each task, run:

```bash
mix test test/path/to/new_test.exs  # New tests pass
mix compile --warnings-as-errors     # No warnings
mix format --check-formatted         # Code formatted
```

Before moving to next phase, run:

```bash
mix precommit  # Full quality check
```
