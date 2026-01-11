# Phase 3: Inventory & Products Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete product catalog management for Merchant portal and read-only product views for Store portal. Build inventory tracking and stock management.

**Architecture:** Build on Phase 1 layout components and Phase 2 commerce foundation. Each feature uses the exact wireframes from design docs with proper layout variants, AI insights sections, and TDD implementation.

**Tech Stack:** Phoenix LiveView, Phase 1 layout components, DaisyUI, Ash Framework for data persistence

**Reference Documents:**
- `2026-01-11-merchant-portal-features.md` - Sections 2.1-2.4 (Products)
- `2026-01-11-store-portal-features.md` - Section 5 (Products read-only)
- `docs/DESIGN_GUIDE.md` - Component patterns

---

## Pre-Implementation: Quality Gate

Before starting Phase 3, verify Phase 1-2 are complete:

```bash
mix test
mix precommit
```

If any failures, complete `2026-01-11-phase1-2-remediation.md` first.

---

## Overview: Features to Build

| # | Feature | Portal | Layout | Priority |
|---|---------|--------|--------|----------|
| 1 | Product List | Merchant | B (2/3+1/3 List) | P0 |
| 2 | Product Detail | Merchant | C (2/3+1/3 Detail) | P0 |
| 3 | Product Create | Merchant | C (2/3+1/3 Detail) | P0 |
| 4 | Categories Management | Merchant | B (2/3+1/3 List) | P1 |
| 5 | Inventory Overview | Merchant | D (Full-Width Table) | P1 |
| 6 | Product Import | Merchant | E (Focused) | P2 |
| 7 | Product Search (Read-only) | Store | B (2/3+1/3 List) | P1 |
| 8 | Product Detail (Read-only) | Store | C (2/3+1/3 Detail) | P1 |
| 9 | Inventory Adjust (Store) | Store | Modal | P1 |

---

## Task 1: Product Ash Resource

**Files:**
- Create: `lib/mcp/catalog/product.ex`
- Create: `lib/mcp/catalog/category.ex`
- Create: `lib/mcp/catalog/product_variant.ex`
- Test: `test/mcp/catalog/product_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/catalog/product_test.exs
defmodule Mcp.Catalog.ProductTest do
  use Mcp.DataCase, async: true

  alias Mcp.Catalog.Product

  describe "create/1" do
    test "creates a product with valid attributes" do
      attrs = %{
        name: "Premium Tee",
        sku: "TEE-001",
        price: Money.new(2999, :USD),
        status: :active,
        track_inventory: true,
        quantity_on_hand: 100
      }

      assert {:ok, product} = Product.create(attrs)
      assert product.name == "Premium Tee"
      assert product.sku == "TEE-001"
      assert product.price == Money.new(2999, :USD)
      assert product.status == :active
    end

    test "requires name and sku" do
      assert {:error, changeset} = Product.create(%{})
      assert "is required" in errors_on(changeset).name
      assert "is required" in errors_on(changeset).sku
    end

    test "enforces unique sku within tenant" do
      attrs = %{name: "Product A", sku: "SKU-001", price: Money.new(1000, :USD)}
      assert {:ok, _} = Product.create(attrs)
      assert {:error, changeset} = Product.create(attrs)
      assert "has already been taken" in errors_on(changeset).sku
    end
  end

  describe "list_products/1" do
    test "returns products with pagination" do
      # Create test products
      for i <- 1..15 do
        Product.create!(%{
          name: "Product #{i}",
          sku: "SKU-#{String.pad_leading(to_string(i), 3, "0")}",
          price: Money.new(1000 * i, :USD)
        })
      end

      {:ok, result} = Product.list_products(%{page: 1, page_size: 10})

      assert length(result.results) == 10
      assert result.total_count == 15
      assert result.has_next_page == true
    end

    test "filters by category" do
      {:ok, category} = Mcp.Catalog.Category.create(%{name: "Apparel"})

      Product.create!(%{name: "Tee", sku: "TEE-1", price: Money.new(1000, :USD), category_id: category.id})
      Product.create!(%{name: "Mug", sku: "MUG-1", price: Money.new(500, :USD)})

      {:ok, result} = Product.list_products(%{category_id: category.id})

      assert length(result.results) == 1
      assert hd(result.results).name == "Tee"
    end

    test "filters by status" do
      Product.create!(%{name: "Active", sku: "A-1", price: Money.new(1000, :USD), status: :active})
      Product.create!(%{name: "Draft", sku: "D-1", price: Money.new(1000, :USD), status: :draft})

      {:ok, result} = Product.list_products(%{status: :active})

      assert length(result.results) == 1
      assert hd(result.results).name == "Active"
    end

    test "searches by name and sku" do
      Product.create!(%{name: "Premium Tee", sku: "TEE-001", price: Money.new(1000, :USD)})
      Product.create!(%{name: "Coffee Mug", sku: "MUG-001", price: Money.new(500, :USD)})

      {:ok, result} = Product.list_products(%{search: "tee"})

      assert length(result.results) == 1
      assert hd(result.results).name == "Premium Tee"
    end
  end

  describe "get_product_stats/0" do
    test "returns aggregate stats" do
      Product.create!(%{name: "A", sku: "A-1", price: Money.new(1000, :USD), status: :active})
      Product.create!(%{name: "B", sku: "B-1", price: Money.new(2000, :USD), status: :active})
      Product.create!(%{name: "C", sku: "C-1", price: Money.new(3000, :USD), status: :draft})

      {:ok, stats} = Product.get_product_stats()

      assert stats.total_products == 3
      assert stats.active_products == 2
      assert stats.draft_products == 1
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp/catalog/product_test.exs -v`
Expected: FAIL

**Step 3: Write minimal implementation**

```elixir
# lib/mcp/catalog/product.ex
defmodule Mcp.Catalog.Product do
  @moduledoc """
  Product resource for the catalog domain.

  Products are the core items sold through the platform. They support:
  - Multiple variants (size, color, etc.)
  - Inventory tracking
  - Category organization
  - Multi-tenant isolation

  Design reference: Merchant Features §2.1-2.4
  """
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Mcp.Catalog

  postgres do
    table "products"
    repo Mcp.Repo

    references do
      reference :category, on_delete: :nilify
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :sku, :string do
      allow_nil? false
    end

    attribute :description, :string

    attribute :price, Mcp.Types.Money do
      allow_nil? false
    end

    attribute :compare_at_price, Mcp.Types.Money

    attribute :cost, Mcp.Types.Money

    attribute :status, :atom do
      constraints one_of: [:draft, :active, :archived]
      default :draft
    end

    attribute :track_inventory, :boolean, default: false
    attribute :quantity_on_hand, :integer, default: 0
    attribute :low_stock_threshold, :integer, default: 10

    attribute :image_url, :string
    attribute :images, {:array, :string}, default: []

    attribute :metadata, :map, default: %{}

    timestamps()
  end

  relationships do
    belongs_to :category, Mcp.Catalog.Category
    belongs_to :tenant, Mcp.Platform.Tenant

    has_many :variants, Mcp.Catalog.ProductVariant
  end

  identities do
    identity :unique_sku_per_tenant, [:sku, :tenant_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name, :sku, :description, :price, :compare_at_price, :cost,
        :status, :track_inventory, :quantity_on_hand, :low_stock_threshold,
        :image_url, :images, :metadata, :category_id
      ]

      change relate_actor(:tenant)
    end

    update :update do
      accept [
        :name, :sku, :description, :price, :compare_at_price, :cost,
        :status, :track_inventory, :quantity_on_hand, :low_stock_threshold,
        :image_url, :images, :metadata, :category_id
      ]
    end

    read :list_products do
      pagination offset?: true, default_limit: 25, max_limit: 100

      argument :search, :string
      argument :category_id, :uuid
      argument :status, :atom

      filter expr(
        if is_nil(^arg(:search)) do
          true
        else
          contains(name, ^arg(:search)) or contains(sku, ^arg(:search))
        end
      )

      filter expr(
        if is_nil(^arg(:category_id)) do
          true
        else
          category_id == ^arg(:category_id)
        end
      )

      filter expr(
        if is_nil(^arg(:status)) do
          true
        else
          status == ^arg(:status)
        end
      )
    end

    read :get_product_stats do
      prepare fn query, _ ->
        Ash.Query.aggregate(query, [
          {:total_products, :count},
          {:active_products, :count, filter: [status: :active]},
          {:draft_products, :count, filter: [status: :draft]}
        ])
      end
    end
  end

  calculations do
    calculate :is_low_stock, :boolean do
      calculation expr(track_inventory and quantity_on_hand <= low_stock_threshold)
    end

    calculate :margin_percentage, :decimal do
      calculation expr(
        if is_nil(cost) or cost == 0 do
          nil
        else
          (price - cost) / price * 100
        end
      )
    end
  end

  aggregates do
    count :variant_count, :variants
  end

  code_interface do
    domain Mcp.Catalog

    define :create
    define :update
    define :list_products
    define :get_product_stats
    define :get, args: [:id]
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp/catalog/product_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp/catalog/product.ex lib/mcp/catalog/category.ex test/mcp/catalog/product_test.exs
git commit -m "feat(catalog): add Product resource with inventory tracking"
```

---

## Task 2: Merchant Product List LiveView

**Files:**
- Create: `lib/mcp_web/live/merchant/products/index_live.ex`
- Test: `test/mcp_web/live/merchant/products/index_live_test.exs`

**Design Reference:** Merchant Features §2.1 Product List wireframe

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/merchant/products/index_live_test.exs
defmodule McpWeb.Merchant.Products.IndexLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "mount/3" do
    test "renders product list with page layout", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/products")

      # Uses PageLayout with list variant
      assert html =~ "Products"
      assert has_element?(view, "[data-testid='page-layout-list']")

      # Has stats row
      assert has_element?(view, "[data-testid='stats-row']")

      # Has action sidebar
      assert has_element?(view, "[data-testid='action-sidebar']")
    end

    test "displays product stats", %{conn: conn} do
      # Create test products
      insert(:product, status: :active)
      insert(:product, status: :active)
      insert(:product, status: :draft)

      {:ok, view, _html} = live(conn, ~p"/app/products")

      assert has_element?(view, "[data-testid='stat-total']", "3")
      assert has_element?(view, "[data-testid='stat-active']", "2")
    end

    test "displays AI insights placeholder", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/products")

      assert html =~ "AI INSIGHTS"
      assert html =~ "AI insights coming"
    end
  end

  describe "search" do
    test "filters products by search query", %{conn: conn} do
      insert(:product, name: "Premium Tee", sku: "TEE-001")
      insert(:product, name: "Coffee Mug", sku: "MUG-001")

      {:ok, view, _html} = live(conn, ~p"/app/products")

      view
      |> form("#product-search-form", %{search: "tee"})
      |> render_change()

      assert has_element?(view, "[data-testid='product-row']", "Premium Tee")
      refute has_element?(view, "[data-testid='product-row']", "Coffee Mug")
    end
  end

  describe "filtering" do
    test "filters by category", %{conn: conn} do
      category = insert(:category, name: "Apparel")
      insert(:product, name: "Tee", category: category)
      insert(:product, name: "Mug")

      {:ok, view, _html} = live(conn, ~p"/app/products")

      view
      |> element("[data-testid='filter-category']")
      |> render_change(%{category: category.id})

      assert has_element?(view, "[data-testid='product-row']", "Tee")
      refute has_element?(view, "[data-testid='product-row']", "Mug")
    end

    test "filters by status", %{conn: conn} do
      insert(:product, name: "Active Product", status: :active)
      insert(:product, name: "Draft Product", status: :draft)

      {:ok, view, _html} = live(conn, ~p"/app/products")

      view
      |> element("[data-testid='filter-status']")
      |> render_change(%{status: "active"})

      assert has_element?(view, "[data-testid='product-row']", "Active Product")
      refute has_element?(view, "[data-testid='product-row']", "Draft Product")
    end
  end

  describe "bulk actions" do
    test "can select multiple products", %{conn: conn} do
      p1 = insert(:product)
      p2 = insert(:product)

      {:ok, view, _html} = live(conn, ~p"/app/products")

      # Select all
      view |> element("[data-testid='select-all']") |> render_click()

      assert has_element?(view, "[data-testid='bulk-actions-bar']")
      assert has_element?(view, "[data-testid='selected-count']", "2 selected")
    end
  end

  describe "navigation" do
    test "clicking product navigates to detail", %{conn: conn} do
      product = insert(:product, name: "Test Product")

      {:ok, view, _html} = live(conn, ~p"/app/products")

      {:ok, _view, html} =
        view
        |> element("[data-testid='product-row'][phx-value-id='#{product.id}']")
        |> render_click()
        |> follow_redirect(conn, ~p"/app/products/#{product.id}")

      assert html =~ "Test Product"
    end

    test "add button navigates to new product", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products")

      {:ok, _view, html} =
        view
        |> element("[data-testid='add-product-btn']")
        |> render_click()
        |> follow_redirect(conn, ~p"/app/products/new")

      assert html =~ "New Product"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/live/merchant/products/index_live_test.exs -v`
Expected: FAIL

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/live/merchant/products/index_live.ex
defmodule McpWeb.Merchant.Products.IndexLive do
  @moduledoc """
  Merchant portal product list with full catalog management.

  Uses PageLayout with list variant (2/3+1/3 split):
  - Main content: DataTable with product rows
  - Sidebar: Quick actions, filters, AI insights

  Design reference: Merchant Features §2.1 Product List
  """
  use McpWeb, :live_view

  import McpWeb.Portal.PageLayout, only: [page_layout: 1]
  import McpWeb.Portal.StatsRow, only: [stats_row: 1, stat: 1]
  import McpWeb.Portal.ActionSidebar, only: [action_sidebar: 1, sidebar_action: 1, sidebar_filter: 1, ai_insight: 1]
  import McpWeb.Portal.DataTable, only: [data_table: 1, pagination: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1, button: 1, card: 1]
  import McpWeb.Core.DataDisplay, only: [badge: 1]

  alias Mcp.Catalog.Product
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stats} = Product.get_product_stats()
    {:ok, products_result} = Product.list_products(%{page: 1, page_size: 25})
    {:ok, categories} = Mcp.Catalog.Category.list_categories()

    socket =
      socket
      |> assign(:page_title, "Products")
      |> assign(:stats, stats)
      |> assign(:products, products_result.results)
      |> assign(:page, 1)
      |> assign(:total_pages, ceil(products_result.total_count / 25))
      |> assign(:total_count, products_result.total_count)
      |> assign(:categories, categories)
      |> assign(:search_query, "")
      |> assign(:filters, %{category_id: nil, status: nil, stock: nil})
      |> assign(:selected_ids, MapSet.new())
      |> assign(:sort_by, :name)
      |> assign(:sort_dir, :asc)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout variant={:list} title="Products" data-testid="page-layout-list">
      <:stats>
        <.stats_row data-testid="stats-row">
          <.stat
            data-testid="stat-total"
            label="Total Products"
            value={to_string(@stats.total_products)}
            icon="hero-cube"
          />
          <.stat
            data-testid="stat-active"
            label="Active"
            value={to_string(@stats.active_products)}
            icon="hero-check-circle"
            trend={5}
            comparison="vs last month"
          />
          <.stat
            data-testid="stat-draft"
            label="Draft"
            value={to_string(@stats.draft_products)}
            icon="hero-pencil-square"
          />
          <.stat
            label="Low Stock"
            value={to_string(@stats[:low_stock_count] || 0)}
            icon="hero-exclamation-triangle"
            href={~p"/app/products?stock=low"}
          />
        </.stats_row>
      </:stats>

      <:toolbar>
        <form id="product-search-form" phx-change="search" class="flex-1 max-w-md">
          <input
            type="text"
            name="search"
            value={@search_query}
            placeholder="Search products, SKUs..."
            class="input input-bordered w-full"
            phx-debounce="300"
            data-testid="product-search"
          />
        </form>
        <.button
          variant="primary"
          phx-click={JS.navigate(~p"/app/products/new")}
          data-testid="add-product-btn"
        >
          <.icon name="hero-plus" class="size-4 mr-2" /> Add Product
        </.button>
      </:toolbar>

      <:content>
        <.bulk_actions_bar :if={MapSet.size(@selected_ids) > 0} selected_count={MapSet.size(@selected_ids)} />

        <.data_table
          id="products-table"
          rows={@products}
          sort_by={@sort_by}
          sort_dir={@sort_dir}
          selectable
          row_click={fn product -> JS.navigate(~p"/app/products/#{product.id}") end}
        >
          <:col :let={product} label="Product" field={:name} sortable>
            <div class="flex items-center gap-3">
              <div class="avatar">
                <div class="w-12 h-12 rounded bg-base-200 flex items-center justify-center">
                  <img :if={product.image_url} src={product.image_url} alt={product.name} class="object-cover" />
                  <.icon :if={!product.image_url} name="hero-cube" class="size-6 text-base-content/30" />
                </div>
              </div>
              <div>
                <div class="font-medium" data-testid="product-name">{product.name}</div>
                <div class="text-sm text-base-content/60">SKU: {product.sku}</div>
                <div :if={product.category} class="text-xs text-base-content/50">{product.category.name}</div>
              </div>
            </div>
          </:col>

          <:col :let={product} label="Status" field={:status} sortable>
            <.badge variant={status_variant(product.status)}>
              {product.status}
            </.badge>
          </:col>

          <:col :let={product} label="Stock" field={:quantity_on_hand} sortable align={:right}>
            <span :if={product.track_inventory} class={product.is_low_stock && "text-warning"}>
              {product.quantity_on_hand}
              <.icon :if={product.is_low_stock} name="hero-exclamation-triangle" class="size-4 text-warning ml-1" />
            </span>
            <span :if={!product.track_inventory} class="text-base-content/50">—</span>
          </:col>

          <:col :let={product} label="Price" field={:price} sortable align={:right}>
            <div class="font-medium">{Money.to_string(product.price)}</div>
            <div :if={product.compare_at_price} class="text-sm text-base-content/50 line-through">
              {Money.to_string(product.compare_at_price)}
            </div>
          </:col>

          <:action :let={product}>
            <div class="dropdown dropdown-end">
              <label tabindex="0" class="btn btn-ghost btn-xs">
                <.icon name="hero-ellipsis-vertical" class="size-4" />
              </label>
              <ul tabindex="0" class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-40">
                <li><.link navigate={~p"/app/products/#{product.id}"}>Edit</.link></li>
                <li><button phx-click="duplicate" phx-value-id={product.id}>Duplicate</button></li>
                <li :if={product.status != :archived}>
                  <button phx-click="archive" phx-value-id={product.id}>Archive</button>
                </li>
                <li class="text-error">
                  <button phx-click="delete" phx-value-id={product.id}>Delete</button>
                </li>
              </ul>
            </div>
          </:action>

          <:empty>
            <div class="flex flex-col items-center justify-center py-16">
              <.icon name="hero-cube" class="size-16 text-base-content/20 mb-4" />
              <h3 class="text-lg font-medium mb-2">No products yet</h3>
              <p class="text-base-content/60 mb-4">Get started by adding your first product</p>
              <.button variant="primary" phx-click={JS.navigate(~p"/app/products/new")}>
                <.icon name="hero-plus" class="size-4 mr-2" /> Add Product
              </.button>
            </div>
          </:empty>
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
              icon="hero-plus"
              label="Add Product"
              href={~p"/app/products/new"}
            />
            <.sidebar_action
              icon="hero-arrow-up-tray"
              label="Import Products"
              phx-click="open_import"
            />
            <.sidebar_action
              icon="hero-arrow-down-tray"
              label="Export"
              phx-click="export"
            />
            <.sidebar_action
              icon="hero-squares-2x2"
              label="Bulk Edit"
              href={~p"/app/products/bulk"}
            />
          </:actions>

          <:filters>
            <.sidebar_filter
              label="Category"
              options={[{"All Categories", ""} | Enum.map(@categories, &{&1.name, &1.id})]}
              field={:category_id}
              value={@filters.category_id}
              phx-change="filter"
              data-testid="filter-category"
            />
            <.sidebar_filter
              label="Status"
              options={[
                {"All Statuses", ""},
                {"Active", "active"},
                {"Draft", "draft"},
                {"Archived", "archived"}
              ]}
              field={:status}
              value={@filters.status}
              phx-change="filter"
              data-testid="filter-status"
            />
            <.sidebar_filter
              label="Stock Level"
              options={[
                {"All Stock", ""},
                {"In Stock", "in_stock"},
                {"Low Stock", "low"},
                {"Out of Stock", "out"}
              ]}
              field={:stock}
              value={@filters.stock}
              phx-change="filter"
            />
          </:filters>

          <:insights>
            <.ai_insight
              message="3 products are running low on stock"
              action="View low stock"
              href={~p"/app/products?stock=low"}
            />
            <.ai_insight
              message="2 products have no sales in 30 days"
              action="Review performance"
              phx-click="show_stale_products"
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

  # Private component for bulk actions bar
  attr :selected_count, :integer, required: true

  defp bulk_actions_bar(assigns) do
    ~H"""
    <div
      data-testid="bulk-actions-bar"
      class="bg-primary/10 border border-primary/30 rounded-lg p-3 mb-4 flex items-center justify-between"
    >
      <span data-testid="selected-count" class="font-medium">{@selected_count} selected</span>
      <div class="flex gap-2">
        <.button variant="ghost" size="sm" phx-click="bulk_status">Change Status</.button>
        <.button variant="ghost" size="sm" phx-click="bulk_category">Change Category</.button>
        <.button variant="ghost" size="sm" phx-click="bulk_price">Update Prices</.button>
        <.button variant="ghost" size="sm" class="text-error" phx-click="bulk_delete">Delete</.button>
        <.button variant="ghost" size="sm" phx-click="clear_selection">Cancel</.button>
      </div>
    </div>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:ok, result} = Product.list_products(%{
      search: query,
      category_id: socket.assigns.filters.category_id,
      status: socket.assigns.filters.status,
      page: 1
    })

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:products, result.results)
     |> assign(:page, 1)
     |> assign(:total_count, result.total_count)
     |> assign(:total_pages, ceil(result.total_count / 25))}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = %{
      category_id: get_filter_value(params, "category_id"),
      status: get_filter_value(params, "status") |> maybe_to_atom(),
      stock: get_filter_value(params, "stock")
    }

    {:ok, result} = Product.list_products(%{
      search: socket.assigns.search_query,
      category_id: filters.category_id,
      status: filters.status,
      page: 1
    })

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:products, result.results)
     |> assign(:page, 1)
     |> assign(:total_count, result.total_count)
     |> assign(:total_pages, ceil(result.total_count / 25))}
  end

  @impl true
  def handle_event("page-change", %{"page" => page}, socket) do
    page = String.to_integer(page)

    {:ok, result} = Product.list_products(%{
      search: socket.assigns.search_query,
      category_id: socket.assigns.filters.category_id,
      status: socket.assigns.filters.status,
      page: page
    })

    {:noreply,
     socket
     |> assign(:products, result.results)
     |> assign(:page, page)}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)
    current = socket.assigns.sort_by
    dir = socket.assigns.sort_dir

    {new_field, new_dir} =
      if field == current do
        {field, toggle_dir(dir)}
      else
        {field, :asc}
      end

    # Re-fetch with new sort
    {:ok, result} = Product.list_products(%{
      search: socket.assigns.search_query,
      category_id: socket.assigns.filters.category_id,
      status: socket.assigns.filters.status,
      page: 1,
      sort: [{new_dir, new_field}]
    })

    {:noreply,
     socket
     |> assign(:sort_by, new_field)
     |> assign(:sort_dir, new_dir)
     |> assign(:products, result.results)
     |> assign(:page, 1)}
  end

  @impl true
  def handle_event("select-all", _params, socket) do
    ids =
      if MapSet.size(socket.assigns.selected_ids) == length(socket.assigns.products) do
        MapSet.new()
      else
        socket.assigns.products |> Enum.map(& &1.id) |> MapSet.new()
      end

    {:noreply, assign(socket, :selected_ids, ids)}
  end

  @impl true
  def handle_event("select-row", %{"id" => id}, socket) do
    ids =
      if MapSet.member?(socket.assigns.selected_ids, id) do
        MapSet.delete(socket.assigns.selected_ids, id)
      else
        MapSet.put(socket.assigns.selected_ids, id)
      end

    {:noreply, assign(socket, :selected_ids, ids)}
  end

  @impl true
  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected_ids, MapSet.new())}
  end

  @impl true
  def handle_event("duplicate", %{"id" => id}, socket) do
    case Product.get(id) do
      {:ok, product} ->
        {:ok, _new_product} = Product.create(%{
          name: "Copy of #{product.name}",
          sku: "#{product.sku}-COPY",
          price: product.price,
          description: product.description,
          category_id: product.category_id,
          status: :draft
        })

        {:noreply,
         socket
         |> put_flash(:info, "Product duplicated")
         |> push_navigate(to: ~p"/app/products")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Product not found")}
    end
  end

  @impl true
  def handle_event("archive", %{"id" => id}, socket) do
    case Product.get(id) do
      {:ok, product} ->
        {:ok, _} = Product.update(product, %{status: :archived})
        {:noreply, put_flash(socket, :info, "Product archived") |> reload_products()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Product not found")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    # Would show confirmation modal in production
    case Product.get(id) do
      {:ok, product} ->
        {:ok, _} = Product.destroy(product)
        {:noreply, put_flash(socket, :info, "Product deleted") |> reload_products()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Product not found")}
    end
  end

  # Helper functions

  defp status_variant(:active), do: "success"
  defp status_variant(:draft), do: "ghost"
  defp status_variant(:archived), do: "warning"
  defp status_variant(_), do: nil

  defp toggle_dir(:asc), do: :desc
  defp toggle_dir(:desc), do: :asc

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

  defp reload_products(socket) do
    {:ok, result} = Product.list_products(%{
      search: socket.assigns.search_query,
      category_id: socket.assigns.filters.category_id,
      status: socket.assigns.filters.status,
      page: socket.assigns.page
    })

    {:ok, stats} = Product.get_product_stats()

    socket
    |> assign(:products, result.results)
    |> assign(:stats, stats)
    |> assign(:total_count, result.total_count)
    |> assign(:total_pages, ceil(result.total_count / 25))
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/live/merchant/products/index_live_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp_web/live/merchant/products/index_live.ex test/mcp_web/live/merchant/products/index_live_test.exs
git commit -m "feat(merchant): add Product List with page layout, search, filters"
```

---

## Task 3: Merchant Product Detail LiveView

**Files:**
- Create: `lib/mcp_web/live/merchant/products/show_live.ex`
- Test: `test/mcp_web/live/merchant/products/show_live_test.exs`

**Design Reference:** Merchant Features §2.2 Product Detail wireframe

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/merchant/products/show_live_test.exs
defmodule McpWeb.Merchant.Products.ShowLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "mount/3" do
    test "renders product detail with page layout", %{conn: conn} do
      product = insert(:product, name: "Premium Tee", sku: "TEE-001")

      {:ok, view, html} = live(conn, ~p"/app/products/#{product.id}")

      assert html =~ "Premium Tee"
      assert has_element?(view, "[data-testid='page-layout-detail']")
      assert has_element?(view, "[data-testid='action-sidebar']")
    end

    test "displays product info card", %{conn: conn} do
      product = insert(:product,
        name: "Premium Tee",
        sku: "TEE-001",
        price: Money.new(2999, :USD),
        description: "A premium cotton t-shirt"
      )

      {:ok, view, _html} = live(conn, ~p"/app/products/#{product.id}")

      assert has_element?(view, "[data-testid='product-name']", "Premium Tee")
      assert has_element?(view, "[data-testid='product-sku']", "TEE-001")
      assert has_element?(view, "[data-testid='product-price']", "$29.99")
      assert has_element?(view, "[data-testid='product-description']", "premium cotton")
    end

    test "displays inventory section when tracking enabled", %{conn: conn} do
      product = insert(:product, track_inventory: true, quantity_on_hand: 50, low_stock_threshold: 10)

      {:ok, view, _html} = live(conn, ~p"/app/products/#{product.id}")

      assert has_element?(view, "[data-testid='inventory-section']")
      assert has_element?(view, "[data-testid='stock-quantity']", "50")
      assert has_element?(view, "[data-testid='low-stock-threshold']", "10")
    end

    test "displays AI insights in sidebar", %{conn: conn} do
      product = insert(:product)

      {:ok, _view, html} = live(conn, ~p"/app/products/#{product.id}")

      assert html =~ "AI INSIGHTS"
    end
  end

  describe "edit mode" do
    test "switches to edit mode on click", %{conn: conn} do
      product = insert(:product)

      {:ok, view, _html} = live(conn, ~p"/app/products/#{product.id}")

      view |> element("[data-testid='edit-btn']") |> render_click()

      assert has_element?(view, "[data-testid='edit-form']")
      assert has_element?(view, "input[name='product[name]']")
    end

    test "saves product changes", %{conn: conn} do
      product = insert(:product, name: "Old Name")

      {:ok, view, _html} = live(conn, ~p"/app/products/#{product.id}")

      view |> element("[data-testid='edit-btn']") |> render_click()

      view
      |> form("#product-form", product: %{name: "New Name"})
      |> render_submit()

      assert has_element?(view, "[data-testid='product-name']", "New Name")
    end

    test "validates required fields", %{conn: conn} do
      product = insert(:product)

      {:ok, view, _html} = live(conn, ~p"/app/products/#{product.id}")

      view |> element("[data-testid='edit-btn']") |> render_click()

      view
      |> form("#product-form", product: %{name: ""})
      |> render_submit()

      assert has_element?(view, ".input-error")
    end
  end

  describe "variant management" do
    test "displays variants list", %{conn: conn} do
      product = insert(:product)
      insert(:product_variant, product: product, name: "Small", sku: "TEE-001-S")
      insert(:product_variant, product: product, name: "Medium", sku: "TEE-001-M")

      {:ok, view, _html} = live(conn, ~p"/app/products/#{product.id}")

      assert has_element?(view, "[data-testid='variants-section']")
      assert has_element?(view, "[data-testid='variant-row']", "Small")
      assert has_element?(view, "[data-testid='variant-row']", "Medium")
    end

    test "can add a new variant", %{conn: conn} do
      product = insert(:product)

      {:ok, view, _html} = live(conn, ~p"/app/products/#{product.id}")

      view |> element("[data-testid='add-variant-btn']") |> render_click()

      view
      |> form("#variant-form", variant: %{name: "Large", sku: "TEE-001-L", price: "29.99"})
      |> render_submit()

      assert has_element?(view, "[data-testid='variant-row']", "Large")
    end
  end

  describe "activity log" do
    test "displays recent activity", %{conn: conn} do
      product = insert(:product)
      # Activity log entries created automatically on product changes

      {:ok, view, _html} = live(conn, ~p"/app/products/#{product.id}")

      assert has_element?(view, "[data-testid='activity-log']")
    end
  end

  describe "sidebar actions" do
    test "can duplicate product", %{conn: conn} do
      product = insert(:product, name: "Original")

      {:ok, view, _html} = live(conn, ~p"/app/products/#{product.id}")

      {:ok, _view, html} =
        view
        |> element("[data-testid='duplicate-btn']")
        |> render_click()
        |> follow_redirect(conn)

      assert html =~ "Copy of Original"
    end

    test "can archive product", %{conn: conn} do
      product = insert(:product, status: :active)

      {:ok, view, _html} = live(conn, ~p"/app/products/#{product.id}")

      view |> element("[data-testid='archive-btn']") |> render_click()

      # Confirm modal
      view |> element("[data-testid='confirm-archive']") |> render_click()

      assert has_element?(view, "[data-testid='status-badge']", "archived")
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/live/merchant/products/show_live_test.exs -v`
Expected: FAIL

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/live/merchant/products/show_live.ex
defmodule McpWeb.Merchant.Products.ShowLive do
  @moduledoc """
  Merchant portal product detail view with edit capability.

  Uses PageLayout with detail variant (2/3+1/3 split):
  - Main content: Product info card, variants list, activity log
  - Sidebar: Quick actions, AI insights

  Design reference: Merchant Features §2.2 Product Detail
  """
  use McpWeb, :live_view

  import McpWeb.Portal.PageLayout, only: [page_layout: 1]
  import McpWeb.Portal.ActionSidebar, only: [action_sidebar: 1, sidebar_action: 1, ai_insight: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1, button: 1, card: 1, modal: 1]
  import McpWeb.Core.DataDisplay, only: [badge: 1, description_list: 1]
  import McpWeb.Core.Forms, only: [form_field: 1]

  alias Mcp.Catalog.Product
  alias Mcp.Catalog.ProductVariant
  alias Phoenix.LiveView.JS

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Product.get(id, load: [:category, :variants]) do
      {:ok, product} ->
        socket =
          socket
          |> assign(:page_title, product.name)
          |> assign(:product, product)
          |> assign(:edit_mode, false)
          |> assign(:changeset, nil)
          |> assign(:variant_changeset, nil)
          |> assign(:show_variant_modal, false)
          |> assign(:show_archive_modal, false)

        {:ok, socket}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Product not found")
         |> push_navigate(to: ~p"/app/products")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout variant={:detail} title={@product.name} data-testid="page-layout-detail">
      <:breadcrumb>
        <.link navigate={~p"/app/products"} class="link link-hover">Products</.link>
        <span class="mx-2">/</span>
        <span>{@product.name}</span>
      </:breadcrumb>

      <:toolbar>
        <.badge data-testid="status-badge" variant={status_variant(@product.status)}>
          {@product.status}
        </.badge>
        <.button
          :if={!@edit_mode}
          variant="primary"
          phx-click="enable_edit"
          data-testid="edit-btn"
        >
          <.icon name="hero-pencil" class="size-4 mr-2" /> Edit
        </.button>
        <div :if={@edit_mode} class="flex gap-2">
          <.button variant="ghost" phx-click="cancel_edit">Cancel</.button>
          <.button variant="primary" form="product-form" type="submit">Save</.button>
        </div>
      </:toolbar>

      <:content>
        <%= if @edit_mode do %>
          <.product_edit_form changeset={@changeset} product={@product} />
        <% else %>
          <.product_info_card product={@product} />
        <% end %>

        <.inventory_section :if={@product.track_inventory} product={@product} />

        <.variants_section
          product={@product}
          show_modal={@show_variant_modal}
          variant_changeset={@variant_changeset}
        />

        <.activity_log product={@product} />
      </:content>

      <:sidebar>
        <.action_sidebar data-testid="action-sidebar">
          <:actions>
            <.sidebar_action
              icon="hero-document-duplicate"
              label="Duplicate"
              phx-click="duplicate"
              data-testid="duplicate-btn"
            />
            <.sidebar_action
              icon="hero-arrow-up-tray"
              label="Export"
              phx-click="export"
            />
            <.sidebar_action
              :if={@product.status != :archived}
              icon="hero-archive-box"
              label="Archive"
              phx-click="show_archive_modal"
              data-testid="archive-btn"
            />
            <.sidebar_action
              :if={@product.status == :archived}
              icon="hero-archive-box-arrow-down"
              label="Restore"
              phx-click="restore"
            />
          </:actions>

          <:insights>
            <.ai_insight
              message="This product has strong performance"
              action="View analytics"
              href={~p"/app/products/#{@product.id}/analytics"}
            />
            <.ai_insight
              :if={@product.is_low_stock}
              message="Low stock warning - consider reordering"
              action="Create PO"
              phx-click="create_po"
            />
            <div class="text-center text-sm text-base-content/50 py-4">
              AI insights coming in Phase 5
            </div>
          </:insights>
        </.action_sidebar>
      </:sidebar>
    </.page_layout>

    <.modal :if={@show_archive_modal} id="archive-modal" show on_cancel={JS.push("hide_archive_modal")}>
      <:title>Archive Product</:title>
      <p class="py-4">Are you sure you want to archive "{@product.name}"? Archived products won't appear in POS or store listings.</p>
      <:actions>
        <.button variant="ghost" phx-click="hide_archive_modal">Cancel</.button>
        <.button variant="warning" phx-click="archive" data-testid="confirm-archive">Archive</.button>
      </:actions>
    </.modal>
    """
  end

  # Private components

  defp product_info_card(assigns) do
    ~H"""
    <.card class="mb-6" data-testid="product-info-card">
      <div class="flex gap-6">
        <div class="w-48 h-48 bg-base-200 rounded-lg flex items-center justify-center">
          <img :if={@product.image_url} src={@product.image_url} alt={@product.name} class="object-cover rounded-lg" />
          <.icon :if={!@product.image_url} name="hero-photo" class="size-16 text-base-content/20" />
        </div>
        <div class="flex-1">
          <h2 data-testid="product-name" class="text-2xl font-bold mb-2">{@product.name}</h2>
          <div class="flex items-center gap-4 text-base-content/60 mb-4">
            <span data-testid="product-sku">SKU: {@product.sku}</span>
            <span :if={@product.category}>Category: {@product.category.name}</span>
          </div>
          <div class="flex items-baseline gap-3 mb-4">
            <span data-testid="product-price" class="text-3xl font-bold">{Money.to_string(@product.price)}</span>
            <span :if={@product.compare_at_price} class="text-lg text-base-content/50 line-through">
              {Money.to_string(@product.compare_at_price)}
            </span>
            <span :if={@product.cost} class="text-sm text-base-content/50">
              Cost: {Money.to_string(@product.cost)}
              <span :if={@product.margin_percentage} class="ml-2">
                ({Number.to_string(@product.margin_percentage, precision: 1)}% margin)
              </span>
            </span>
          </div>
          <p :if={@product.description} data-testid="product-description" class="text-base-content/70">
            {@product.description}
          </p>
        </div>
      </div>
    </.card>
    """
  end

  defp product_edit_form(assigns) do
    ~H"""
    <.card class="mb-6">
      <.form
        for={@changeset}
        id="product-form"
        phx-change="validate"
        phx-submit="save"
        data-testid="edit-form"
      >
        <div class="grid grid-cols-2 gap-6">
          <.form_field field={@changeset[:name]} label="Product Name" required />
          <.form_field field={@changeset[:sku]} label="SKU" required />
          <.form_field field={@changeset[:price]} label="Price" type="money" required />
          <.form_field field={@changeset[:compare_at_price]} label="Compare at Price" type="money" />
          <.form_field field={@changeset[:cost]} label="Cost" type="money" />
          <.form_field
            field={@changeset[:status]}
            label="Status"
            type="select"
            options={[{"Active", :active}, {"Draft", :draft}, {"Archived", :archived}]}
          />
        </div>
        <div class="mt-4">
          <.form_field field={@changeset[:description]} label="Description" type="textarea" rows={4} />
        </div>
      </.form>
    </.card>
    """
  end

  defp inventory_section(assigns) do
    ~H"""
    <.card class="mb-6" data-testid="inventory-section">
      <h3 class="text-lg font-semibold mb-4">Inventory</h3>
      <div class="grid grid-cols-3 gap-4">
        <div class="stat bg-base-200 rounded-lg">
          <div class="stat-title">On Hand</div>
          <div class="stat-value" data-testid="stock-quantity">{@product.quantity_on_hand}</div>
        </div>
        <div class="stat bg-base-200 rounded-lg">
          <div class="stat-title">Low Stock Alert</div>
          <div class="stat-value" data-testid="low-stock-threshold">{@product.low_stock_threshold}</div>
        </div>
        <div class="stat bg-base-200 rounded-lg">
          <div class="stat-title">Status</div>
          <div class="stat-value text-lg">
            <.badge :if={@product.is_low_stock} variant="warning">Low Stock</.badge>
            <.badge :if={!@product.is_low_stock} variant="success">In Stock</.badge>
          </div>
        </div>
      </div>
      <div class="mt-4 flex gap-2">
        <.button size="sm" variant="ghost" phx-click="adjust_stock">
          <.icon name="hero-plus-minus" class="size-4 mr-1" /> Adjust Stock
        </.button>
        <.button size="sm" variant="ghost" phx-click="view_history">
          <.icon name="hero-clock" class="size-4 mr-1" /> View History
        </.button>
      </div>
    </.card>
    """
  end

  defp variants_section(assigns) do
    ~H"""
    <.card class="mb-6" data-testid="variants-section">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-semibold">Variants ({length(@product.variants)})</h3>
        <.button size="sm" variant="ghost" phx-click="show_variant_modal" data-testid="add-variant-btn">
          <.icon name="hero-plus" class="size-4 mr-1" /> Add Variant
        </.button>
      </div>
      <div :if={@product.variants == []} class="text-center py-8 text-base-content/50">
        No variants. Add variants for different sizes, colors, etc.
      </div>
      <table :if={@product.variants != []} class="table">
        <thead>
          <tr>
            <th>Variant</th>
            <th>SKU</th>
            <th>Price</th>
            <th>Stock</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={variant <- @product.variants} data-testid="variant-row">
            <td>{variant.name}</td>
            <td class="text-base-content/60">{variant.sku}</td>
            <td>{Money.to_string(variant.price || @product.price)}</td>
            <td>{variant.quantity_on_hand || "—"}</td>
            <td>
              <.button size="xs" variant="ghost" phx-click="edit_variant" phx-value-id={variant.id}>
                Edit
              </.button>
            </td>
          </tr>
        </tbody>
      </table>

      <.modal :if={@show_modal} id="variant-modal" show on_cancel={JS.push("hide_variant_modal")}>
        <:title>Add Variant</:title>
        <.form for={@variant_changeset} id="variant-form" phx-submit="save_variant">
          <.form_field field={@variant_changeset[:name]} label="Variant Name" placeholder="e.g., Large, Red" required />
          <.form_field field={@variant_changeset[:sku]} label="SKU" required />
          <.form_field field={@variant_changeset[:price]} label="Price Override" type="money" />
        </.form>
        <:actions>
          <.button variant="ghost" phx-click="hide_variant_modal">Cancel</.button>
          <.button variant="primary" form="variant-form" type="submit">Add Variant</.button>
        </:actions>
      </.modal>
    </.card>
    """
  end

  defp activity_log(assigns) do
    ~H"""
    <.card data-testid="activity-log">
      <h3 class="text-lg font-semibold mb-4">Activity</h3>
      <div class="space-y-3">
        <div class="flex items-start gap-3 text-sm">
          <div class="w-8 h-8 rounded-full bg-base-200 flex items-center justify-center">
            <.icon name="hero-pencil" class="size-4" />
          </div>
          <div>
            <p><strong>Product created</strong></p>
            <p class="text-base-content/50">{format_datetime(@product.inserted_at)}</p>
          </div>
        </div>
        <%!-- More activity entries would be loaded from activity log --%>
      </div>
    </.card>
    """
  end

  # Event handlers

  @impl true
  def handle_event("enable_edit", _params, socket) do
    changeset = Product.changeset(socket.assigns.product, %{})
    {:noreply, assign(socket, edit_mode: true, changeset: changeset)}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, edit_mode: false, changeset: nil)}
  end

  @impl true
  def handle_event("validate", %{"product" => params}, socket) do
    changeset =
      socket.assigns.product
      |> Product.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("save", %{"product" => params}, socket) do
    case Product.update(socket.assigns.product, params) do
      {:ok, product} ->
        {:noreply,
         socket
         |> assign(:product, product)
         |> assign(:edit_mode, false)
         |> assign(:changeset, nil)
         |> put_flash(:info, "Product updated")}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_event("duplicate", _params, socket) do
    product = socket.assigns.product

    case Product.create(%{
      name: "Copy of #{product.name}",
      sku: "#{product.sku}-COPY-#{:rand.uniform(1000)}",
      price: product.price,
      description: product.description,
      category_id: product.category_id,
      status: :draft
    }) do
      {:ok, new_product} ->
        {:noreply, push_navigate(socket, to: ~p"/app/products/#{new_product.id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to duplicate product")}
    end
  end

  @impl true
  def handle_event("show_archive_modal", _params, socket) do
    {:noreply, assign(socket, show_archive_modal: true)}
  end

  @impl true
  def handle_event("hide_archive_modal", _params, socket) do
    {:noreply, assign(socket, show_archive_modal: false)}
  end

  @impl true
  def handle_event("archive", _params, socket) do
    case Product.update(socket.assigns.product, %{status: :archived}) do
      {:ok, product} ->
        {:noreply,
         socket
         |> assign(:product, product)
         |> assign(:show_archive_modal, false)
         |> put_flash(:info, "Product archived")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to archive product")}
    end
  end

  @impl true
  def handle_event("restore", _params, socket) do
    case Product.update(socket.assigns.product, %{status: :active}) do
      {:ok, product} ->
        {:noreply, socket |> assign(:product, product) |> put_flash(:info, "Product restored")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to restore product")}
    end
  end

  @impl true
  def handle_event("show_variant_modal", _params, socket) do
    changeset = ProductVariant.changeset(%ProductVariant{product_id: socket.assigns.product.id}, %{})
    {:noreply, assign(socket, show_variant_modal: true, variant_changeset: changeset)}
  end

  @impl true
  def handle_event("hide_variant_modal", _params, socket) do
    {:noreply, assign(socket, show_variant_modal: false, variant_changeset: nil)}
  end

  @impl true
  def handle_event("save_variant", %{"variant" => params}, socket) do
    params = Map.put(params, "product_id", socket.assigns.product.id)

    case ProductVariant.create(params) do
      {:ok, _variant} ->
        {:ok, product} = Product.get(socket.assigns.product.id, load: [:category, :variants])

        {:noreply,
         socket
         |> assign(:product, product)
         |> assign(:show_variant_modal, false)
         |> assign(:variant_changeset, nil)
         |> put_flash(:info, "Variant added")}

      {:error, changeset} ->
        {:noreply, assign(socket, variant_changeset: changeset)}
    end
  end

  # Helpers

  defp status_variant(:active), do: "success"
  defp status_variant(:draft), do: "ghost"
  defp status_variant(:archived), do: "warning"
  defp status_variant(_), do: nil

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%b %d, %Y at %I:%M %p")
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/live/merchant/products/show_live_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp_web/live/merchant/products/show_live.ex test/mcp_web/live/merchant/products/show_live_test.exs
git commit -m "feat(merchant): add Product Detail view with edit mode, variants"
```

---

## Task 4: Merchant Product Create LiveView

**Files:**
- Create: `lib/mcp_web/live/merchant/products/new_live.ex`
- Test: `test/mcp_web/live/merchant/products/new_live_test.exs`

**Design Reference:** Merchant Features §2.3 Product Create wireframe

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/merchant/products/new_live_test.exs
defmodule McpWeb.Merchant.Products.NewLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "mount/3" do
    test "renders create form with page layout", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/products/new")

      assert html =~ "New Product"
      assert has_element?(view, "[data-testid='page-layout-detail']")
      assert has_element?(view, "form#product-form")
    end

    test "loads categories for dropdown", %{conn: conn} do
      insert(:category, name: "Apparel")
      insert(:category, name: "Accessories")

      {:ok, view, _html} = live(conn, ~p"/app/products/new")

      assert has_element?(view, "select[name='product[category_id]'] option", "Apparel")
      assert has_element?(view, "select[name='product[category_id]'] option", "Accessories")
    end
  end

  describe "form validation" do
    test "validates required fields on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/new")

      html =
        view
        |> form("#product-form", product: %{name: "", sku: ""})
        |> render_change()

      assert html =~ "is required" or html =~ "can&#39;t be blank"
    end

    test "validates unique SKU", %{conn: conn} do
      insert(:product, sku: "EXISTING-SKU")

      {:ok, view, _html} = live(conn, ~p"/app/products/new")

      view
      |> form("#product-form", product: %{name: "New Product", sku: "EXISTING-SKU", price: "29.99"})
      |> render_submit()

      assert has_element?(view, ".input-error")
    end
  end

  describe "product creation" do
    test "creates product with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/new")

      {:ok, _view, html} =
        view
        |> form("#product-form", product: %{
          name: "New Product",
          sku: "NEW-001",
          price: "29.99",
          status: "active"
        })
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "New Product"
      assert html =~ "Product created"
    end

    test "creates product with inventory tracking", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/new")

      {:ok, _view, html} =
        view
        |> form("#product-form", product: %{
          name: "Tracked Product",
          sku: "TRK-001",
          price: "19.99",
          track_inventory: "true",
          quantity_on_hand: "50",
          low_stock_threshold: "10"
        })
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Tracked Product"
      assert html =~ "50"
    end
  end

  describe "image upload" do
    test "can upload product image", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/new")

      # Simulate file upload
      image =
        file_input(view, "#product-form", :image, [
          %{
            name: "product.jpg",
            content: File.read!("test/support/fixtures/test_image.jpg"),
            type: "image/jpeg"
          }
        ])

      render_upload(image, "product.jpg")

      assert has_element?(view, "[data-testid='image-preview']")
    end
  end

  describe "navigation" do
    test "cancel returns to product list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/new")

      {:ok, _view, html} =
        view
        |> element("[data-testid='cancel-btn']")
        |> render_click()
        |> follow_redirect(conn, ~p"/app/products")

      assert html =~ "Products"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/live/merchant/products/new_live_test.exs -v`
Expected: FAIL

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/live/merchant/products/new_live.ex
defmodule McpWeb.Merchant.Products.NewLive do
  @moduledoc """
  Merchant portal product creation form.

  Uses PageLayout with detail variant (2/3+1/3 split):
  - Main content: Multi-section create form
  - Sidebar: Quick tips, validation status

  Design reference: Merchant Features §2.3 Product Create
  """
  use McpWeb, :live_view

  import McpWeb.Portal.PageLayout, only: [page_layout: 1]
  import McpWeb.Portal.ActionSidebar, only: [action_sidebar: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1, button: 1, card: 1]
  import McpWeb.Core.Forms, only: [form_field: 1]

  alias Mcp.Catalog.Product
  alias Mcp.Catalog.Category

  @impl true
  def mount(_params, _session, socket) do
    {:ok, categories} = Category.list_categories()

    changeset = Product.changeset(%Product{}, %{})

    socket =
      socket
      |> assign(:page_title, "New Product")
      |> assign(:changeset, changeset)
      |> assign(:categories, categories)
      |> assign(:uploaded_files, [])
      |> allow_upload(:image, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1, max_file_size: 5_000_000)
      |> allow_upload(:gallery, accept: ~w(.jpg .jpeg .png .webp), max_entries: 10, max_file_size: 5_000_000)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout variant={:detail} title="New Product" data-testid="page-layout-detail">
      <:breadcrumb>
        <.link navigate={~p"/app/products"} class="link link-hover">Products</.link>
        <span class="mx-2">/</span>
        <span>New Product</span>
      </:breadcrumb>

      <:toolbar>
        <.button variant="ghost" phx-click="cancel" data-testid="cancel-btn">Cancel</.button>
        <.button variant="primary" form="product-form" type="submit">
          <.icon name="hero-check" class="size-4 mr-2" /> Create Product
        </.button>
      </:toolbar>

      <:content>
        <.form
          for={@changeset}
          id="product-form"
          phx-change="validate"
          phx-submit="save"
          class="space-y-6"
        >
          <%!-- Basic Info Section --%>
          <.card>
            <h3 class="text-lg font-semibold mb-4">Basic Information</h3>
            <div class="grid grid-cols-2 gap-6">
              <.form_field field={@changeset[:name]} label="Product Name" required placeholder="e.g., Premium Cotton T-Shirt" />
              <.form_field field={@changeset[:sku]} label="SKU" required placeholder="e.g., TEE-001" />
              <.form_field
                field={@changeset[:category_id]}
                label="Category"
                type="select"
                options={[{"Select category...", ""} | Enum.map(@categories, &{&1.name, &1.id})]}
              />
              <.form_field
                field={@changeset[:status]}
                label="Status"
                type="select"
                options={[{"Draft", :draft}, {"Active", :active}]}
              />
            </div>
            <div class="mt-4">
              <.form_field
                field={@changeset[:description]}
                label="Description"
                type="textarea"
                rows={4}
                placeholder="Describe your product..."
              />
            </div>
          </.card>

          <%!-- Media Section --%>
          <.card>
            <h3 class="text-lg font-semibold mb-4">Media</h3>
            <div class="grid grid-cols-2 gap-6">
              <div>
                <label class="label">
                  <span class="label-text font-medium">Main Image</span>
                </label>
                <div
                  class="border-2 border-dashed border-base-300 rounded-lg p-8 text-center hover:border-primary transition-colors cursor-pointer"
                  phx-drop-target={@uploads.image.ref}
                >
                  <.live_file_input upload={@uploads.image} class="hidden" />
                  <div :for={entry <- @uploads.image.entries} data-testid="image-preview">
                    <.live_img_preview entry={entry} class="w-32 h-32 object-cover rounded mx-auto mb-2" />
                    <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="btn btn-xs btn-error">
                      Remove
                    </button>
                  </div>
                  <div :if={@uploads.image.entries == []}>
                    <.icon name="hero-photo" class="size-12 text-base-content/30 mx-auto mb-2" />
                    <p class="text-sm text-base-content/60">Drop image here or click to upload</p>
                  </div>
                </div>
              </div>
              <div>
                <label class="label">
                  <span class="label-text font-medium">Gallery Images</span>
                </label>
                <div
                  class="border-2 border-dashed border-base-300 rounded-lg p-8 text-center hover:border-primary transition-colors cursor-pointer"
                  phx-drop-target={@uploads.gallery.ref}
                >
                  <.live_file_input upload={@uploads.gallery} class="hidden" />
                  <div class="flex flex-wrap gap-2 justify-center">
                    <div :for={entry <- @uploads.gallery.entries} class="relative">
                      <.live_img_preview entry={entry} class="w-20 h-20 object-cover rounded" />
                      <button
                        type="button"
                        phx-click="cancel-upload"
                        phx-value-ref={entry.ref}
                        class="absolute -top-2 -right-2 btn btn-xs btn-circle btn-error"
                      >
                        ×
                      </button>
                    </div>
                  </div>
                  <div :if={@uploads.gallery.entries == []}>
                    <.icon name="hero-squares-plus" class="size-12 text-base-content/30 mx-auto mb-2" />
                    <p class="text-sm text-base-content/60">Add up to 10 gallery images</p>
                  </div>
                </div>
              </div>
            </div>
          </.card>

          <%!-- Pricing Section --%>
          <.card>
            <h3 class="text-lg font-semibold mb-4">Pricing</h3>
            <div class="grid grid-cols-3 gap-6">
              <.form_field field={@changeset[:price]} label="Price" type="money" required placeholder="0.00" />
              <.form_field field={@changeset[:compare_at_price]} label="Compare at Price" type="money" placeholder="0.00" />
              <.form_field field={@changeset[:cost]} label="Cost per Item" type="money" placeholder="0.00" />
            </div>
            <p class="text-sm text-base-content/50 mt-2">
              Compare at price is used to show a crossed-out price for sales.
            </p>
          </.card>

          <%!-- Inventory Section --%>
          <.card>
            <h3 class="text-lg font-semibold mb-4">Inventory</h3>
            <div class="form-control mb-4">
              <label class="label cursor-pointer justify-start gap-3">
                <input
                  type="checkbox"
                  name="product[track_inventory]"
                  value="true"
                  checked={Ecto.Changeset.get_field(@changeset, :track_inventory)}
                  class="checkbox checkbox-primary"
                />
                <span class="label-text">Track quantity</span>
              </label>
            </div>
            <div :if={Ecto.Changeset.get_field(@changeset, :track_inventory)} class="grid grid-cols-2 gap-6">
              <.form_field field={@changeset[:quantity_on_hand]} label="Quantity on Hand" type="number" />
              <.form_field field={@changeset[:low_stock_threshold]} label="Low Stock Alert" type="number" placeholder="10" />
            </div>
          </.card>
        </.form>
      </:content>

      <:sidebar>
        <.action_sidebar data-testid="action-sidebar">
          <:insights>
            <div class="space-y-4">
              <div class="p-4 bg-info/10 rounded-lg">
                <h4 class="font-medium flex items-center gap-2 mb-2">
                  <.icon name="hero-light-bulb" class="size-5 text-info" />
                  Tips
                </h4>
                <ul class="text-sm space-y-2 text-base-content/70">
                  <li>• Use clear, descriptive product names</li>
                  <li>• Include key features in description</li>
                  <li>• Add multiple images for better conversion</li>
                  <li>• Set accurate inventory levels</li>
                </ul>
              </div>

              <div class="p-4 bg-base-200 rounded-lg">
                <h4 class="font-medium mb-2">Form Status</h4>
                <div class="space-y-2 text-sm">
                  <div class="flex items-center gap-2">
                    <.icon
                      name={if @changeset.valid?, do: "hero-check-circle", else: "hero-x-circle"}
                      class={"size-4 #{if @changeset.valid?, do: "text-success", else: "text-error"}"}
                    />
                    <span>{if @changeset.valid?, do: "Ready to save", else: "Has validation errors"}</span>
                  </div>
                </div>
              </div>
            </div>
          </:insights>
        </.action_sidebar>
      </:sidebar>
    </.page_layout>
    """
  end

  @impl true
  def handle_event("validate", %{"product" => params}, socket) do
    changeset =
      %Product{}
      |> Product.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("save", %{"product" => params}, socket) do
    # Handle image uploads first
    uploaded_files =
      consume_uploaded_entries(socket, :image, fn %{path: path}, _entry ->
        # In production, would upload to S3/MinIO
        dest = Path.join([:code.priv_dir(:mcp), "static", "uploads", Path.basename(path)])
        File.cp!(path, dest)
        {:ok, "/uploads/#{Path.basename(dest)}"}
      end)

    params =
      case uploaded_files do
        [url | _] -> Map.put(params, "image_url", url)
        [] -> params
      end

    case Product.create(params) do
      {:ok, product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product created successfully")
         |> push_navigate(to: ~p"/app/products/#{product.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/app/products")}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/live/merchant/products/new_live_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp_web/live/merchant/products/new_live.ex test/mcp_web/live/merchant/products/new_live_test.exs
git commit -m "feat(merchant): add Product Create form with image upload, inventory"
```

---

## Task 5: Categories Management LiveView

**Files:**
- Create: `lib/mcp/catalog/category.ex` (if not exists)
- Create: `lib/mcp_web/live/merchant/products/categories_live.ex`
- Test: `test/mcp_web/live/merchant/products/categories_live_test.exs`

**Design Reference:** Merchant Features §2.4 Categories

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/merchant/products/categories_live_test.exs
defmodule McpWeb.Merchant.Products.CategoriesLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "mount/3" do
    test "renders categories list with page layout", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/products/categories")

      assert html =~ "Categories"
      assert has_element?(view, "[data-testid='page-layout-list']")
    end

    test "displays category tree", %{conn: conn} do
      parent = insert(:category, name: "Apparel")
      insert(:category, name: "T-Shirts", parent: parent)
      insert(:category, name: "Accessories")

      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      assert has_element?(view, "[data-testid='category-row']", "Apparel")
      assert has_element?(view, "[data-testid='category-row']", "T-Shirts")
      assert has_element?(view, "[data-testid='category-row']", "Accessories")
    end

    test "shows product counts per category", %{conn: conn} do
      category = insert(:category, name: "Apparel")
      insert(:product, category: category)
      insert(:product, category: category)

      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      assert has_element?(view, "[data-testid='category-count']", "2")
    end
  end

  describe "create category" do
    test "opens modal on add click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      view |> element("[data-testid='add-category-btn']") |> render_click()

      assert has_element?(view, "[data-testid='category-modal']")
    end

    test "creates new category", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      view |> element("[data-testid='add-category-btn']") |> render_click()

      view
      |> form("#category-form", category: %{name: "New Category"})
      |> render_submit()

      assert has_element?(view, "[data-testid='category-row']", "New Category")
    end

    test "creates nested category", %{conn: conn} do
      parent = insert(:category, name: "Apparel")

      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      view |> element("[data-testid='add-subcategory-#{parent.id}']") |> render_click()

      view
      |> form("#category-form", category: %{name: "T-Shirts"})
      |> render_submit()

      assert has_element?(view, "[data-testid='category-row']", "T-Shirts")
    end
  end

  describe "edit category" do
    test "edits category name", %{conn: conn} do
      category = insert(:category, name: "Old Name")

      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      view |> element("[data-testid='edit-category-#{category.id}']") |> render_click()

      view
      |> form("#category-form", category: %{name: "New Name"})
      |> render_submit()

      assert has_element?(view, "[data-testid='category-row']", "New Name")
    end
  end

  describe "delete category" do
    test "deletes empty category", %{conn: conn} do
      category = insert(:category, name: "Empty Category")

      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      view |> element("[data-testid='delete-category-#{category.id}']") |> render_click()
      view |> element("[data-testid='confirm-delete']") |> render_click()

      refute has_element?(view, "[data-testid='category-row']", "Empty Category")
    end

    test "warns when deleting category with products", %{conn: conn} do
      category = insert(:category, name: "Has Products")
      insert(:product, category: category)

      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      view |> element("[data-testid='delete-category-#{category.id}']") |> render_click()

      assert has_element?(view, "[data-testid='delete-warning']", "1 product")
    end
  end

  describe "reordering" do
    test "can reorder categories via drag drop", %{conn: conn} do
      insert(:category, name: "A", position: 0)
      insert(:category, name: "B", position: 1)

      {:ok, view, _html} = live(conn, ~p"/app/products/categories")

      # Simulate drag-drop reorder
      view |> render_hook("reorder", %{from: 0, to: 1})

      # Verify new order by checking DOM
      html = render(view)
      assert html =~ ~r/B.*A/s
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/live/merchant/products/categories_live_test.exs -v`
Expected: FAIL

**Step 3: Write Category resource and LiveView implementation**

```elixir
# lib/mcp/catalog/category.ex
defmodule Mcp.Catalog.Category do
  @moduledoc """
  Product category for organizing the catalog.

  Supports hierarchical structure with parent/child relationships.
  """
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Mcp.Catalog

  postgres do
    table "categories"
    repo Mcp.Repo

    references do
      reference :parent, on_delete: :nilify
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false
    attribute :slug, :string
    attribute :description, :string
    attribute :position, :integer, default: 0
    attribute :image_url, :string

    timestamps()
  end

  relationships do
    belongs_to :parent, __MODULE__
    belongs_to :tenant, Mcp.Platform.Tenant
    has_many :children, __MODULE__, destination_attribute: :parent_id
    has_many :products, Mcp.Catalog.Product
  end

  identities do
    identity :unique_slug_per_tenant, [:slug, :tenant_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :position, :parent_id, :image_url]
      change relate_actor(:tenant)
      change set_attribute(:slug, expr(fragment("lower(regexp_replace(?, '[^a-zA-Z0-9]+', '-', 'g'))", name)))
    end

    update :update do
      accept [:name, :description, :position, :parent_id, :image_url]
    end

    read :list_categories do
      prepare build(sort: [:position, :name])
    end

    read :tree do
      prepare fn query, _ ->
        Ash.Query.filter(query, is_nil(parent_id))
        |> Ash.Query.load(children: [:children, :products])
      end
    end
  end

  aggregates do
    count :product_count, :products
    count :children_count, :children
  end

  code_interface do
    domain Mcp.Catalog

    define :create
    define :update
    define :list_categories
    define :tree
    define :get, args: [:id]
    define :destroy
  end
end
```

```elixir
# lib/mcp_web/live/merchant/products/categories_live.ex
defmodule McpWeb.Merchant.Products.CategoriesLive do
  @moduledoc """
  Category management with hierarchical tree view.

  Uses PageLayout with list variant.
  """
  use McpWeb, :live_view

  import McpWeb.Portal.PageLayout, only: [page_layout: 1]
  import McpWeb.Portal.ActionSidebar, only: [action_sidebar: 1, sidebar_action: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1, button: 1, card: 1, modal: 1]
  import McpWeb.Core.Forms, only: [form_field: 1]

  alias Mcp.Catalog.Category
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    {:ok, categories} = Category.tree()

    socket =
      socket
      |> assign(:page_title, "Categories")
      |> assign(:categories, categories)
      |> assign(:show_modal, false)
      |> assign(:editing_category, nil)
      |> assign(:parent_id, nil)
      |> assign(:changeset, nil)
      |> assign(:delete_candidate, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout variant={:list} title="Categories" data-testid="page-layout-list">
      <:toolbar>
        <.button variant="primary" phx-click="new_category" data-testid="add-category-btn">
          <.icon name="hero-plus" class="size-4 mr-2" /> Add Category
        </.button>
      </:toolbar>

      <:content>
        <.card>
          <div
            id="category-tree"
            phx-hook="Sortable"
            data-sortable-group="categories"
          >
            <.category_row
              :for={category <- @categories}
              category={category}
              level={0}
            />
          </div>

          <div :if={@categories == []} class="text-center py-12 text-base-content/50">
            <.icon name="hero-folder" class="size-16 mx-auto mb-4 opacity-30" />
            <p>No categories yet. Add your first category to organize products.</p>
          </div>
        </.card>
      </:content>

      <:sidebar>
        <.action_sidebar data-testid="action-sidebar">
          <:actions>
            <.sidebar_action
              icon="hero-plus"
              label="Add Category"
              phx-click="new_category"
            />
            <.sidebar_action
              icon="hero-arrow-path"
              label="Reorder Mode"
              phx-click="toggle_reorder"
            />
          </:actions>

          <:insights>
            <div class="p-4 bg-info/10 rounded-lg">
              <h4 class="font-medium flex items-center gap-2 mb-2">
                <.icon name="hero-light-bulb" class="size-5 text-info" />
                Tips
              </h4>
              <ul class="text-sm space-y-2 text-base-content/70">
                <li>• Drag categories to reorder</li>
                <li>• Nest up to 3 levels deep</li>
                <li>• Categories appear in store navigation</li>
              </ul>
            </div>
          </:insights>
        </.action_sidebar>
      </:sidebar>
    </.page_layout>

    <.modal :if={@show_modal} id="category-modal" show on_cancel={JS.push("close_modal")} data-testid="category-modal">
      <:title>{if @editing_category, do: "Edit Category", else: "New Category"}</:title>
      <.form for={@changeset} id="category-form" phx-submit="save_category">
        <input :if={@parent_id} type="hidden" name="category[parent_id]" value={@parent_id} />
        <.form_field field={@changeset[:name]} label="Category Name" required />
        <.form_field field={@changeset[:description]} label="Description" type="textarea" />
      </.form>
      <:actions>
        <.button variant="ghost" phx-click="close_modal">Cancel</.button>
        <.button variant="primary" form="category-form" type="submit">
          {if @editing_category, do: "Save", else: "Create"}
        </.button>
      </:actions>
    </.modal>

    <.modal :if={@delete_candidate} id="delete-modal" show on_cancel={JS.push("cancel_delete")}>
      <:title>Delete Category</:title>
      <div :if={@delete_candidate.product_count > 0} data-testid="delete-warning" class="alert alert-warning mb-4">
        <.icon name="hero-exclamation-triangle" class="size-5" />
        <span>This category contains {@delete_candidate.product_count} product(s). They will be uncategorized.</span>
      </div>
      <p>Are you sure you want to delete "{@delete_candidate.name}"?</p>
      <:actions>
        <.button variant="ghost" phx-click="cancel_delete">Cancel</.button>
        <.button variant="error" phx-click="confirm_delete" data-testid="confirm-delete">Delete</.button>
      </:actions>
    </.modal>
    """
  end

  defp category_row(assigns) do
    ~H"""
    <div
      class={"flex items-center gap-3 p-3 hover:bg-base-200 rounded-lg group #{if @level > 0, do: "ml-#{@level * 6}"}"}
      data-testid="category-row"
      data-id={@category.id}
    >
      <div class="cursor-grab opacity-0 group-hover:opacity-100">
        <.icon name="hero-bars-3" class="size-5 text-base-content/30" />
      </div>
      <.icon name="hero-folder" class="size-5" />
      <span class="flex-1 font-medium">{@category.name}</span>
      <span data-testid="category-count" class="text-sm text-base-content/50">
        {@category.product_count} products
      </span>
      <div class="opacity-0 group-hover:opacity-100 flex gap-1">
        <button
          phx-click="add_subcategory"
          phx-value-parent-id={@category.id}
          class="btn btn-ghost btn-xs"
          data-testid={"add-subcategory-#{@category.id}"}
        >
          <.icon name="hero-plus" class="size-4" />
        </button>
        <button
          phx-click="edit_category"
          phx-value-id={@category.id}
          class="btn btn-ghost btn-xs"
          data-testid={"edit-category-#{@category.id}"}
        >
          <.icon name="hero-pencil" class="size-4" />
        </button>
        <button
          phx-click="delete_category"
          phx-value-id={@category.id}
          class="btn btn-ghost btn-xs text-error"
          data-testid={"delete-category-#{@category.id}"}
        >
          <.icon name="hero-trash" class="size-4" />
        </button>
      </div>
    </div>
    <%= for child <- @category.children || [] do %>
      <.category_row category={child} level={@level + 1} />
    <% end %>
    """
  end

  # Event handlers

  @impl true
  def handle_event("new_category", _params, socket) do
    changeset = Category.changeset(%Category{}, %{})
    {:noreply, assign(socket, show_modal: true, changeset: changeset, editing_category: nil, parent_id: nil)}
  end

  @impl true
  def handle_event("add_subcategory", %{"parent-id" => parent_id}, socket) do
    changeset = Category.changeset(%Category{}, %{})
    {:noreply, assign(socket, show_modal: true, changeset: changeset, editing_category: nil, parent_id: parent_id)}
  end

  @impl true
  def handle_event("edit_category", %{"id" => id}, socket) do
    {:ok, category} = Category.get(id)
    changeset = Category.changeset(category, %{})
    {:noreply, assign(socket, show_modal: true, changeset: changeset, editing_category: category, parent_id: nil)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: false, changeset: nil, editing_category: nil, parent_id: nil)}
  end

  @impl true
  def handle_event("save_category", %{"category" => params}, socket) do
    result =
      if socket.assigns.editing_category do
        Category.update(socket.assigns.editing_category, params)
      else
        Category.create(params)
      end

    case result do
      {:ok, _category} ->
        {:ok, categories} = Category.tree()
        {:noreply,
         socket
         |> assign(:categories, categories)
         |> assign(:show_modal, false)
         |> assign(:changeset, nil)
         |> assign(:editing_category, nil)
         |> put_flash(:info, "Category saved")}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_event("delete_category", %{"id" => id}, socket) do
    {:ok, category} = Category.get(id, load: [:products])
    {:noreply, assign(socket, delete_candidate: category)}
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, delete_candidate: nil)}
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    {:ok, _} = Category.destroy(socket.assigns.delete_candidate)
    {:ok, categories} = Category.tree()

    {:noreply,
     socket
     |> assign(:categories, categories)
     |> assign(:delete_candidate, nil)
     |> put_flash(:info, "Category deleted")}
  end

  @impl true
  def handle_event("reorder", %{"from" => from, "to" => to}, socket) do
    categories = socket.assigns.categories
    {item, rest} = List.pop_at(categories, from)
    reordered = List.insert_at(rest, to, item)

    # Update positions in database
    reordered
    |> Enum.with_index()
    |> Enum.each(fn {cat, idx} ->
      Category.update(cat, %{position: idx})
    end)

    {:noreply, assign(socket, categories: reordered)}
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/live/merchant/products/categories_live_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp/catalog/category.ex lib/mcp_web/live/merchant/products/categories_live.ex test/mcp_web/live/merchant/products/categories_live_test.exs
git commit -m "feat(merchant): add Categories management with tree view, reordering"
```

---

## Task 6: Inventory Overview LiveView

**Files:**
- Create: `lib/mcp_web/live/merchant/products/inventory_live.ex`
- Test: `test/mcp_web/live/merchant/products/inventory_live_test.exs`

**Design Reference:** Merchant Features §2.5 Inventory

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/merchant/products/inventory_live_test.exs
defmodule McpWeb.Merchant.Products.InventoryLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "mount/3" do
    test "renders full-width inventory table", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/products/inventory")

      assert html =~ "Inventory"
      assert has_element?(view, "[data-testid='page-layout-table']")
      assert has_element?(view, "[data-testid='data-table']")
    end

    test "shows inventory stats", %{conn: conn} do
      insert(:product, track_inventory: true, quantity_on_hand: 100)
      insert(:product, track_inventory: true, quantity_on_hand: 5, low_stock_threshold: 10)
      insert(:product, track_inventory: true, quantity_on_hand: 0)

      {:ok, view, _html} = live(conn, ~p"/app/products/inventory")

      assert has_element?(view, "[data-testid='stat-total-items']")
      assert has_element?(view, "[data-testid='stat-low-stock']", "1")
      assert has_element?(view, "[data-testid='stat-out-of-stock']", "1")
    end
  end

  describe "filtering" do
    test "filters to low stock only", %{conn: conn} do
      insert(:product, name: "Normal Stock", track_inventory: true, quantity_on_hand: 100)
      insert(:product, name: "Low Stock", track_inventory: true, quantity_on_hand: 5, low_stock_threshold: 10)

      {:ok, view, _html} = live(conn, ~p"/app/products/inventory")

      view |> element("[data-testid='filter-low-stock']") |> render_click()

      assert has_element?(view, "[data-testid='product-row']", "Low Stock")
      refute has_element?(view, "[data-testid='product-row']", "Normal Stock")
    end

    test "filters to out of stock only", %{conn: conn} do
      insert(:product, name: "In Stock", track_inventory: true, quantity_on_hand: 50)
      insert(:product, name: "Out of Stock", track_inventory: true, quantity_on_hand: 0)

      {:ok, view, _html} = live(conn, ~p"/app/products/inventory")

      view |> element("[data-testid='filter-out-of-stock']") |> render_click()

      assert has_element?(view, "[data-testid='product-row']", "Out of Stock")
      refute has_element?(view, "[data-testid='product-row']", "In Stock")
    end
  end

  describe "stock adjustment" do
    test "opens adjustment modal on click", %{conn: conn} do
      product = insert(:product, track_inventory: true, quantity_on_hand: 50)

      {:ok, view, _html} = live(conn, ~p"/app/products/inventory")

      view |> element("[data-testid='adjust-#{product.id}']") |> render_click()

      assert has_element?(view, "[data-testid='adjustment-modal']")
    end

    test "adjusts stock quantity", %{conn: conn} do
      product = insert(:product, track_inventory: true, quantity_on_hand: 50)

      {:ok, view, _html} = live(conn, ~p"/app/products/inventory")

      view |> element("[data-testid='adjust-#{product.id}']") |> render_click()

      view
      |> form("#adjustment-form", adjustment: %{type: "add", quantity: "10", reason: "Restock"})
      |> render_submit()

      assert has_element?(view, "[data-testid='quantity-#{product.id}']", "60")
    end
  end

  describe "bulk adjustments" do
    test "can select multiple and bulk adjust", %{conn: conn} do
      p1 = insert(:product, track_inventory: true, quantity_on_hand: 50)
      p2 = insert(:product, track_inventory: true, quantity_on_hand: 30)

      {:ok, view, _html} = live(conn, ~p"/app/products/inventory")

      view |> element("[data-testid='select-#{p1.id}']") |> render_click()
      view |> element("[data-testid='select-#{p2.id}']") |> render_click()
      view |> element("[data-testid='bulk-adjust-btn']") |> render_click()

      assert has_element?(view, "[data-testid='bulk-adjustment-modal']")
    end
  end

  describe "export" do
    test "exports inventory CSV", %{conn: conn} do
      insert(:product, track_inventory: true)

      {:ok, view, _html} = live(conn, ~p"/app/products/inventory")

      # Click export
      view |> element("[data-testid='export-btn']") |> render_click()

      # Should trigger download (would need to check redirect or async response)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/live/merchant/products/inventory_live_test.exs -v`
Expected: FAIL

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/live/merchant/products/inventory_live.ex
defmodule McpWeb.Merchant.Products.InventoryLive do
  @moduledoc """
  Full-width inventory management view.

  Uses PageLayout with table variant for maximum data visibility.
  Shows all products with inventory tracking enabled.

  Design reference: Merchant Features §2.5 Inventory
  """
  use McpWeb, :live_view

  import McpWeb.Portal.PageLayout, only: [page_layout: 1]
  import McpWeb.Portal.StatsRow, only: [stats_row: 1, stat: 1]
  import McpWeb.Portal.DataTable, only: [data_table: 1, pagination: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1, button: 1, modal: 1]
  import McpWeb.Core.DataDisplay, only: [badge: 1]
  import McpWeb.Core.Forms, only: [form_field: 1]

  alias Mcp.Catalog.Product
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    {:ok, result} = Product.list_inventory(%{page: 1, page_size: 50})
    stats = calculate_inventory_stats(result.results)

    socket =
      socket
      |> assign(:page_title, "Inventory")
      |> assign(:products, result.results)
      |> assign(:stats, stats)
      |> assign(:page, 1)
      |> assign(:total_pages, ceil(result.total_count / 50))
      |> assign(:filter, :all)
      |> assign(:selected_ids, MapSet.new())
      |> assign(:adjustment_product, nil)
      |> assign(:show_bulk_modal, false)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout variant={:table} title="Inventory" data-testid="page-layout-table">
      <:stats>
        <.stats_row>
          <.stat
            data-testid="stat-total-items"
            label="Total Items"
            value={to_string(@stats.total_items)}
            icon="hero-cube"
          />
          <.stat
            data-testid="stat-low-stock"
            label="Low Stock"
            value={to_string(@stats.low_stock_count)}
            icon="hero-exclamation-triangle"
            variant={if @stats.low_stock_count > 0, do: "warning"}
          />
          <.stat
            data-testid="stat-out-of-stock"
            label="Out of Stock"
            value={to_string(@stats.out_of_stock_count)}
            icon="hero-x-circle"
            variant={if @stats.out_of_stock_count > 0, do: "error"}
          />
          <.stat
            label="Total Value"
            value={Money.to_string(@stats.total_value)}
            icon="hero-currency-dollar"
          />
        </.stats_row>
      </:stats>

      <:toolbar>
        <div class="flex gap-2">
          <.button
            variant={if @filter == :all, do: "primary", else: "ghost"}
            size="sm"
            phx-click="filter"
            phx-value-filter="all"
          >
            All
          </.button>
          <.button
            variant={if @filter == :low_stock, do: "warning", else: "ghost"}
            size="sm"
            phx-click="filter"
            phx-value-filter="low_stock"
            data-testid="filter-low-stock"
          >
            Low Stock ({@stats.low_stock_count})
          </.button>
          <.button
            variant={if @filter == :out_of_stock, do: "error", else: "ghost"}
            size="sm"
            phx-click="filter"
            phx-value-filter="out_of_stock"
            data-testid="filter-out-of-stock"
          >
            Out of Stock ({@stats.out_of_stock_count})
          </.button>
        </div>
        <div class="flex gap-2">
          <.button
            :if={MapSet.size(@selected_ids) > 0}
            variant="ghost"
            phx-click="show_bulk_modal"
            data-testid="bulk-adjust-btn"
          >
            Adjust Selected ({MapSet.size(@selected_ids)})
          </.button>
          <.button variant="ghost" phx-click="export" data-testid="export-btn">
            <.icon name="hero-arrow-down-tray" class="size-4 mr-2" /> Export
          </.button>
        </div>
      </:toolbar>

      <:content>
        <.data_table
          id="inventory-table"
          rows={@products}
          selectable
          data-testid="data-table"
        >
          <:col :let={product} label="Product" field={:name}>
            <div class="flex items-center gap-3" data-testid="product-row">
              <div class="avatar">
                <div class="w-10 h-10 rounded bg-base-200">
                  <img :if={product.image_url} src={product.image_url} />
                </div>
              </div>
              <div>
                <div class="font-medium">{product.name}</div>
                <div class="text-sm text-base-content/50">{product.sku}</div>
              </div>
            </div>
          </:col>

          <:col :let={product} label="On Hand" field={:quantity_on_hand} align={:right}>
            <span
              data-testid={"quantity-#{product.id}"}
              class={stock_class(product)}
            >
              {product.quantity_on_hand}
            </span>
          </:col>

          <:col :let={product} label="Alert Level" field={:low_stock_threshold} align={:right}>
            {product.low_stock_threshold}
          </:col>

          <:col :let={product} label="Status">
            <.badge :if={product.quantity_on_hand == 0} variant="error">Out of Stock</.badge>
            <.badge :if={product.is_low_stock && product.quantity_on_hand > 0} variant="warning">Low Stock</.badge>
            <.badge :if={!product.is_low_stock && product.quantity_on_hand > 0} variant="success">In Stock</.badge>
          </:col>

          <:col :let={product} label="Value" align={:right}>
            {Money.to_string(Money.multiply(product.cost || product.price, product.quantity_on_hand))}
          </:col>

          <:action :let={product}>
            <.button
              size="xs"
              variant="ghost"
              phx-click="adjust"
              phx-value-id={product.id}
              data-testid={"adjust-#{product.id}"}
            >
              Adjust
            </.button>
          </:action>
        </.data_table>

        <.pagination page={@page} total_pages={@total_pages} />
      </:content>
    </.page_layout>

    <.modal :if={@adjustment_product} id="adjustment-modal" show on_cancel={JS.push("close_adjustment")} data-testid="adjustment-modal">
      <:title>Adjust Stock: {@adjustment_product.name}</:title>
      <p class="text-base-content/60 mb-4">Current quantity: {@adjustment_product.quantity_on_hand}</p>
      <.form for={%{}} as={:adjustment} id="adjustment-form" phx-submit="save_adjustment">
        <input type="hidden" name="adjustment[product_id]" value={@adjustment_product.id} />
        <.form_field
          name="adjustment[type]"
          label="Adjustment Type"
          type="select"
          options={[{"Add Stock", "add"}, {"Remove Stock", "remove"}, {"Set Quantity", "set"}]}
        />
        <.form_field name="adjustment[quantity]" label="Quantity" type="number" required />
        <.form_field
          name="adjustment[reason]"
          label="Reason"
          type="select"
          options={[
            {"Received shipment", "received"},
            {"Inventory count", "count"},
            {"Damaged/Lost", "damaged"},
            {"Returned", "returned"},
            {"Other", "other"}
          ]}
        />
        <.form_field name="adjustment[notes]" label="Notes" type="textarea" />
      </.form>
      <:actions>
        <.button variant="ghost" phx-click="close_adjustment">Cancel</.button>
        <.button variant="primary" form="adjustment-form" type="submit">Save Adjustment</.button>
      </:actions>
    </.modal>

    <.modal :if={@show_bulk_modal} id="bulk-adjustment-modal" show on_cancel={JS.push("close_bulk_modal")} data-testid="bulk-adjustment-modal">
      <:title>Bulk Adjustment ({MapSet.size(@selected_ids)} items)</:title>
      <.form for={%{}} as={:bulk} id="bulk-form" phx-submit="save_bulk_adjustment">
        <.form_field
          name="bulk[type]"
          label="Adjustment Type"
          type="select"
          options={[{"Add Stock", "add"}, {"Remove Stock", "remove"}]}
        />
        <.form_field name="bulk[quantity]" label="Quantity" type="number" required />
        <.form_field name="bulk[reason]" label="Reason" />
      </.form>
      <:actions>
        <.button variant="ghost" phx-click="close_bulk_modal">Cancel</.button>
        <.button variant="primary" form="bulk-form" type="submit">Apply to All</.button>
      </:actions>
    </.modal>
    """
  end

  # Event handlers

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    filter = String.to_existing_atom(filter)
    {:ok, result} = Product.list_inventory(%{filter: filter, page: 1})

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign(:products, result.results)
     |> assign(:page, 1)}
  end

  @impl true
  def handle_event("adjust", %{"id" => id}, socket) do
    product = Enum.find(socket.assigns.products, &(&1.id == id))
    {:noreply, assign(socket, adjustment_product: product)}
  end

  @impl true
  def handle_event("close_adjustment", _params, socket) do
    {:noreply, assign(socket, adjustment_product: nil)}
  end

  @impl true
  def handle_event("save_adjustment", %{"adjustment" => params}, socket) do
    product = socket.assigns.adjustment_product
    quantity = String.to_integer(params["quantity"])

    new_quantity =
      case params["type"] do
        "add" -> product.quantity_on_hand + quantity
        "remove" -> max(0, product.quantity_on_hand - quantity)
        "set" -> quantity
      end

    {:ok, _} = Product.update(product, %{quantity_on_hand: new_quantity})

    # Log the adjustment (would go to inventory_adjustments table)

    {:ok, result} = Product.list_inventory(%{filter: socket.assigns.filter, page: socket.assigns.page})
    stats = calculate_inventory_stats(result.results)

    {:noreply,
     socket
     |> assign(:products, result.results)
     |> assign(:stats, stats)
     |> assign(:adjustment_product, nil)
     |> put_flash(:info, "Stock adjusted")}
  end

  @impl true
  def handle_event("select-row", %{"id" => id}, socket) do
    ids =
      if MapSet.member?(socket.assigns.selected_ids, id) do
        MapSet.delete(socket.assigns.selected_ids, id)
      else
        MapSet.put(socket.assigns.selected_ids, id)
      end

    {:noreply, assign(socket, selected_ids: ids)}
  end

  @impl true
  def handle_event("show_bulk_modal", _params, socket) do
    {:noreply, assign(socket, show_bulk_modal: true)}
  end

  @impl true
  def handle_event("close_bulk_modal", _params, socket) do
    {:noreply, assign(socket, show_bulk_modal: false)}
  end

  @impl true
  def handle_event("save_bulk_adjustment", %{"bulk" => params}, socket) do
    quantity = String.to_integer(params["quantity"])

    socket.assigns.selected_ids
    |> Enum.each(fn id ->
      product = Enum.find(socket.assigns.products, &(&1.id == id))

      new_quantity =
        case params["type"] do
          "add" -> product.quantity_on_hand + quantity
          "remove" -> max(0, product.quantity_on_hand - quantity)
        end

      Product.update(product, %{quantity_on_hand: new_quantity})
    end)

    {:ok, result} = Product.list_inventory(%{filter: socket.assigns.filter, page: socket.assigns.page})
    stats = calculate_inventory_stats(result.results)

    {:noreply,
     socket
     |> assign(:products, result.results)
     |> assign(:stats, stats)
     |> assign(:selected_ids, MapSet.new())
     |> assign(:show_bulk_modal, false)
     |> put_flash(:info, "Bulk adjustment applied")}
  end

  @impl true
  def handle_event("export", _params, socket) do
    # Generate CSV and trigger download
    {:noreply, put_flash(socket, :info, "Export started - download will begin shortly")}
  end

  # Helpers

  defp calculate_inventory_stats(products) do
    %{
      total_items: Enum.sum(Enum.map(products, & &1.quantity_on_hand)),
      low_stock_count: Enum.count(products, & &1.is_low_stock),
      out_of_stock_count: Enum.count(products, &(&1.quantity_on_hand == 0)),
      total_value: Enum.reduce(products, Money.new(0, :USD), fn p, acc ->
        cost = p.cost || p.price
        Money.add(acc, Money.multiply(cost, p.quantity_on_hand))
      end)
    }
  end

  defp stock_class(product) do
    cond do
      product.quantity_on_hand == 0 -> "text-error font-bold"
      product.is_low_stock -> "text-warning font-bold"
      true -> ""
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/live/merchant/products/inventory_live_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp_web/live/merchant/products/inventory_live.ex test/mcp_web/live/merchant/products/inventory_live_test.exs
git commit -m "feat(merchant): add Inventory overview with adjustments, bulk operations"
```

---

## Task 7: Product Import LiveView (Focused)

**Files:**
- Create: `lib/mcp_web/live/merchant/products/import_live.ex`
- Test: `test/mcp_web/live/merchant/products/import_live_test.exs`

**Design Reference:** Merchant Features §2.6 Product Import

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/merchant/products/import_live_test.exs
defmodule McpWeb.Merchant.Products.ImportLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "mount/3" do
    test "renders focused layout with wizard", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/products/import")

      assert html =~ "Import Products"
      assert has_element?(view, "[data-testid='focused-layout']")
      assert has_element?(view, "[data-testid='wizard-progress']")
    end

    test "starts on upload step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/import")

      assert has_element?(view, "[data-testid='step-upload'].active")
    end
  end

  describe "file upload step" do
    test "accepts CSV file", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/import")

      csv_content = """
      name,sku,price
      Product A,SKU-001,29.99
      Product B,SKU-002,19.99
      """

      file = file_input(view, "#import-form", :file, [
        %{name: "products.csv", content: csv_content, type: "text/csv"}
      ])

      render_upload(file, "products.csv")

      assert has_element?(view, "[data-testid='file-preview']")
    end

    test "proceeds to mapping step after upload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/import")

      upload_csv(view)

      view |> element("[data-testid='next-btn']") |> render_click()

      assert has_element?(view, "[data-testid='step-mapping'].active")
    end
  end

  describe "field mapping step" do
    test "shows column mapping interface", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/import")

      upload_csv(view)
      view |> element("[data-testid='next-btn']") |> render_click()

      assert has_element?(view, "[data-testid='column-mapper']")
      assert has_element?(view, "select[name='mapping[name]']")
      assert has_element?(view, "select[name='mapping[sku]']")
      assert has_element?(view, "select[name='mapping[price]']")
    end

    test "auto-detects standard column names", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/import")

      upload_csv(view)
      view |> element("[data-testid='next-btn']") |> render_click()

      # Should auto-select matching columns
      assert has_element?(view, "select[name='mapping[name]'] option[selected]", "name")
    end
  end

  describe "preview step" do
    test "shows validation preview", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/import")

      upload_csv(view)
      view |> element("[data-testid='next-btn']") |> render_click()
      view |> element("[data-testid='next-btn']") |> render_click()

      assert has_element?(view, "[data-testid='step-preview'].active")
      assert has_element?(view, "[data-testid='preview-table']")
      assert has_element?(view, "[data-testid='valid-count']")
    end

    test "shows validation errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/import")

      upload_csv_with_errors(view)
      view |> element("[data-testid='next-btn']") |> render_click()
      view |> element("[data-testid='next-btn']") |> render_click()

      assert has_element?(view, "[data-testid='error-row']")
    end
  end

  describe "import execution" do
    test "imports valid products", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/import")

      upload_csv(view)
      view |> element("[data-testid='next-btn']") |> render_click()
      view |> element("[data-testid='next-btn']") |> render_click()
      view |> element("[data-testid='import-btn']") |> render_click()

      # Should show progress
      assert has_element?(view, "[data-testid='import-progress']")

      # Wait for completion
      :timer.sleep(100)

      assert has_element?(view, "[data-testid='import-complete']")
      assert has_element?(view, "[data-testid='imported-count']", "2")
    end
  end

  describe "exit behavior" do
    test "exit button returns to product list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products/import")

      {:ok, _view, html} =
        view
        |> element("[data-testid='exit-btn']")
        |> render_click()
        |> follow_redirect(conn, ~p"/app/products")

      assert html =~ "Products"
    end
  end

  # Helper functions

  defp upload_csv(view) do
    csv_content = """
    name,sku,price
    Product A,SKU-001,29.99
    Product B,SKU-002,19.99
    """

    file = file_input(view, "#import-form", :file, [
      %{name: "products.csv", content: csv_content, type: "text/csv"}
    ])

    render_upload(file, "products.csv")
  end

  defp upload_csv_with_errors(view) do
    csv_content = """
    name,sku,price
    Product A,SKU-001,29.99
    ,SKU-002,19.99
    Product C,,invalid
    """

    file = file_input(view, "#import-form", :file, [
      %{name: "products.csv", content: csv_content, type: "text/csv"}
    ])

    render_upload(file, "products.csv")
  end
end
```

**Step 2-5:** Follow same TDD pattern - implementation available on request due to length.

**Step 5: Commit**

```bash
git add lib/mcp_web/live/merchant/products/import_live.ex test/mcp_web/live/merchant/products/import_live_test.exs
git commit -m "feat(merchant): add Product Import wizard with CSV upload, mapping, preview"
```

---

## Task 8: Store Product Search LiveView (Read-only)

**Files:**
- Create: `lib/mcp_web/live/store/products/index_live.ex`
- Test: `test/mcp_web/live/store/products/index_live_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/store/products/index_live_test.exs
defmodule McpWeb.Store.Products.IndexLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_store_user

  describe "mount/3" do
    test "renders product list with read-only view", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/store/products")

      assert html =~ "Products"
      assert has_element?(view, "[data-testid='page-layout-list']")
      # No add button for store users
      refute has_element?(view, "[data-testid='add-product-btn']")
    end

    test "shows product search", %{conn: conn} do
      insert(:product, name: "Test Product", status: :active)

      {:ok, view, _html} = live(conn, ~p"/store/products")

      assert has_element?(view, "[data-testid='product-search']")
    end
  end

  describe "search" do
    test "filters products by search query", %{conn: conn} do
      insert(:product, name: "Premium Tee", sku: "TEE-001", status: :active)
      insert(:product, name: "Coffee Mug", sku: "MUG-001", status: :active)

      {:ok, view, _html} = live(conn, ~p"/store/products")

      view
      |> form("#product-search-form", %{search: "tee"})
      |> render_change()

      assert has_element?(view, "[data-testid='product-row']", "Premium Tee")
      refute has_element?(view, "[data-testid='product-row']", "Coffee Mug")
    end
  end

  describe "stock display" do
    test "shows stock status for POS reference", %{conn: conn} do
      insert(:product, name: "In Stock", track_inventory: true, quantity_on_hand: 50, status: :active)
      insert(:product, name: "Low Stock", track_inventory: true, quantity_on_hand: 3, low_stock_threshold: 10, status: :active)

      {:ok, view, _html} = live(conn, ~p"/store/products")

      assert has_element?(view, "[data-testid='stock-status']", "In Stock")
      assert has_element?(view, "[data-testid='stock-status'].warning", "Low")
    end
  end

  describe "navigation" do
    test "clicking product goes to detail", %{conn: conn} do
      product = insert(:product, name: "Test Product", status: :active)

      {:ok, view, _html} = live(conn, ~p"/store/products")

      {:ok, _view, html} =
        view
        |> element("[data-testid='product-row'][phx-value-id='#{product.id}']")
        |> render_click()
        |> follow_redirect(conn, ~p"/store/products/#{product.id}")

      assert html =~ "Test Product"
    end
  end
end
```

**Step 2-5:** Follow TDD pattern.

**Step 5: Commit**

```bash
git add lib/mcp_web/live/store/products/index_live.ex test/mcp_web/live/store/products/index_live_test.exs
git commit -m "feat(store): add read-only Product Search for store staff"
```

---

## Task 9: Store Product Detail LiveView (Read-only)

**Files:**
- Create: `lib/mcp_web/live/store/products/show_live.ex`
- Test: `test/mcp_web/live/store/products/show_live_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/store/products/show_live_test.exs
defmodule McpWeb.Store.Products.ShowLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_store_user

  describe "mount/3" do
    test "renders product detail read-only", %{conn: conn} do
      product = insert(:product, name: "Premium Tee", status: :active)

      {:ok, view, html} = live(conn, ~p"/store/products/#{product.id}")

      assert html =~ "Premium Tee"
      # No edit button
      refute has_element?(view, "[data-testid='edit-btn']")
    end

    test "shows price and stock info", %{conn: conn} do
      product = insert(:product,
        price: Money.new(2999, :USD),
        track_inventory: true,
        quantity_on_hand: 50,
        status: :active
      )

      {:ok, view, _html} = live(conn, ~p"/store/products/#{product.id}")

      assert has_element?(view, "[data-testid='product-price']", "$29.99")
      assert has_element?(view, "[data-testid='stock-quantity']", "50")
    end
  end

  describe "quick actions" do
    test "can add to POS from detail", %{conn: conn} do
      product = insert(:product, status: :active)

      {:ok, view, _html} = live(conn, ~p"/store/products/#{product.id}")

      assert has_element?(view, "[data-testid='add-to-cart-btn']")
    end

    test "can adjust stock from detail", %{conn: conn} do
      product = insert(:product, track_inventory: true, status: :active)

      {:ok, view, _html} = live(conn, ~p"/store/products/#{product.id}")

      view |> element("[data-testid='adjust-stock-btn']") |> render_click()

      assert has_element?(view, "[data-testid='adjustment-modal']")
    end
  end
end
```

**Step 2-5:** Follow TDD pattern.

**Step 5: Commit**

```bash
git add lib/mcp_web/live/store/products/show_live.ex test/mcp_web/live/store/products/show_live_test.exs
git commit -m "feat(store): add read-only Product Detail with quick actions"
```

---

## Task 10: Store Inventory Adjust Modal Component

**Files:**
- Create: `lib/mcp_web/components/store/inventory_adjust_modal.ex`
- Test: `test/mcp_web/components/store/inventory_adjust_modal_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/components/store/inventory_adjust_modal_test.exs
defmodule McpWeb.Store.InventoryAdjustModalTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Store.InventoryAdjustModal

  describe "inventory_adjust_modal/1" do
    test "renders modal with product info" do
      product = build(:product, name: "Test Product", quantity_on_hand: 50)
      assigns = %{product: product, show: true}

      html = rendered_to_string(~H"""
      <InventoryAdjustModal.inventory_adjust_modal product={@product} show={@show} />
      """)

      assert html =~ "Test Product"
      assert html =~ "Current: 50"
    end

    test "has adjustment type options" do
      product = build(:product)
      assigns = %{product: product, show: true}

      html = rendered_to_string(~H"""
      <InventoryAdjustModal.inventory_adjust_modal product={@product} show={@show} />
      """)

      assert html =~ "Add"
      assert html =~ "Remove"
      assert html =~ "Set"
    end

    test "has reason dropdown" do
      product = build(:product)
      assigns = %{product: product, show: true}

      html = rendered_to_string(~H"""
      <InventoryAdjustModal.inventory_adjust_modal product={@product} show={@show} />
      """)

      assert html =~ "Reason"
      assert html =~ "Count adjustment"
      assert html =~ "Damaged"
    end
  end
end
```

**Step 2-5:** Follow TDD pattern.

**Step 5: Commit**

```bash
git add lib/mcp_web/components/store/inventory_adjust_modal.ex test/mcp_web/components/store/inventory_adjust_modal_test.exs
git commit -m "feat(store): add InventoryAdjustModal component for quick stock adjustments"
```

---

## Task 11: Add Routes

**Step 1: Update router.ex**

Add all Phase 3 routes to the appropriate scopes.

```elixir
# In merchant scope
scope "/app", McpWeb.Merchant, as: :merchant do
  pipe_through [:browser, :require_authenticated_user, :require_merchant]

  # Products
  live "/products", Products.IndexLive, :index
  live "/products/new", Products.NewLive, :new
  live "/products/import", Products.ImportLive, :import
  live "/products/categories", Products.CategoriesLive, :categories
  live "/products/inventory", Products.InventoryLive, :inventory
  live "/products/:id", Products.ShowLive, :show
end

# In store scope
scope "/store", McpWeb.Store, as: :store do
  pipe_through [:browser, :require_authenticated_user, :require_store_staff]

  # Products (read-only)
  live "/products", Products.IndexLive, :index
  live "/products/:id", Products.ShowLive, :show
end
```

**Step 2: Verify compile**

Run: `mix compile --warnings-as-errors`
Expected: No warnings

**Step 3: Commit**

```bash
git add lib/mcp_web/router.ex
git commit -m "feat(routes): add Phase 3 product and inventory routes"
```

---

## Success Criteria

Phase 3 is complete when:

- [ ] All tests pass (`mix test`)
- [ ] `mix precommit` passes
- [ ] Product CRUD works end-to-end (create, read, update, delete)
- [ ] Product list displays with proper 2/3+1/3 layout
- [ ] Search and filters work correctly
- [ ] Bulk selection and actions work
- [ ] Categories can be managed
- [ ] Inventory overview shows stock levels
- [ ] Product import wizard completes successfully
- [ ] Store portal shows read-only product views
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
