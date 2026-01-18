# Phase 2: Core Commerce Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the critical path for taking payments - POS, Terminal, Customers, and Transactions.

**Architecture:** Build on Phase 1 layout components (PageLayout, StatsRow, ActionSidebar, FocusedLayout). Each feature page uses the exact wireframes from the design docs with proper 2/3+1/3 splits, AI insights sections, and full interactivity.

**Tech Stack:** Phoenix LiveView, Phase 1 layout components, DaisyUI, Ash Framework (for data)

**Reference Documents:**
- `2026-01-11-merchant-portal-features.md` - Merchant wireframes (sections 3.1, 3.2, 2.1, 2.2)
- `2026-01-11-store-portal-features.md` - Store wireframes (sections 2, 3, 6)
- `2026-01-10-ai-portal-ux-design.md` - AI UX patterns

---

## Pre-Implementation: Remove Broken Phase 2 Code

Before starting, remove the existing broken Phase 2 implementation.

**Files to Remove:**
```
lib/mcp_web/live/merchant/customers/index_live.ex
lib/mcp_web/live/merchant/customers/show_live.ex
lib/mcp_web/live/merchant/payments/transactions/index_live.ex
lib/mcp_web/live/merchant/payments/transactions/show_live.ex
lib/mcp_web/live/store/customers/index_live.ex
lib/mcp_web/live/store/customers/show_live.ex
lib/mcp_web/live/store/pos_live.ex
lib/mcp_web/live/store/terminal_live.ex
test/mcp_web/live/merchant/customers/index_live_test.exs
test/mcp_web/live/merchant/customers/show_live_test.exs
test/mcp_web/live/merchant/payments/transactions/index_live_test.exs
test/mcp_web/live/merchant/payments/transactions/show_live_test.exs
test/mcp_web/live/store/customers/index_live_test.exs
test/mcp_web/live/store/customers/show_live_test.exs
test/mcp_web/live/store/pos_live_test.exs
test/mcp_web/live/store/terminal_live_test.exs
```

**Step 1: Remove broken files**

Run:
```bash
rm -f lib/mcp_web/live/merchant/customers/index_live.ex \
      lib/mcp_web/live/merchant/customers/show_live.ex \
      lib/mcp_web/live/merchant/payments/transactions/index_live.ex \
      lib/mcp_web/live/merchant/payments/transactions/show_live.ex \
      lib/mcp_web/live/store/customers/index_live.ex \
      lib/mcp_web/live/store/customers/show_live.ex \
      lib/mcp_web/live/store/pos_live.ex \
      lib/mcp_web/live/store/terminal_live.ex
```

**Step 2: Remove broken test files**

Run:
```bash
rm -f test/mcp_web/live/merchant/customers/index_live_test.exs \
      test/mcp_web/live/merchant/customers/show_live_test.exs \
      test/mcp_web/live/merchant/payments/transactions/index_live_test.exs \
      test/mcp_web/live/merchant/payments/transactions/show_live_test.exs \
      test/mcp_web/live/store/customers/index_live_test.exs \
      test/mcp_web/live/store/customers/show_live_test.exs \
      test/mcp_web/live/store/pos_live_test.exs \
      test/mcp_web/live/store/terminal_live_test.exs
```

**Step 3: Remove routes for broken pages**

In `lib/mcp_web/router.ex`, remove any routes pointing to the deleted LiveViews. Keep routes but comment them out with a note that they'll be re-added.

**Step 4: Verify clean state**

Run:
```bash
mix compile --warnings-as-errors
```

Expected: Compilation succeeds with no warnings about missing modules.

**Step 5: Commit clean state**

```bash
git add -A
git commit -m "chore: remove broken Phase 2 implementation for rebuild"
```

---

## Overview: Features to Build

| # | Feature | Portal | Layout | Design Ref |
|---|---------|--------|--------|------------|
| 1 | POS | Store | E (Focused) | Store Features §2 |
| 2 | Terminal | Store | E (Focused) | Store Features §3 |
| 3 | Customer List | Merchant | B (2/3+1/3 List) | Merchant Features §3.1 |
| 4 | Customer Detail | Merchant | C (2/3+1/3 Detail) | Merchant Features §3.2 |
| 5 | Customer Lookup | Store | B (2/3+1/3 List) | Store Features §6.1 |
| 6 | Customer Card | Store | C (2/3+1/3 Detail) | Store Features §6.2 |
| 7 | Transactions List | Merchant | D (Full-Width Table) | Merchant Features §2.1 |
| 8 | Transaction Detail | Merchant | C (2/3+1/3 Detail) | Merchant Features §2.2 |

---

## Task 1: Store POS - Product Grid Component

**Files:**
- Create: `lib/mcp_web/components/pos/product_grid.ex`
- Test: `test/mcp_web/components/pos/product_grid_test.exs`

**Design Reference:** Store Features §2, wireframe "Main Screen", left panel

### Step 1: Write the failing test

```elixir
# test/mcp_web/components/pos/product_grid_test.exs
defmodule McpWeb.Components.Pos.ProductGridTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Components.Pos.ProductGrid

  describe "product_grid/1" do
    test "renders search input with barcode scan button" do
      html = render_component(&ProductGrid.product_grid/1, %{
        products: [],
        categories: [],
        selected_category: nil,
        search_query: ""
      })

      assert html =~ ~s(placeholder="Search or scan...)
      assert html =~ ~s(data-testid="product-search")
      assert html =~ ~s(data-testid="barcode-scan-btn")
    end

    test "renders category tabs including 'All' tab" do
      categories = ["Apparel", "Drinkware", "Electronics"]

      html = render_component(&ProductGrid.product_grid/1, %{
        products: [],
        categories: categories,
        selected_category: nil,
        search_query: ""
      })

      assert html =~ "All"
      assert html =~ "Apparel"
      assert html =~ "Drinkware"
      assert html =~ "Electronics"
      # All tab should be active when no category selected
      assert html =~ ~s(tab-active)
    end

    test "renders product tiles with image placeholder, name, and price" do
      products = [
        %{id: "1", name: "Premium Tee", price: Decimal.new("29.99"), category: "Apparel", image_url: nil},
        %{id: "2", name: "Coffee Mug", price: Decimal.new("12.00"), category: "Drinkware", image_url: nil}
      ]

      html = render_component(&ProductGrid.product_grid/1, %{
        products: products,
        categories: ["Apparel", "Drinkware"],
        selected_category: nil,
        search_query: ""
      })

      assert html =~ "Premium Tee"
      assert html =~ "$29.99"
      assert html =~ "Coffee Mug"
      assert html =~ "$12.00"
      assert html =~ ~s(data-testid="product-tile")
    end

    test "renders custom item button at bottom" do
      html = render_component(&ProductGrid.product_grid/1, %{
        products: [],
        categories: [],
        selected_category: nil,
        search_query: ""
      })

      assert html =~ ~s(data-testid="custom-item-btn")
      assert html =~ "+ Custom Item"
    end

    test "highlights selected category tab" do
      categories = ["Apparel", "Drinkware"]

      html = render_component(&ProductGrid.product_grid/1, %{
        products: [],
        categories: categories,
        selected_category: "Apparel",
        search_query: ""
      })

      # Apparel should have tab-active, All should not
      assert html =~ ~r/<button[^>]*Apparel[^>]*tab-active/s or
             html =~ ~r/tab-active[^>]*>Apparel/s
    end
  end
end
```

### Step 2: Run test to verify it fails

Run: `mix test test/mcp_web/components/pos/product_grid_test.exs -v`
Expected: FAIL with "module McpWeb.Components.Pos.ProductGrid is not available"

### Step 3: Write minimal implementation

```elixir
# lib/mcp_web/components/pos/product_grid.ex
defmodule McpWeb.Components.Pos.ProductGrid do
  @moduledoc """
  Product grid component for POS interface.

  Displays products in a responsive grid with:
  - Search input with barcode scan button
  - Category tabs for filtering
  - Product tiles with image, name, price
  - Custom item entry button

  Design reference: Store Portal Features §2 - POS wireframe
  """
  use Phoenix.Component

  import McpWeb.Core.CoreComponents, only: [icon: 1, button: 1]

  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :selected_category, :string, default: nil
  attr :search_query, :string, default: ""
  attr :class, :string, default: nil

  def product_grid(assigns) do
    ~H"""
    <div class={["flex flex-col h-full", @class]}>
      <%!-- Search Bar with Barcode Scan --%>
      <div class="flex gap-2 mb-4">
        <div class="flex-1 relative">
          <input
            type="text"
            name="search"
            value={@search_query}
            placeholder="Search or scan..."
            phx-change="search_products"
            phx-debounce="300"
            data-testid="product-search"
            class="input input-bordered w-full pr-10"
          />
          <button
            type="button"
            data-testid="barcode-scan-btn"
            class="absolute right-2 top-1/2 -translate-y-1/2 btn btn-ghost btn-sm btn-circle"
            phx-click="scan_barcode"
          >
            <.icon name="hero-qr-code" class="size-5" />
          </button>
        </div>
      </div>

      <%!-- Category Tabs --%>
      <div class="tabs tabs-boxed mb-4 bg-base-200 flex-wrap">
        <button
          type="button"
          class={["tab", is_nil(@selected_category) && "tab-active"]}
          phx-click="select_category"
          phx-value-category=""
        >
          All
        </button>
        <button
          :for={category <- @categories}
          type="button"
          class={["tab", @selected_category == category && "tab-active"]}
          phx-click="select_category"
          phx-value-category={category}
        >
          {category}
        </button>
      </div>

      <%!-- Product Grid --%>
      <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3 overflow-y-auto flex-1">
        <.product_tile :for={product <- @products} product={product} />
      </div>

      <%!-- Bottom Actions --%>
      <div class="flex gap-2 mt-4 pt-4 border-t border-base-300">
        <button
          type="button"
          data-testid="barcode-scan-btn"
          class="btn btn-outline flex-1"
          phx-click="scan_barcode"
        >
          <.icon name="hero-qr-code" class="size-5 mr-2" /> Scan Barcode
        </button>
        <button
          type="button"
          data-testid="custom-item-btn"
          class="btn btn-outline flex-1"
          phx-click="add_custom_item"
        >
          <.icon name="hero-plus" class="size-5 mr-2" /> + Custom Item
        </button>
      </div>
    </div>
    """
  end

  attr :product, :map, required: true

  defp product_tile(assigns) do
    ~H"""
    <button
      type="button"
      data-testid="product-tile"
      class={[
        "flex flex-col p-3 rounded-xl border-2 border-transparent",
        "bg-base-200 hover:border-primary hover:bg-base-300",
        "transition-all duration-200 cursor-pointer text-left"
      ]}
      phx-click="add_to_cart"
      phx-value-id={@product.id}
    >
      <%!-- Product Image or Placeholder --%>
      <div class="aspect-square w-full bg-base-300 rounded-lg mb-2 flex items-center justify-center overflow-hidden">
        <img
          :if={@product[:image_url]}
          src={@product.image_url}
          alt={@product.name}
          class="w-full h-full object-cover"
        />
        <.icon :if={!@product[:image_url]} name="hero-cube" class="size-10 text-base-content/30" />
      </div>

      <%!-- Product Name --%>
      <span class="font-medium text-sm text-base-content line-clamp-2 mb-1">
        {@product.name}
      </span>

      <%!-- Product Price --%>
      <span class="text-primary font-semibold text-lg">
        ${format_price(@product.price)}
      </span>
    </button>
    """
  end

  defp format_price(%Decimal{} = price) do
    price |> Decimal.round(2) |> Decimal.to_string()
  end

  defp format_price(price) when is_number(price) do
    :erlang.float_to_binary(price / 1, decimals: 2)
  end

  defp format_price(price) when is_binary(price), do: price
end
```

### Step 4: Run test to verify it passes

Run: `mix test test/mcp_web/components/pos/product_grid_test.exs -v`
Expected: PASS - all tests green

### Step 5: Commit

```bash
git add lib/mcp_web/components/pos/product_grid.ex test/mcp_web/components/pos/product_grid_test.exs
git commit -m "feat(pos): add ProductGrid component with search, categories, tiles"
```

---

## Task 2: Store POS - Cart Component

**Files:**
- Create: `lib/mcp_web/components/pos/cart.ex`
- Test: `test/mcp_web/components/pos/cart_test.exs`

**Design Reference:** Store Features §2, wireframe "Main Screen", right panel (CART section)

### Step 1: Write the failing test

```elixir
# test/mcp_web/components/pos/cart_test.exs
defmodule McpWeb.Components.Pos.CartTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Components.Pos.Cart

  describe "cart/1" do
    test "renders empty cart message when no items" do
      html = render_component(&Cart.cart/1, %{
        items: [],
        customer: nil,
        subtotal: Decimal.new("0.00"),
        tax: Decimal.new("0.00"),
        total: Decimal.new("0.00")
      })

      assert html =~ "Cart is empty"
      assert html =~ ~s(data-testid="empty-cart")
    end

    test "renders customer add button when no customer" do
      html = render_component(&Cart.cart/1, %{
        items: [],
        customer: nil,
        subtotal: Decimal.new("0.00"),
        tax: Decimal.new("0.00"),
        total: Decimal.new("0.00")
      })

      assert html =~ "+ Add Customer"
      assert html =~ ~s(data-testid="add-customer-btn")
    end

    test "renders customer info when customer attached" do
      customer = %{
        id: "1",
        name: "John Smith",
        loyalty_points: 580,
        loyalty_tier: :vip
      }

      html = render_component(&Cart.cart/1, %{
        items: [],
        customer: customer,
        subtotal: Decimal.new("0.00"),
        tax: Decimal.new("0.00"),
        total: Decimal.new("0.00")
      })

      assert html =~ "John Smith"
      assert html =~ "VIP"
      assert html =~ "580 pts"
      assert html =~ ~s(data-testid="customer-info")
    end

    test "renders cart items with quantity controls" do
      items = [
        %{
          id: "item-1",
          product: %{id: "1", name: "Premium Tee (L, Blue)", price: Decimal.new("29.99")},
          quantity: 1,
          subtotal: Decimal.new("29.99")
        },
        %{
          id: "item-2",
          product: %{id: "2", name: "Coffee Mug", price: Decimal.new("12.00")},
          quantity: 2,
          subtotal: Decimal.new("24.00")
        }
      ]

      html = render_component(&Cart.cart/1, %{
        items: items,
        customer: nil,
        subtotal: Decimal.new("53.99"),
        tax: Decimal.new("4.45"),
        total: Decimal.new("58.44")
      })

      assert html =~ "Premium Tee (L, Blue)"
      assert html =~ "$29.99"
      assert html =~ "Coffee Mug"
      # Quantity controls
      assert html =~ ~s(data-testid="qty-decrease")
      assert html =~ ~s(data-testid="qty-increase")
      assert html =~ ~s(data-testid="remove-item")
    end

    test "renders totals section" do
      html = render_component(&Cart.cart/1, %{
        items: [%{id: "1", product: %{id: "1", name: "Test", price: Decimal.new("50.00")}, quantity: 1, subtotal: Decimal.new("50.00")}],
        customer: nil,
        subtotal: Decimal.new("53.99"),
        tax: Decimal.new("4.45"),
        total: Decimal.new("58.44")
      })

      assert html =~ "Subtotal"
      assert html =~ "$53.99"
      assert html =~ "Tax"
      assert html =~ "$4.45"
      assert html =~ "TOTAL"
      assert html =~ "$58.44"
    end

    test "renders pay button with total amount" do
      html = render_component(&Cart.cart/1, %{
        items: [%{id: "1", product: %{id: "1", name: "Test", price: Decimal.new("50.00")}, quantity: 1, subtotal: Decimal.new("50.00")}],
        customer: nil,
        subtotal: Decimal.new("53.99"),
        tax: Decimal.new("4.45"),
        total: Decimal.new("58.44")
      })

      assert html =~ "PAY"
      assert html =~ "$58.44"
      assert html =~ ~s(data-testid="pay-btn")
    end

    test "renders discount and note buttons" do
      html = render_component(&Cart.cart/1, %{
        items: [%{id: "1", product: %{id: "1", name: "Test", price: Decimal.new("50.00")}, quantity: 1, subtotal: Decimal.new("50.00")}],
        customer: nil,
        subtotal: Decimal.new("50.00"),
        tax: Decimal.new("0.00"),
        total: Decimal.new("50.00")
      })

      assert html =~ "+ Discount"
      assert html =~ "+ Note"
    end

    test "renders hold and clear buttons" do
      html = render_component(&Cart.cart/1, %{
        items: [%{id: "1", product: %{id: "1", name: "Test", price: Decimal.new("50.00")}, quantity: 1, subtotal: Decimal.new("50.00")}],
        customer: nil,
        subtotal: Decimal.new("50.00"),
        tax: Decimal.new("0.00"),
        total: Decimal.new("50.00")
      })

      assert html =~ "Hold Order"
      assert html =~ "Clear Cart"
    end
  end
end
```

### Step 2: Run test to verify it fails

Run: `mix test test/mcp_web/components/pos/cart_test.exs -v`
Expected: FAIL with "module McpWeb.Components.Pos.Cart is not available"

### Step 3: Write minimal implementation

```elixir
# lib/mcp_web/components/pos/cart.ex
defmodule McpWeb.Components.Pos.Cart do
  @moduledoc """
  Shopping cart component for POS interface.

  Displays:
  - Customer info with loyalty status (or add customer button)
  - Cart items with quantity controls (+/-, remove)
  - Per-item notes
  - Discount and note actions
  - Subtotal, tax, and total
  - Pay button
  - Hold order and clear cart buttons

  Design reference: Store Portal Features §2 - POS wireframe, CART section
  """
  use Phoenix.Component

  import McpWeb.Core.CoreComponents, only: [icon: 1, button: 1]

  attr :items, :list, required: true
  attr :customer, :map, default: nil
  attr :subtotal, Decimal, required: true
  attr :tax, Decimal, required: true
  attr :total, Decimal, required: true
  attr :class, :string, default: nil

  def cart(assigns) do
    ~H"""
    <div class={["flex flex-col h-full bg-base-100 rounded-box p-4", @class]}>
      <h2 class="text-lg font-bold mb-4">CART</h2>

      <%!-- Customer Section --%>
      <.customer_section customer={@customer} />

      <div class="divider my-2"></div>

      <%!-- Cart Items --%>
      <div class="flex-1 overflow-y-auto">
        <.empty_cart :if={@items == []} />
        <.cart_items :if={@items != []} items={@items} />
      </div>

      <%!-- Discount / Note Actions --%>
      <div :if={@items != []} class="flex gap-2 my-2">
        <button type="button" class="btn btn-ghost btn-sm flex-1" phx-click="add_discount">
          + Discount
        </button>
        <button type="button" class="btn btn-ghost btn-sm flex-1" phx-click="add_note">
          + Note
        </button>
      </div>

      <div class="divider my-2"></div>

      <%!-- Totals --%>
      <.totals_section subtotal={@subtotal} tax={@tax} total={@total} />

      <%!-- Pay Button --%>
      <button
        type="button"
        data-testid="pay-btn"
        class="btn btn-primary btn-lg w-full mt-4"
        phx-click="checkout"
        disabled={@items == []}
      >
        <.icon name="hero-credit-card" class="size-6 mr-2" />
        PAY ${format_price(@total)}
      </button>

      <%!-- Hold / Clear Actions --%>
      <div :if={@items != []} class="flex gap-2 mt-3">
        <button type="button" class="btn btn-outline btn-sm flex-1" phx-click="hold_order">
          Hold Order
        </button>
        <button type="button" class="btn btn-ghost btn-sm flex-1 text-error" phx-click="clear_cart">
          Clear Cart
        </button>
      </div>
    </div>
    """
  end

  attr :customer, :map, default: nil

  defp customer_section(assigns) do
    ~H"""
    <div class="mb-2">
      <div :if={@customer} data-testid="customer-info" class="bg-base-200 rounded-lg p-3">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <div class="avatar placeholder">
              <div class="bg-primary text-primary-content rounded-full w-8">
                <span class="text-xs">{initials(@customer.name)}</span>
              </div>
            </div>
            <div>
              <div class="font-medium">{@customer.name}</div>
              <div class="text-xs text-base-content/60">
                <span :if={@customer[:loyalty_tier] == :vip} class="badge badge-warning badge-xs mr-1">VIP</span>
                {@customer[:loyalty_points] || 0} pts
              </div>
            </div>
          </div>
          <button type="button" class="btn btn-ghost btn-xs btn-circle" phx-click="remove_customer">
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>
      </div>

      <button
        :if={!@customer}
        type="button"
        data-testid="add-customer-btn"
        class="btn btn-outline btn-sm w-full"
        phx-click="add_customer"
      >
        <.icon name="hero-user-plus" class="size-4 mr-1" /> + Add Customer
      </button>
    </div>
    """
  end

  defp empty_cart(assigns) do
    ~H"""
    <div data-testid="empty-cart" class="text-center py-12 text-base-content/50">
      <.icon name="hero-shopping-cart" class="size-16 mx-auto mb-4 opacity-30" />
      <p class="text-lg">Cart is empty</p>
      <p class="text-sm mt-1">Tap products to add them</p>
    </div>
    """
  end

  attr :items, :list, required: true

  defp cart_items(assigns) do
    ~H"""
    <div class="space-y-2">
      <.cart_item :for={item <- @items} item={item} />
    </div>
    """
  end

  attr :item, :map, required: true

  defp cart_item(assigns) do
    ~H"""
    <div class="bg-base-200/50 rounded-lg p-3">
      <div class="flex items-start justify-between gap-2">
        <div class="flex-1 min-w-0">
          <div class="font-medium text-sm truncate">{@item.product.name}</div>
          <div class="text-xs text-base-content/60">${format_price(@item.product.price)}</div>
          <div :if={@item[:note]} class="text-xs text-info mt-1">
            − {@item.note}
          </div>
        </div>
        <div class="text-right">
          <div class="font-semibold">${format_price(@item.subtotal)}</div>
        </div>
      </div>

      <%!-- Quantity Controls --%>
      <div class="flex items-center justify-between mt-2">
        <div class="flex items-center gap-1">
          <button
            type="button"
            data-testid="qty-decrease"
            class="btn btn-ghost btn-xs btn-circle"
            phx-click="decrease_qty"
            phx-value-id={@item.id}
          >
            <.icon name="hero-minus" class="size-3" />
          </button>
          <span class="w-8 text-center font-medium">{@item.quantity}</span>
          <button
            type="button"
            data-testid="qty-increase"
            class="btn btn-ghost btn-xs btn-circle"
            phx-click="increase_qty"
            phx-value-id={@item.id}
          >
            <.icon name="hero-plus" class="size-3" />
          </button>
        </div>
        <button
          type="button"
          data-testid="remove-item"
          class="btn btn-ghost btn-xs text-error"
          phx-click="remove_item"
          phx-value-id={@item.id}
        >
          <.icon name="hero-trash" class="size-4" />
        </button>
      </div>
    </div>
    """
  end

  attr :subtotal, Decimal, required: true
  attr :tax, Decimal, required: true
  attr :total, Decimal, required: true

  defp totals_section(assigns) do
    ~H"""
    <div class="space-y-1 text-sm">
      <div class="flex justify-between">
        <span class="text-base-content/70">Subtotal</span>
        <span>${format_price(@subtotal)}</span>
      </div>
      <div class="flex justify-between">
        <span class="text-base-content/70">Tax</span>
        <span>${format_price(@tax)}</span>
      </div>
      <div class="flex justify-between text-lg font-bold pt-2 border-t border-base-300">
        <span>TOTAL</span>
        <span>${format_price(@total)}</span>
      </div>
    </div>
    """
  end

  defp format_price(%Decimal{} = price) do
    price |> Decimal.round(2) |> Decimal.to_string()
  end

  defp format_price(price) when is_number(price) do
    :erlang.float_to_binary(price / 1, decimals: 2)
  end

  defp initials(name) when is_binary(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  defp initials(_), do: "?"
end
```

### Step 4: Run test to verify it passes

Run: `mix test test/mcp_web/components/pos/cart_test.exs -v`
Expected: PASS - all tests green

### Step 5: Commit

```bash
git add lib/mcp_web/components/pos/cart.ex test/mcp_web/components/pos/cart_test.exs
git commit -m "feat(pos): add Cart component with customer, items, totals"
```

---

## Task 3: Store POS - Payment Modal Component

**Files:**
- Create: `lib/mcp_web/components/pos/payment_modal.ex`
- Test: `test/mcp_web/components/pos/payment_modal_test.exs`

**Design Reference:** Store Features §2, wireframe "Payment Screen"

### Step 1: Write the failing test

```elixir
# test/mcp_web/components/pos/payment_modal_test.exs
defmodule McpWeb.Components.Pos.PaymentModalTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Components.Pos.PaymentModal

  describe "payment_modal/1" do
    test "renders total due prominently" do
      html = render_component(&PaymentModal.payment_modal/1, %{
        total: Decimal.new("58.44"),
        customer: nil,
        show: true
      })

      assert html =~ "Total Due:"
      assert html =~ "$58.44"
    end

    test "renders all payment method buttons" do
      html = render_component(&PaymentModal.payment_modal/1, %{
        total: Decimal.new("100.00"),
        customer: nil,
        show: true
      })

      assert html =~ "CARD READER"
      assert html =~ "CASH"
      assert html =~ "SPLIT"
      assert html =~ "MANUAL ENTRY"
      assert html =~ "PAYMENT LINK"
      assert html =~ "OTHER"
    end

    test "renders loyalty section when customer has points" do
      customer = %{
        name: "John Smith",
        loyalty_points: 580,
        loyalty_value: Decimal.new("58.00")
      }

      html = render_component(&PaymentModal.payment_modal/1, %{
        total: Decimal.new("58.44"),
        customer: customer,
        show: true
      })

      assert html =~ "LOYALTY"
      assert html =~ "580 points"
      assert html =~ "$58.00 value"
      assert html =~ "Apply points"
    end

    test "renders tip options" do
      html = render_component(&PaymentModal.payment_modal/1, %{
        total: Decimal.new("58.44"),
        customer: nil,
        show: true
      })

      assert html =~ "TIP"
      assert html =~ "No Tip"
      assert html =~ "15%"
      assert html =~ "18%"
      assert html =~ "20%"
      assert html =~ "Custom"
    end

    test "renders back button" do
      html = render_component(&PaymentModal.payment_modal/1, %{
        total: Decimal.new("58.44"),
        customer: nil,
        show: true
      })

      assert html =~ "← Back"
      assert html =~ ~s(phx-click="cancel_payment")
    end
  end
end
```

### Step 2: Run test to verify it fails

Run: `mix test test/mcp_web/components/pos/payment_modal_test.exs -v`
Expected: FAIL with "module McpWeb.Components.Pos.PaymentModal is not available"

### Step 3: Write minimal implementation

```elixir
# lib/mcp_web/components/pos/payment_modal.ex
defmodule McpWeb.Components.Pos.PaymentModal do
  @moduledoc """
  Payment modal for POS checkout flow.

  Displays payment method selection with:
  - Total due prominently displayed
  - Payment method grid (Card, Cash, Split, Manual, Link, Other)
  - Loyalty points section (if customer attached)
  - Tip selection
  - Back button

  Design reference: Store Portal Features §2 - Payment Screen wireframe
  """
  use Phoenix.Component

  import McpWeb.Core.CoreComponents, only: [icon: 1]

  attr :total, Decimal, required: true
  attr :customer, :map, default: nil
  attr :show, :boolean, default: false
  attr :selected_tip, :atom, default: nil
  attr :class, :string, default: nil

  def payment_modal(assigns) do
    ~H"""
    <div
      :if={@show}
      class="fixed inset-0 bg-black/60 flex items-center justify-center z-50"
      phx-click="cancel_payment"
    >
      <div
        class={["bg-base-100 rounded-2xl w-full max-w-2xl mx-4 overflow-hidden", @class]}
        phx-click-away="cancel_payment"
      >
        <%!-- Header --%>
        <div class="flex items-center justify-between p-4 border-b border-base-300">
          <button type="button" class="btn btn-ghost btn-sm" phx-click="cancel_payment">
            ← Back
          </button>
          <h2 class="text-xl font-bold">PAYMENT</h2>
          <div class="w-20"></div>
        </div>

        <div class="p-6">
          <%!-- Total Due --%>
          <div class="text-center mb-6">
            <div class="text-base-content/60 text-sm">Total Due:</div>
            <div class="text-4xl font-bold">${format_price(@total)}</div>
          </div>

          <%!-- Payment Methods Grid --%>
          <div class="grid grid-cols-3 gap-4 mb-6">
            <.payment_method_btn
              icon="hero-credit-card"
              label="CARD READER"
              sublabel="Tap, Insert, or Swipe"
              event="pay_card_reader"
            />
            <.payment_method_btn
              icon="hero-banknotes"
              label="CASH"
              sublabel="Bills & Coins"
              event="pay_cash"
            />
            <.payment_method_btn
              icon="hero-scissors"
              label="SPLIT"
              sublabel="Multiple Methods"
              event="pay_split"
            />
            <.payment_method_btn
              icon="hero-command-line"
              label="MANUAL ENTRY"
              sublabel="Type Card #"
              event="pay_manual"
            />
            <.payment_method_btn
              icon="hero-device-phone-mobile"
              label="PAYMENT LINK"
              sublabel="Send to Customer"
              event="pay_link"
            />
            <.payment_method_btn
              icon="hero-gift"
              label="OTHER"
              sublabel="Gift Card, Check, etc"
              event="pay_other"
            />
          </div>

          <%!-- Loyalty Section --%>
          <.loyalty_section :if={@customer && @customer[:loyalty_points]} customer={@customer} total={@total} />

          <%!-- Tip Section --%>
          <.tip_section total={@total} selected={@selected_tip} />
        </div>
      </div>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :sublabel, :string, required: true
  attr :event, :string, required: true

  defp payment_method_btn(assigns) do
    ~H"""
    <button
      type="button"
      class="btn btn-outline h-auto py-4 flex flex-col items-center gap-2"
      phx-click={@event}
    >
      <.icon name={@icon} class="size-8" />
      <div class="font-semibold text-xs">{@label}</div>
      <div class="text-xs text-base-content/60 font-normal">{@sublabel}</div>
    </button>
    """
  end

  attr :customer, :map, required: true
  attr :total, Decimal, required: true

  defp loyalty_section(assigns) do
    ~H"""
    <div class="bg-base-200 rounded-lg p-4 mb-6">
      <div class="font-semibold mb-2">LOYALTY</div>
      <div class="text-sm text-base-content/70 mb-3">
        {@customer.name} has {@customer.loyalty_points} points (= ${format_price(@customer[:loyalty_value] || Decimal.new("0"))} value)
      </div>
      <label class="flex items-center gap-2 cursor-pointer">
        <input type="checkbox" class="checkbox checkbox-primary" phx-click="toggle_loyalty" />
        <span>Apply points</span>
      </label>
    </div>
    """
  end

  attr :total, Decimal, required: true
  attr :selected, :atom, default: nil

  defp tip_section(assigns) do
    tip_15 = Decimal.mult(assigns.total, Decimal.new("0.15")) |> Decimal.round(2)
    tip_18 = Decimal.mult(assigns.total, Decimal.new("0.18")) |> Decimal.round(2)
    tip_20 = Decimal.mult(assigns.total, Decimal.new("0.20")) |> Decimal.round(2)

    assigns = assign(assigns, tip_15: tip_15, tip_18: tip_18, tip_20: tip_20)

    ~H"""
    <div class="bg-base-200 rounded-lg p-4">
      <div class="font-semibold mb-3">TIP</div>
      <div class="flex flex-wrap gap-2">
        <button
          type="button"
          class={["btn btn-sm", @selected == :none && "btn-primary"]}
          phx-click="select_tip"
          phx-value-tip="none"
        >
          No Tip
        </button>
        <button
          type="button"
          class={["btn btn-sm", @selected == :tip_15 && "btn-primary"]}
          phx-click="select_tip"
          phx-value-tip="15"
        >
          15% ${format_price(@tip_15)}
        </button>
        <button
          type="button"
          class={["btn btn-sm", @selected == :tip_18 && "btn-primary"]}
          phx-click="select_tip"
          phx-value-tip="18"
        >
          18% ${format_price(@tip_18)}
        </button>
        <button
          type="button"
          class={["btn btn-sm", @selected == :tip_20 && "btn-primary"]}
          phx-click="select_tip"
          phx-value-tip="20"
        >
          20% ${format_price(@tip_20)}
        </button>
        <button
          type="button"
          class={["btn btn-sm", @selected == :custom && "btn-primary"]}
          phx-click="select_tip"
          phx-value-tip="custom"
        >
          Custom
        </button>
      </div>
    </div>
    """
  end

  defp format_price(%Decimal{} = price) do
    price |> Decimal.round(2) |> Decimal.to_string()
  end
end
```

### Step 4: Run test to verify it passes

Run: `mix test test/mcp_web/components/pos/payment_modal_test.exs -v`
Expected: PASS - all tests green

### Step 5: Commit

```bash
git add lib/mcp_web/components/pos/payment_modal.ex test/mcp_web/components/pos/payment_modal_test.exs
git commit -m "feat(pos): add PaymentModal with methods, loyalty, tips"
```

---

## Task 4: Store POS LiveView

**Files:**
- Create: `lib/mcp_web/live/store/pos_live.ex`
- Test: `test/mcp_web/live/store/pos_live_test.exs`

**Design Reference:** Store Features §2, complete POS flow

### Step 1: Write the failing test

```elixir
# test/mcp_web/live/store/pos_live_test.exs
defmodule McpWeb.Store.PosLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "POS LiveView" do
    setup %{conn: conn} do
      {:ok, conn: log_in_user(conn, insert_user_fixture())}
    end

    test "renders POS interface with focused layout", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/app/stores/test-store/pos")

      # Uses focused layout
      assert html =~ "Point of Sale"
      assert html =~ ~s(data-testid="pos-exit-btn")

      # Has product grid
      assert html =~ ~s(data-testid="product-search")
      assert html =~ ~s(data-testid="product-grid")

      # Has cart
      assert html =~ "CART"
      assert html =~ ~s(data-testid="empty-cart")
    end

    test "can search products", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/stores/test-store/pos")

      html = view
             |> element(~s([data-testid="product-search"]))
             |> render_change(%{search: "Coffee"})

      # Should filter products (exact assertion depends on sample data)
      assert html =~ "Coffee" or html =~ "product-tile"
    end

    test "can add product to cart", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/stores/test-store/pos")

      # Click first product tile
      view |> element(~s([data-testid="product-tile"]), "") |> render_click()

      # Cart should show item
      html = render(view)
      refute html =~ ~s(data-testid="empty-cart")
      assert html =~ ~s(data-testid="cart-item")
    end

    test "can adjust quantity in cart", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/stores/test-store/pos")

      # Add product
      view |> element(~s([data-testid="product-tile"]), "") |> render_click()

      # Increase quantity
      view |> element(~s([data-testid="qty-increase"])) |> render_click()

      html = render(view)
      # Should show qty 2
      assert html =~ ">2<"
    end

    test "can remove item from cart", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/stores/test-store/pos")

      # Add product
      view |> element(~s([data-testid="product-tile"]), "") |> render_click()

      # Remove it
      view |> element(~s([data-testid="remove-item"])) |> render_click()

      # Cart should be empty again
      html = render(view)
      assert html =~ ~s(data-testid="empty-cart")
    end

    test "can open payment modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/stores/test-store/pos")

      # Add product first
      view |> element(~s([data-testid="product-tile"]), "") |> render_click()

      # Click pay button
      view |> element(~s([data-testid="pay-btn"])) |> render_click()

      html = render(view)
      assert html =~ "PAYMENT"
      assert html =~ "Total Due:"
      assert html =~ "CARD READER"
    end

    test "pay button disabled when cart empty", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/test-store/pos")

      assert html =~ ~s(data-testid="pay-btn")
      assert html =~ "disabled"
    end
  end
end
```

### Step 2: Run test to verify it fails

Run: `mix test test/mcp_web/live/store/pos_live_test.exs -v`
Expected: FAIL with module not available or route not found

### Step 3: Write minimal implementation

```elixir
# lib/mcp_web/live/store/pos_live.ex
defmodule McpWeb.Store.PosLive do
  @moduledoc """
  Point of Sale LiveView for Store portal.

  Provides a focused, distraction-free interface for in-person sales:
  - Product grid with search and category filtering
  - Shopping cart with quantity controls
  - Customer lookup and loyalty integration
  - Payment flow with multiple methods

  Uses FocusedLayout with two-panel variant (60/40 split).

  Design reference: Store Portal Features §2 - POS
  """
  use McpWeb, :live_view

  import McpWeb.Portal.FocusedLayout, only: [focused_layout: 1]
  import McpWeb.Components.Pos.ProductGrid, only: [product_grid: 1]
  import McpWeb.Components.Pos.Cart, only: [cart: 1]
  import McpWeb.Components.Pos.PaymentModal, only: [payment_modal: 1]

  @impl true
  def mount(%{"store_slug" => store_slug}, _session, socket) do
    products = load_products()
    categories = extract_categories(products)

    socket =
      socket
      |> assign(:page_title, "Point of Sale")
      |> assign(:store_slug, store_slug)
      |> assign(:products, products)
      |> assign(:filtered_products, products)
      |> assign(:categories, categories)
      |> assign(:selected_category, nil)
      |> assign(:search_query, "")
      |> assign(:cart_items, [])
      |> assign(:customer, nil)
      |> assign(:subtotal, Decimal.new("0.00"))
      |> assign(:tax, Decimal.new("0.00"))
      |> assign(:total, Decimal.new("0.00"))
      |> assign(:show_payment, false)
      |> assign(:selected_tip, nil)

    {:ok, socket, layout: {McpWeb.Layouts, :focused}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.focused_layout
      title="Point of Sale"
      exit={~p"/app/stores/#{@store_slug}/dashboard"}
    >
      <:left_panel>
        <div data-testid="product-grid">
          <.product_grid
            products={@filtered_products}
            categories={@categories}
            selected_category={@selected_category}
            search_query={@search_query}
          />
        </div>
      </:left_panel>

      <:right_panel>
        <.cart
          items={@cart_items}
          customer={@customer}
          subtotal={@subtotal}
          tax={@tax}
          total={@total}
        />
      </:right_panel>
    </.focused_layout>

    <.payment_modal
      total={@total}
      customer={@customer}
      show={@show_payment}
      selected_tip={@selected_tip}
    />
    """
  end

  # Event Handlers

  @impl true
  def handle_event("search_products", %{"search" => query}, socket) do
    filtered = filter_products(socket.assigns.products, query, socket.assigns.selected_category)

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:filtered_products, filtered)}
  end

  @impl true
  def handle_event("select_category", %{"category" => ""}, socket) do
    filtered = filter_products(socket.assigns.products, socket.assigns.search_query, nil)

    {:noreply,
     socket
     |> assign(:selected_category, nil)
     |> assign(:filtered_products, filtered)}
  end

  @impl true
  def handle_event("select_category", %{"category" => category}, socket) do
    filtered = filter_products(socket.assigns.products, socket.assigns.search_query, category)

    {:noreply,
     socket
     |> assign(:selected_category, category)
     |> assign(:filtered_products, filtered)}
  end

  @impl true
  def handle_event("add_to_cart", %{"id" => product_id}, socket) do
    product = Enum.find(socket.assigns.products, &(&1.id == product_id))

    if product do
      cart_items = add_to_cart(socket.assigns.cart_items, product)
      {subtotal, tax, total} = calculate_totals(cart_items)

      {:noreply,
       socket
       |> assign(:cart_items, cart_items)
       |> assign(:subtotal, subtotal)
       |> assign(:tax, tax)
       |> assign(:total, total)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("increase_qty", %{"id" => item_id}, socket) do
    cart_items = update_quantity(socket.assigns.cart_items, item_id, 1)
    {subtotal, tax, total} = calculate_totals(cart_items)

    {:noreply,
     socket
     |> assign(:cart_items, cart_items)
     |> assign(:subtotal, subtotal)
     |> assign(:tax, tax)
     |> assign(:total, total)}
  end

  @impl true
  def handle_event("decrease_qty", %{"id" => item_id}, socket) do
    cart_items = update_quantity(socket.assigns.cart_items, item_id, -1)
    {subtotal, tax, total} = calculate_totals(cart_items)

    {:noreply,
     socket
     |> assign(:cart_items, cart_items)
     |> assign(:subtotal, subtotal)
     |> assign(:tax, tax)
     |> assign(:total, total)}
  end

  @impl true
  def handle_event("remove_item", %{"id" => item_id}, socket) do
    cart_items = Enum.reject(socket.assigns.cart_items, &(&1.id == item_id))
    {subtotal, tax, total} = calculate_totals(cart_items)

    {:noreply,
     socket
     |> assign(:cart_items, cart_items)
     |> assign(:subtotal, subtotal)
     |> assign(:tax, tax)
     |> assign(:total, total)}
  end

  @impl true
  def handle_event("checkout", _params, socket) do
    if socket.assigns.cart_items != [] do
      {:noreply, assign(socket, :show_payment, true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_payment", _params, socket) do
    {:noreply, assign(socket, :show_payment, false)}
  end

  @impl true
  def handle_event("select_tip", %{"tip" => tip}, socket) do
    tip_atom = case tip do
      "none" -> :none
      "15" -> :tip_15
      "18" -> :tip_18
      "20" -> :tip_20
      "custom" -> :custom
      _ -> nil
    end

    {:noreply, assign(socket, :selected_tip, tip_atom)}
  end

  @impl true
  def handle_event("pay_" <> _method, _params, socket) do
    # Process payment (placeholder - will integrate with payment gateway)
    {:noreply,
     socket
     |> assign(:cart_items, [])
     |> assign(:subtotal, Decimal.new("0.00"))
     |> assign(:tax, Decimal.new("0.00"))
     |> assign(:total, Decimal.new("0.00"))
     |> assign(:show_payment, false)
     |> assign(:customer, nil)
     |> put_flash(:info, "Payment successful!")}
  end

  @impl true
  def handle_event("clear_cart", _params, socket) do
    {:noreply,
     socket
     |> assign(:cart_items, [])
     |> assign(:subtotal, Decimal.new("0.00"))
     |> assign(:tax, Decimal.new("0.00"))
     |> assign(:total, Decimal.new("0.00"))}
  end

  @impl true
  def handle_event("add_customer", _params, socket) do
    # Placeholder - will open customer lookup modal
    {:noreply, put_flash(socket, :info, "Customer lookup coming soon")}
  end

  @impl true
  def handle_event("remove_customer", _params, socket) do
    {:noreply, assign(socket, :customer, nil)}
  end

  @impl true
  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  # Private Functions

  defp load_products do
    # Sample products - replace with Ash query
    [
      %{id: "1", name: "Premium Tee", price: Decimal.new("29.99"), category: "Apparel", image_url: nil},
      %{id: "2", name: "Coffee Mug", price: Decimal.new("12.00"), category: "Drinkware", image_url: nil},
      %{id: "3", name: "Backpack", price: Decimal.new("49.00"), category: "Bags", image_url: nil},
      %{id: "4", name: "Water Bottle", price: Decimal.new("24.99"), category: "Drinkware", image_url: nil},
      %{id: "5", name: "Cap", price: Decimal.new("19.99"), category: "Apparel", image_url: nil},
      %{id: "6", name: "Tote Bag", price: Decimal.new("35.00"), category: "Bags", image_url: nil},
      %{id: "7", name: "Phone Case", price: Decimal.new("15.00"), category: "Electronics", image_url: nil},
      %{id: "8", name: "Laptop Stand", price: Decimal.new("45.00"), category: "Electronics", image_url: nil},
      %{id: "9", name: "Headphones", price: Decimal.new("79.00"), category: "Electronics", image_url: nil}
    ]
  end

  defp extract_categories(products) do
    products
    |> Enum.map(& &1.category)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp filter_products(products, query, category) do
    products
    |> maybe_filter_by_category(category)
    |> maybe_filter_by_query(query)
  end

  defp maybe_filter_by_category(products, nil), do: products
  defp maybe_filter_by_category(products, ""), do: products
  defp maybe_filter_by_category(products, category) do
    Enum.filter(products, &(&1.category == category))
  end

  defp maybe_filter_by_query(products, nil), do: products
  defp maybe_filter_by_query(products, ""), do: products
  defp maybe_filter_by_query(products, query) do
    query_lower = String.downcase(query)
    Enum.filter(products, fn p -> String.downcase(p.name) =~ query_lower end)
  end

  defp add_to_cart(cart_items, product) do
    case Enum.find_index(cart_items, &(&1.product.id == product.id)) do
      nil ->
        item_id = "item-#{System.unique_integer([:positive])}"
        cart_items ++ [%{
          id: item_id,
          product: product,
          quantity: 1,
          subtotal: product.price
        }]

      index ->
        List.update_at(cart_items, index, fn item ->
          new_qty = item.quantity + 1
          %{item | quantity: new_qty, subtotal: Decimal.mult(product.price, new_qty)}
        end)
    end
  end

  defp update_quantity(cart_items, item_id, delta) do
    cart_items
    |> Enum.map(fn item ->
      if item.id == item_id do
        new_qty = max(1, item.quantity + delta)
        %{item | quantity: new_qty, subtotal: Decimal.mult(item.product.price, new_qty)}
      else
        item
      end
    end)
  end

  defp calculate_totals(cart_items) do
    subtotal = Enum.reduce(cart_items, Decimal.new("0.00"), fn item, acc ->
      Decimal.add(acc, item.subtotal)
    end)

    tax_rate = Decimal.new("0.0825")  # 8.25% tax
    tax = Decimal.mult(subtotal, tax_rate) |> Decimal.round(2)
    total = Decimal.add(subtotal, tax)

    {subtotal, tax, total}
  end
end
```

### Step 4: Add route in router.ex

In `lib/mcp_web/router.ex`, add:
```elixir
# Inside the store portal scope
live "/stores/:store_slug/pos", Store.PosLive, :index
```

### Step 5: Run test to verify it passes

Run: `mix test test/mcp_web/live/store/pos_live_test.exs -v`
Expected: PASS - all tests green

### Step 6: Commit

```bash
git add lib/mcp_web/live/store/pos_live.ex test/mcp_web/live/store/pos_live_test.exs lib/mcp_web/router.ex
git commit -m "feat(store): add POS LiveView with product grid, cart, payment"
```

---

## Remaining Tasks (Summary)

The following tasks follow the same TDD pattern. Each task includes:
1. Write failing test
2. Verify failure
3. Write minimal implementation
4. Verify pass
5. Commit

### Task 5: Store Terminal LiveView
- Design ref: Store Features §3
- Similar to POS but with customer required, shipping options, manual card entry

### Task 6: Merchant Customer List (2/3+1/3 Layout)
- Design ref: Merchant Features §3.1
- Uses PageLayout.list with ActionSidebar
- Includes AI insights section, segment filtering, search

### Task 7: Merchant Customer Detail (2/3+1/3 Layout)
- Design ref: Merchant Features §3.2
- Uses PageLayout.detail with ActionSidebar
- Includes AI summary, purchase history chart, recent orders

### Task 8: Store Customer Lookup (Simplified List)
- Design ref: Store Features §6.1
- Read-focused, quick lookup for service
- Shows visits, last visit, loyalty status

### Task 9: Store Customer Card (Quick View)
- Design ref: Store Features §6.2
- AI insight card, quick actions, recent transactions at THIS store

### Task 10: Merchant Transactions List (Full-Width Table)
- Design ref: Merchant Features §2.1
- Uses PageLayout.table with DataTable component
- Dense data with search and filters in toolbar

### Task 11: Merchant Transaction Detail
- Design ref: Merchant Features §2.2
- Uses PageLayout.detail with timeline, customer info sidebar

---

## Success Criteria

Phase 2 is complete when:

- [ ] All tests pass (`mix test --exclude slow`)
- [ ] `mix precommit` passes
- [ ] POS can complete a sale with card payment
- [ ] Terminal can complete a card-not-present transaction
- [ ] Customer list displays with proper 2/3+1/3 layout and AI insights placeholder
- [ ] Customer detail shows full profile with actions sidebar
- [ ] Transactions list displays in full-width table with filters
- [ ] Transaction detail shows timeline and customer context
- [ ] All pages use Phase 1 layout components correctly
- [ ] All pages match design doc wireframes

---

## Notes for Implementer

1. **Use Phase 1 Components:** Import from `McpWeb.Portal.*` - don't reinvent layouts
2. **Follow Wireframes:** The design docs have exact layouts - match them
3. **AI Insights Placeholder:** Add the section with placeholder text "AI insights coming in Phase 5"
4. **Sample Data:** Use hardcoded sample data for now - Ash integration comes later
5. **TDD Discipline:** Write test first, watch it fail, then implement
6. **Small Commits:** One feature per commit for easy review/rollback
