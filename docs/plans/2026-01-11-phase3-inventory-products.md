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

## Remaining Tasks (Summary)

The following tasks follow the same TDD pattern:

### Task 3: Merchant Product Detail LiveView
- File: `lib/mcp_web/live/merchant/products/show_live.ex`
- Layout: PageLayout variant `:detail`
- Features: Product info display, edit form, variant management, activity log

### Task 4: Merchant Product Create LiveView
- File: `lib/mcp_web/live/merchant/products/new_live.ex`
- Layout: PageLayout variant `:detail`
- Features: Create form, image upload, variant builder, pricing

### Task 5: Categories Management
- File: `lib/mcp_web/live/merchant/products/categories_live.ex`
- Layout: PageLayout variant `:list`
- Features: Category tree, drag-drop reorder, nested categories

### Task 6: Inventory Overview
- File: `lib/mcp_web/live/merchant/products/inventory_live.ex`
- Layout: PageLayout variant `:table`
- Features: Full-width table, stock levels, adjustments, alerts

### Task 7: Product Import (Focused)
- File: `lib/mcp_web/live/merchant/products/import_live.ex`
- Layout: FocusedLayout with wizard variant
- Features: CSV upload, field mapping, validation preview, import progress

### Task 8: Store Product Search (Read-only)
- File: `lib/mcp_web/live/store/products/index_live.ex`
- Layout: PageLayout variant `:list`
- Features: Read-only view, quick lookup for POS reference

### Task 9: Store Product Detail (Read-only)
- File: `lib/mcp_web/live/store/products/show_live.ex`
- Layout: PageLayout variant `:detail`
- Features: Stock info, pricing, no edit capability

### Task 10: Store Inventory Adjust Modal
- File: `lib/mcp_web/components/store/inventory_adjust_modal.ex`
- Features: Quick stock adjustment from store context

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
