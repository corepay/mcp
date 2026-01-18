# Virtual Terminal Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the Virtual Terminal from a 4-step wizard to a single-screen, feature-rich payment interface with products, customers, fees, discounts, and multiple payment methods.

**Architecture:** Single-screen two-panel layout using existing `focused_layout` component. Left panel for line items, right panel for order summary. Modals for quick-create, drawers for browse/payment. All components follow DaisyUI patterns via CoreComponents.

**Tech Stack:** Phoenix LiveView, DaisyUI, Tailwind CSS v4, CoreComponents, Decimal for currency

**Design Reference:** `docs/plans/2026-01-11-virtual-terminal-redesign.md`

---

## Phase 1: Core Layout & State Management

### Task 1.1: Create Terminal State Module

**Files:**
- Create: `lib/mcp_web/live/store/terminal/state.ex`
- Test: `test/mcp_web/live/store/terminal/state_test.exs`

**Step 1: Write the failing test for initial state**

```elixir
# test/mcp_web/live/store/terminal/state_test.exs
defmodule McpWeb.Store.Terminal.StateTest do
  use ExUnit.Case, async: true

  alias McpWeb.Store.Terminal.State

  describe "new/1" do
    test "creates initial state with store_slug" do
      state = State.new("downtown")

      assert state.store_slug == "downtown"
      assert state.customer == nil
      assert state.line_items == []
      assert Decimal.eq?(state.subtotal, Decimal.new("0.00"))
      assert Decimal.eq?(state.tax, Decimal.new("0.00"))
      assert Decimal.eq?(state.total, Decimal.new("0.00"))
      assert state.show_payment_drawer == false
      assert state.show_send_link_modal == false
      assert state.show_email_modal == false
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/live/store/terminal/state_test.exs --seed 0`
Expected: FAIL with "module State is not available"

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/live/store/terminal/state.ex
defmodule McpWeb.Store.Terminal.State do
  @moduledoc """
  State management for the Virtual Terminal.
  Handles line items, customer, totals calculation, and UI state.
  """

  defstruct [
    :store_slug,
    :customer,
    :line_items,
    :subtotal,
    :tax,
    :total,
    :tax_rate,
    :note,
    :show_payment_drawer,
    :show_send_link_modal,
    :show_email_modal,
    :show_history_drawer,
    :show_browse_drawer,
    :browse_drawer_type,
    :payment_status,
    :transaction_result
  ]

  @default_tax_rate Decimal.new("0.0825")

  def new(store_slug) do
    %__MODULE__{
      store_slug: store_slug,
      customer: nil,
      line_items: [],
      subtotal: Decimal.new("0.00"),
      tax: Decimal.new("0.00"),
      total: Decimal.new("0.00"),
      tax_rate: @default_tax_rate,
      note: nil,
      show_payment_drawer: false,
      show_send_link_modal: false,
      show_email_modal: false,
      show_history_drawer: false,
      show_browse_drawer: false,
      browse_drawer_type: nil,
      payment_status: nil,
      transaction_result: nil
    }
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/live/store/terminal/state_test.exs --seed 0`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp_web/live/store/terminal/state.ex test/mcp_web/live/store/terminal/state_test.exs
git commit -m "feat(terminal): add state module with initial state"
```

---

### Task 1.2: Add Line Item Types and Operations

**Files:**
- Modify: `lib/mcp_web/live/store/terminal/state.ex`
- Modify: `test/mcp_web/live/store/terminal/state_test.exs`

**Step 1: Write failing tests for line item operations**

```elixir
# Add to test/mcp_web/live/store/terminal/state_test.exs

describe "line items" do
  test "add_product/3 adds a product to line items" do
    state = State.new("downtown")
    product = %{id: "prod_1", name: "Premium Tee", price: Decimal.new("29.99"), type: :product}

    state = State.add_product(state, product, 1)

    assert length(state.line_items) == 1
    [item] = state.line_items
    assert item.type == :product
    assert item.name == "Premium Tee"
    assert Decimal.eq?(item.unit_price, Decimal.new("29.99"))
    assert item.quantity == 1
    assert Decimal.eq?(item.line_total, Decimal.new("29.99"))
  end

  test "add_product/3 increments quantity if product already exists" do
    state = State.new("downtown")
    product = %{id: "prod_1", name: "Premium Tee", price: Decimal.new("29.99"), type: :product}

    state = state |> State.add_product(product, 1) |> State.add_product(product, 2)

    assert length(state.line_items) == 1
    [item] = state.line_items
    assert item.quantity == 3
    assert Decimal.eq?(item.line_total, Decimal.new("89.97"))
  end

  test "add_fee/2 adds a fixed fee" do
    state = State.new("downtown")
    fee = %{id: "fee_1", name: "Rush Delivery", amount: Decimal.new("25.00"), type: :fee, percent: false}

    state = State.add_fee(state, fee)

    assert length(state.line_items) == 1
    [item] = state.line_items
    assert item.type == :fee
    assert Decimal.eq?(item.line_total, Decimal.new("25.00"))
  end

  test "add_discount/2 adds a percentage discount" do
    state = State.new("downtown")
    |> State.add_product(%{id: "prod_1", name: "Tee", price: Decimal.new("100.00"), type: :product}, 1)

    discount = %{id: "disc_1", name: "Summer Sale", amount: Decimal.new("10"), type: :discount, percent: true}

    state = State.add_discount(state, discount)

    # Discount shows as negative
    discount_item = Enum.find(state.line_items, &(&1.type == :discount))
    assert Decimal.eq?(discount_item.line_total, Decimal.new("-10.00"))
  end

  test "add_tip/2 adds a tip amount" do
    state = State.new("downtown")
    state = State.add_tip(state, Decimal.new("10.00"))

    tip_item = Enum.find(state.line_items, &(&1.type == :tip))
    assert tip_item != nil
    assert Decimal.eq?(tip_item.line_total, Decimal.new("10.00"))
  end

  test "remove_item/2 removes item by id" do
    state = State.new("downtown")
    |> State.add_product(%{id: "prod_1", name: "Tee", price: Decimal.new("29.99"), type: :product}, 1)
    |> State.add_product(%{id: "prod_2", name: "Mug", price: Decimal.new("12.00"), type: :product}, 1)

    state = State.remove_item(state, "prod_1")

    assert length(state.line_items) == 1
    assert hd(state.line_items).id == "prod_2"
  end

  test "update_quantity/3 updates product quantity" do
    state = State.new("downtown")
    |> State.add_product(%{id: "prod_1", name: "Tee", price: Decimal.new("29.99"), type: :product}, 2)

    state = State.update_quantity(state, "prod_1", 5)

    [item] = state.line_items
    assert item.quantity == 5
    assert Decimal.eq?(item.line_total, Decimal.new("149.95"))
  end

  test "update_quantity/3 removes item when quantity is 0" do
    state = State.new("downtown")
    |> State.add_product(%{id: "prod_1", name: "Tee", price: Decimal.new("29.99"), type: :product}, 2)

    state = State.update_quantity(state, "prod_1", 0)

    assert state.line_items == []
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/live/store/terminal/state_test.exs --seed 0`
Expected: FAIL with "function add_product/3 is undefined"

**Step 3: Implement line item operations**

```elixir
# Add to lib/mcp_web/live/store/terminal/state.ex

@doc "Add a product to line items"
def add_product(%__MODULE__{} = state, product, quantity) do
  existing_index = Enum.find_index(state.line_items, &(&1.id == product.id && &1.type == :product))

  line_items =
    if existing_index do
      List.update_at(state.line_items, existing_index, fn item ->
        new_qty = item.quantity + quantity
        %{item | quantity: new_qty, line_total: Decimal.mult(item.unit_price, new_qty)}
      end)
    else
      item = %{
        id: product.id,
        type: :product,
        name: product.name,
        unit_price: product.price,
        quantity: quantity,
        line_total: Decimal.mult(product.price, quantity),
        source_id: product.id
      }
      state.line_items ++ [item]
    end

  %{state | line_items: line_items}
  |> recalculate_totals()
end

@doc "Add a fee to line items"
def add_fee(%__MODULE__{} = state, fee) do
  item = %{
    id: fee.id || generate_id(),
    type: :fee,
    name: fee.name,
    unit_price: fee.amount,
    quantity: 1,
    line_total: fee.amount,
    percent: fee[:percent] || false,
    source_id: fee[:id]
  }

  %{state | line_items: state.line_items ++ [item]}
  |> recalculate_totals()
end

@doc "Add a discount to line items"
def add_discount(%__MODULE__{} = state, discount) do
  line_total =
    if discount.percent do
      # Calculate percentage of current subtotal (products + fees only)
      taxable = calculate_taxable_subtotal(state.line_items)
      Decimal.mult(taxable, Decimal.div(discount.amount, 100))
      |> Decimal.negate()
    else
      Decimal.negate(discount.amount)
    end

  item = %{
    id: discount.id || generate_id(),
    type: :discount,
    name: discount.name,
    unit_price: discount.amount,
    quantity: 1,
    line_total: line_total,
    percent: discount.percent,
    source_id: discount[:id]
  }

  %{state | line_items: state.line_items ++ [item]}
  |> recalculate_totals()
end

@doc "Add a tip to line items (replaces existing tip)"
def add_tip(%__MODULE__{} = state, amount) do
  # Remove existing tip
  line_items = Enum.reject(state.line_items, &(&1.type == :tip))

  item = %{
    id: generate_id(),
    type: :tip,
    name: "Tip",
    unit_price: amount,
    quantity: 1,
    line_total: amount,
    percent: false,
    source_id: nil
  }

  %{state | line_items: line_items ++ [item]}
  |> recalculate_totals()
end

@doc "Remove an item by ID"
def remove_item(%__MODULE__{} = state, item_id) do
  line_items = Enum.reject(state.line_items, &(&1.id == item_id))

  %{state | line_items: line_items}
  |> recalculate_totals()
end

@doc "Update quantity for a product"
def update_quantity(%__MODULE__{} = state, item_id, quantity) when quantity <= 0 do
  remove_item(state, item_id)
end

def update_quantity(%__MODULE__{} = state, item_id, quantity) do
  line_items =
    Enum.map(state.line_items, fn item ->
      if item.id == item_id and item.type == :product do
        %{item | quantity: quantity, line_total: Decimal.mult(item.unit_price, quantity)}
      else
        item
      end
    end)

  %{state | line_items: line_items}
  |> recalculate_totals()
end

# Private helpers

defp recalculate_totals(%__MODULE__{} = state) do
  # Recalculate percentage discounts first
  taxable = calculate_taxable_subtotal(state.line_items)

  line_items =
    Enum.map(state.line_items, fn item ->
      if item.type == :discount and item.percent do
        new_total = Decimal.mult(taxable, Decimal.div(item.unit_price, 100)) |> Decimal.negate()
        %{item | line_total: new_total}
      else
        item
      end
    end)

  # Calculate subtotal (all items)
  subtotal = Enum.reduce(line_items, Decimal.new("0.00"), fn item, acc ->
    Decimal.add(acc, item.line_total)
  end)

  # Tax applies to products + fees only (not tips or discounts)
  taxable_for_tax = calculate_taxable_subtotal(line_items)
  discount_total = line_items |> Enum.filter(&(&1.type == :discount)) |> Enum.reduce(Decimal.new("0.00"), &Decimal.add(&1.line_total, &2))
  taxable_after_discount = Decimal.add(taxable_for_tax, discount_total) |> Decimal.max(Decimal.new("0.00"))

  tax = Decimal.mult(taxable_after_discount, state.tax_rate) |> Decimal.round(2)

  # Total = subtotal + tax
  total = Decimal.add(subtotal, tax)

  %{state | line_items: line_items, subtotal: subtotal, tax: tax, total: total}
end

defp calculate_taxable_subtotal(line_items) do
  line_items
  |> Enum.filter(&(&1.type in [:product, :fee]))
  |> Enum.reduce(Decimal.new("0.00"), &Decimal.add(&1.line_total, &2))
end

defp generate_id do
  "item_#{:erlang.unique_integer([:positive])}"
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/live/store/terminal/state_test.exs --seed 0`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp_web/live/store/terminal/state.ex test/mcp_web/live/store/terminal/state_test.exs
git commit -m "feat(terminal): add line item operations (product, fee, discount, tip)"
```

---

### Task 1.3: Add Totals Calculation Tests

**Files:**
- Modify: `test/mcp_web/live/store/terminal/state_test.exs`

**Step 1: Write failing tests for totals calculation**

```elixir
# Add to test/mcp_web/live/store/terminal/state_test.exs

describe "totals calculation" do
  test "calculates subtotal from products" do
    state = State.new("downtown")
    |> State.add_product(%{id: "p1", name: "Tee", price: Decimal.new("29.99"), type: :product}, 2)
    |> State.add_product(%{id: "p2", name: "Mug", price: Decimal.new("12.00"), type: :product}, 1)

    # 29.99 * 2 + 12.00 = 71.98
    assert Decimal.eq?(state.subtotal, Decimal.new("71.98"))
  end

  test "calculates tax on products and fees only" do
    state = State.new("downtown")
    |> State.add_product(%{id: "p1", name: "Tee", price: Decimal.new("100.00"), type: :product}, 1)
    |> State.add_fee(%{id: "f1", name: "Rush", amount: Decimal.new("25.00"), type: :fee})
    |> State.add_tip(Decimal.new("10.00"))

    # Tax on 100 + 25 = 125 * 0.0825 = 10.31 (rounded)
    assert Decimal.eq?(state.tax, Decimal.new("10.31"))
  end

  test "does not tax tips" do
    state = State.new("downtown")
    |> State.add_product(%{id: "p1", name: "Tee", price: Decimal.new("100.00"), type: :product}, 1)
    |> State.add_tip(Decimal.new("20.00"))

    # Tax on 100 only = 8.25
    assert Decimal.eq?(state.tax, Decimal.new("8.25"))
  end

  test "reduces tax base by discount amount" do
    state = State.new("downtown")
    |> State.add_product(%{id: "p1", name: "Tee", price: Decimal.new("100.00"), type: :product}, 1)
    |> State.add_discount(%{id: "d1", name: "10% Off", amount: Decimal.new("10"), type: :discount, percent: true})

    # Tax on (100 - 10) = 90 * 0.0825 = 7.43 (rounded)
    assert Decimal.eq?(state.tax, Decimal.new("7.43"))
  end

  test "calculates correct total" do
    state = State.new("downtown")
    |> State.add_product(%{id: "p1", name: "Tee", price: Decimal.new("100.00"), type: :product}, 1)
    |> State.add_fee(%{id: "f1", name: "Rush", amount: Decimal.new("25.00"), type: :fee})
    |> State.add_discount(%{id: "d1", name: "10% Off", amount: Decimal.new("10"), type: :discount, percent: true})
    |> State.add_tip(Decimal.new("15.00"))

    # Products + Fees = 125
    # Discount = -12.50 (10% of 125)
    # Subtotal = 127.50 (125 - 12.50 + 15)
    # Tax = (125 - 12.50) * 0.0825 = 9.28
    # Total = 127.50 + 9.28 = 136.78
    assert Decimal.eq?(state.subtotal, Decimal.new("127.50"))
    assert Decimal.eq?(state.tax, Decimal.new("9.28"))
    assert Decimal.eq?(state.total, Decimal.new("136.78"))
  end
end
```

**Step 2: Run test to verify current implementation handles these**

Run: `mix test test/mcp_web/live/store/terminal/state_test.exs --seed 0`
Expected: Should PASS if implementation is correct, or fail and reveal needed fixes

**Step 3: Fix any issues if tests fail, then commit**

```bash
git add test/mcp_web/live/store/terminal/state_test.exs
git commit -m "test(terminal): add comprehensive totals calculation tests"
```

---

### Task 1.4: Add Customer Management to State

**Files:**
- Modify: `lib/mcp_web/live/store/terminal/state.ex`
- Modify: `test/mcp_web/live/store/terminal/state_test.exs`

**Step 1: Write failing tests for customer operations**

```elixir
# Add to test/mcp_web/live/store/terminal/state_test.exs

describe "customer management" do
  test "set_customer/2 attaches a customer" do
    state = State.new("downtown")
    customer = %{id: "cust_1", name: "Sarah Chen", email: "sarah@example.com", phone: "555-1234"}

    state = State.set_customer(state, customer)

    assert state.customer.id == "cust_1"
    assert state.customer.name == "Sarah Chen"
  end

  test "clear_customer/1 removes the customer" do
    state = State.new("downtown")
    |> State.set_customer(%{id: "cust_1", name: "Sarah Chen"})
    |> State.clear_customer()

    assert state.customer == nil
  end

  test "has_customer?/1 returns true when customer is set" do
    state = State.new("downtown") |> State.set_customer(%{id: "cust_1", name: "Sarah"})
    assert State.has_customer?(state) == true
  end

  test "has_customer?/1 returns false when no customer" do
    state = State.new("downtown")
    assert State.has_customer?(state) == false
  end

  test "has_customer_email?/1 returns true when customer has email" do
    state = State.new("downtown") |> State.set_customer(%{id: "c1", name: "Sarah", email: "s@test.com"})
    assert State.has_customer_email?(state) == true
  end

  test "has_customer_email?/1 returns false when customer has no email" do
    state = State.new("downtown") |> State.set_customer(%{id: "c1", name: "Sarah", email: nil})
    assert State.has_customer_email?(state) == false
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/live/store/terminal/state_test.exs --seed 0`
Expected: FAIL with "function set_customer/2 is undefined"

**Step 3: Implement customer operations**

```elixir
# Add to lib/mcp_web/live/store/terminal/state.ex

@doc "Set the customer for this transaction"
def set_customer(%__MODULE__{} = state, customer) do
  %{state | customer: customer}
end

@doc "Clear the customer"
def clear_customer(%__MODULE__{} = state) do
  %{state | customer: nil}
end

@doc "Check if a customer is attached"
def has_customer?(%__MODULE__{customer: nil}), do: false
def has_customer?(%__MODULE__{}), do: true

@doc "Check if the attached customer has an email"
def has_customer_email?(%__MODULE__{customer: nil}), do: false
def has_customer_email?(%__MODULE__{customer: %{email: nil}}), do: false
def has_customer_email?(%__MODULE__{customer: %{email: ""}}), do: false
def has_customer_email?(%__MODULE__{}}), do: true
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/live/store/terminal/state_test.exs --seed 0`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp_web/live/store/terminal/state.ex test/mcp_web/live/store/terminal/state_test.exs
git commit -m "feat(terminal): add customer management to state"
```

---

### Task 1.5: Add UI State Toggles

**Files:**
- Modify: `lib/mcp_web/live/store/terminal/state.ex`
- Modify: `test/mcp_web/live/store/terminal/state_test.exs`

**Step 1: Write failing tests for UI toggles**

```elixir
# Add to test/mcp_web/live/store/terminal/state_test.exs

describe "UI state" do
  test "toggle_payment_drawer/1 toggles the drawer" do
    state = State.new("downtown")
    assert state.show_payment_drawer == false

    state = State.toggle_payment_drawer(state)
    assert state.show_payment_drawer == true

    state = State.toggle_payment_drawer(state)
    assert state.show_payment_drawer == false
  end

  test "open_browse_drawer/2 opens drawer with type" do
    state = State.new("downtown")
    state = State.open_browse_drawer(state, :products)

    assert state.show_browse_drawer == true
    assert state.browse_drawer_type == :products
  end

  test "close_browse_drawer/1 closes drawer and clears type" do
    state = State.new("downtown")
    |> State.open_browse_drawer(:fees)
    |> State.close_browse_drawer()

    assert state.show_browse_drawer == false
    assert state.browse_drawer_type == nil
  end

  test "reset/1 clears all state except store_slug" do
    state = State.new("downtown")
    |> State.add_product(%{id: "p1", name: "Tee", price: Decimal.new("29.99"), type: :product}, 1)
    |> State.set_customer(%{id: "c1", name: "Sarah"})
    |> State.toggle_payment_drawer()
    |> State.reset()

    assert state.store_slug == "downtown"
    assert state.customer == nil
    assert state.line_items == []
    assert state.show_payment_drawer == false
  end

  test "can_charge?/1 returns true when total > 0" do
    state = State.new("downtown")
    |> State.add_product(%{id: "p1", name: "Tee", price: Decimal.new("29.99"), type: :product}, 1)

    assert State.can_charge?(state) == true
  end

  test "can_charge?/1 returns false when total is 0" do
    state = State.new("downtown")
    assert State.can_charge?(state) == false
  end

  test "can_email?/1 returns true when total > 0 and customer has email" do
    state = State.new("downtown")
    |> State.add_product(%{id: "p1", name: "Tee", price: Decimal.new("29.99"), type: :product}, 1)
    |> State.set_customer(%{id: "c1", name: "Sarah", email: "s@test.com"})

    assert State.can_email?(state) == true
  end

  test "can_email?/1 returns false when no customer email" do
    state = State.new("downtown")
    |> State.add_product(%{id: "p1", name: "Tee", price: Decimal.new("29.99"), type: :product}, 1)

    assert State.can_email?(state) == false
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/live/store/terminal/state_test.exs --seed 0`
Expected: FAIL

**Step 3: Implement UI state functions**

```elixir
# Add to lib/mcp_web/live/store/terminal/state.ex

@doc "Toggle the payment drawer"
def toggle_payment_drawer(%__MODULE__{} = state) do
  %{state | show_payment_drawer: !state.show_payment_drawer}
end

@doc "Open the payment drawer"
def open_payment_drawer(%__MODULE__{} = state) do
  %{state | show_payment_drawer: true, payment_status: nil, transaction_result: nil}
end

@doc "Close the payment drawer"
def close_payment_drawer(%__MODULE__{} = state) do
  %{state | show_payment_drawer: false}
end

@doc "Open browse drawer with specific type"
def open_browse_drawer(%__MODULE__{} = state, type) when type in [:products, :fees, :discounts] do
  %{state | show_browse_drawer: true, browse_drawer_type: type}
end

@doc "Close browse drawer"
def close_browse_drawer(%__MODULE__{} = state) do
  %{state | show_browse_drawer: false, browse_drawer_type: nil}
end

@doc "Toggle history drawer"
def toggle_history_drawer(%__MODULE__{} = state) do
  %{state | show_history_drawer: !state.show_history_drawer}
end

@doc "Open send link modal"
def open_send_link_modal(%__MODULE__{} = state) do
  %{state | show_send_link_modal: true}
end

@doc "Close send link modal"
def close_send_link_modal(%__MODULE__{} = state) do
  %{state | show_send_link_modal: false}
end

@doc "Open email modal"
def open_email_modal(%__MODULE__{} = state) do
  %{state | show_email_modal: true}
end

@doc "Close email modal"
def close_email_modal(%__MODULE__{} = state) do
  %{state | show_email_modal: false}
end

@doc "Reset state for new transaction"
def reset(%__MODULE__{} = state) do
  new(state.store_slug)
end

@doc "Check if charge is possible"
def can_charge?(%__MODULE__{total: total}) do
  Decimal.gt?(total, Decimal.new("0.00"))
end

@doc "Check if send link is possible"
def can_send_link?(%__MODULE__{} = state) do
  can_charge?(state)
end

@doc "Check if email is possible"
def can_email?(%__MODULE__{} = state) do
  can_charge?(state) and has_customer_email?(state)
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/live/store/terminal/state_test.exs --seed 0`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp_web/live/store/terminal/state.ex test/mcp_web/live/store/terminal/state_test.exs
git commit -m "feat(terminal): add UI state toggles and validation helpers"
```

---

## Phase 2: Core Components

### Task 2.1: Create Drawer Component

**Files:**
- Create: `lib/mcp_web/components/core/drawer.ex`
- Test: `test/mcp_web/components/core/drawer_test.exs`

**Step 1: Write failing test**

```elixir
# test/mcp_web/components/core/drawer_test.exs
defmodule McpWeb.Core.DrawerTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Core.Drawer

  describe "drawer/1" do
    test "renders nothing when show is false" do
      html = render_component(&Drawer.drawer/1, %{
        id: "test-drawer",
        show: false,
        side: :right,
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "Content" end}]
      })

      refute html =~ "Content"
    end

    test "renders drawer when show is true" do
      html = render_component(&Drawer.drawer/1, %{
        id: "test-drawer",
        show: true,
        side: :right,
        title: [],
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "Drawer Content" end}]
      })

      assert html =~ "Drawer Content"
      assert html =~ "test-drawer"
    end

    test "renders right drawer with correct classes" do
      html = render_component(&Drawer.drawer/1, %{
        id: "right-drawer",
        show: true,
        side: :right,
        title: [],
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "Content" end}]
      })

      assert html =~ "right-0"
    end

    test "renders bottom drawer with correct classes" do
      html = render_component(&Drawer.drawer/1, %{
        id: "bottom-drawer",
        show: true,
        side: :bottom,
        title: [],
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "Content" end}]
      })

      assert html =~ "bottom-0"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/components/core/drawer_test.exs --seed 0`
Expected: FAIL with "module Drawer is not available"

**Step 3: Implement drawer component**

```elixir
# lib/mcp_web/components/core/drawer.ex
defmodule McpWeb.Core.Drawer do
  @moduledoc """
  Drawer component for slide-in panels.

  Supports right and bottom positions with smooth animations.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  @doc """
  Renders a drawer that slides in from the right or bottom.

  ## Attributes
    * `id` - Unique ID for the drawer (required)
    * `show` - Whether the drawer is visible (required)
    * `side` - Which side to slide from: :right or :bottom (default :right)
    * `on_close` - Event to fire when close button clicked

  ## Slots
    * `title` - Optional title slot
    * `inner_block` - Main content
  """
  attr :id, :string, required: true
  attr :show, :boolean, required: true
  attr :side, :atom, default: :right, values: [:right, :bottom]
  attr :on_close, :string, default: nil
  attr :class, :string, default: nil

  slot :title
  slot :inner_block, required: true

  def drawer(assigns) do
    ~H"""
    <div
      :if={@show}
      id={@id}
      class="fixed inset-0 z-50"
      phx-mounted={show_drawer(@side)}
    >
      <!-- Backdrop -->
      <div
        class="absolute inset-0 bg-base-300/50 backdrop-blur-sm transition-opacity"
        phx-click={@on_close}
        data-testid="drawer-backdrop"
      />

      <!-- Drawer Panel -->
      <div class={[
        "absolute bg-base-100 shadow-xl transition-transform duration-300",
        drawer_position_class(@side),
        drawer_size_class(@side),
        @class
      ]}>
        <!-- Header -->
        <div class="flex items-center justify-between border-b border-base-300 px-4 py-3">
          <div class="flex-1">
            <%= if @title != [] do %>
              <h3 class="text-lg font-semibold">{render_slot(@title)}</h3>
            <% end %>
          </div>
          <button
            :if={@on_close}
            type="button"
            class="btn btn-ghost btn-sm btn-circle"
            phx-click={@on_close}
            aria-label="Close"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>

        <!-- Content -->
        <div class={[
          "overflow-y-auto",
          content_height_class(@side)
        ]}>
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  defp drawer_position_class(:right), do: "top-0 right-0 h-full"
  defp drawer_position_class(:bottom), do: "bottom-0 left-0 right-0"

  defp drawer_size_class(:right), do: "w-full max-w-md"
  defp drawer_size_class(:bottom), do: "h-auto max-h-[85vh] rounded-t-2xl"

  defp content_height_class(:right), do: "h-[calc(100%-57px)]"
  defp content_height_class(:bottom), do: "max-h-[calc(85vh-57px)]"

  defp show_drawer(:right) do
    Phoenix.LiveView.JS.transition(
      {"transform translate-x-full", "transform translate-x-0"},
      time: 300
    )
  end

  defp show_drawer(:bottom) do
    Phoenix.LiveView.JS.transition(
      {"transform translate-y-full", "transform translate-y-0"},
      time: 300
    )
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/components/core/drawer_test.exs --seed 0`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp_web/components/core/drawer.ex test/mcp_web/components/core/drawer_test.exs
git commit -m "feat(core): add drawer component with right and bottom variants"
```

---

### Task 2.2: Create Terminal Components Module Structure

**Files:**
- Create: `lib/mcp_web/components/terminal/customer_section.ex`
- Create: `lib/mcp_web/components/terminal/line_items.ex`
- Create: `lib/mcp_web/components/terminal/order_summary.ex`

**Step 1: Create customer section component**

```elixir
# lib/mcp_web/components/terminal/customer_section.ex
defmodule McpWeb.Components.Terminal.CustomerSection do
  @moduledoc """
  Customer section component for the Virtual Terminal.
  Shows search input when no customer, shows customer info when selected.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1, button: 1, input: 1]

  attr :customer, :map, default: nil
  attr :search_query, :string, default: ""

  def customer_section(assigns) do
    ~H"""
    <div class="border-b border-base-300 p-4" data-testid="customer-section">
      <%= if @customer do %>
        <.customer_display customer={@customer} />
      <% else %>
        <.customer_search search_query={@search_query} />
      <% end %>
    </div>
    """
  end

  defp customer_display(assigns) do
    ~H"""
    <div class="rounded-xl bg-base-200/50 p-4" data-testid="customer-display">
      <div class="flex items-start justify-between">
        <div class="flex items-center gap-3">
          <div class="avatar placeholder">
            <div class="w-10 rounded-full bg-primary text-primary-content">
              <span class="text-sm">{initials(@customer.name)}</span>
            </div>
          </div>
          <div>
            <div class="font-semibold">{@customer.name}</div>
            <div class="text-sm text-base-content/70">
              <%= if @customer[:email] do %>
                {@customer.email}
              <% end %>
              <%= if @customer[:email] && @customer[:phone] do %>
                <span class="mx-1">·</span>
              <% end %>
              <%= if @customer[:phone] do %>
                {@customer.phone}
              <% end %>
            </div>
          </div>
        </div>
        <button
          type="button"
          class="btn btn-ghost btn-sm btn-circle"
          phx-click="clear_customer"
          aria-label="Remove customer"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>

      <!-- AI Insight placeholder -->
      <div
        :if={@customer[:insight]}
        class="mt-3 rounded-lg bg-info/10 border border-info/20 p-3 text-sm"
        data-testid="customer-insight"
      >
        <div class="flex items-start gap-2">
          <.icon name="hero-light-bulb" class="size-4 text-info mt-0.5" />
          <span class="text-base-content/80">{@customer.insight}</span>
        </div>
      </div>
    </div>
    """
  end

  defp customer_search(assigns) do
    ~H"""
    <div class="flex gap-2" data-testid="customer-search">
      <div class="relative flex-1">
        <.icon name="hero-magnifying-glass" class="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-base-content/50" />
        <input
          type="text"
          placeholder="Search customers by name, email, phone..."
          class="input input-bordered w-full pl-10"
          value={@search_query}
          phx-change="search_customers"
          phx-debounce="300"
          name="query"
          data-testid="customer-search-input"
        />
      </div>
      <.button variant="outline" phx-click="open_customer_modal">
        <.icon name="hero-plus" class="size-4 mr-1" />
        New
      </.button>
    </div>
    """
  end

  defp initials(name) when is_binary(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  defp initials(_), do: "?"
end
```

**Step 2: Create line items component**

```elixir
# lib/mcp_web/components/terminal/line_items.ex
defmodule McpWeb.Components.Terminal.LineItems do
  @moduledoc """
  Line items component for the Virtual Terminal.
  Displays unified list of products, fees, discounts, and tips.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  attr :items, :list, required: true
  attr :search_query, :string, default: ""

  def line_items(assigns) do
    ~H"""
    <div class="flex h-full flex-col" data-testid="line-items">
      <!-- Search -->
      <div class="p-4 border-b border-base-300">
        <div class="flex gap-2">
          <div class="relative flex-1">
            <.icon name="hero-magnifying-glass" class="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-base-content/50" />
            <input
              type="text"
              placeholder="Search products, fees, discounts..."
              class="input input-bordered w-full pl-10"
              value={@search_query}
              phx-change="search_items"
              phx-debounce="300"
              name="query"
              data-testid="item-search-input"
            />
          </div>
          <button
            type="button"
            class="btn btn-outline"
            phx-click="open_quick_create"
          >
            <.icon name="hero-plus" class="size-4 mr-1" />
            Custom
          </button>
        </div>
      </div>

      <!-- Items List -->
      <div class="flex-1 overflow-y-auto p-4">
        <%= if Enum.empty?(@items) do %>
          <.empty_state />
        <% else %>
          <div class="space-y-2">
            <%= for item <- @items do %>
              <.line_item item={item} />
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Add Note -->
      <div class="p-4 border-t border-base-300">
        <button type="button" class="btn btn-ghost btn-sm w-full justify-start">
          <.icon name="hero-chat-bubble-left" class="size-4 mr-2" />
          Add note to order
        </button>
      </div>
    </div>
    """
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-16 text-center" data-testid="empty-items">
      <.icon name="hero-shopping-bag" class="size-16 text-base-content/20 mb-4" />
      <p class="text-base-content/70 mb-1">No items yet</p>
      <p class="text-sm text-base-content/50">Search or add products, fees, and discounts to build an order.</p>
    </div>
    """
  end

  defp line_item(assigns) do
    ~H"""
    <div class={[
      "rounded-lg border p-3",
      item_border_class(@item.type)
    ]} data-testid={"line-item-#{@item.id}"}>
      <div class="flex items-start justify-between">
        <div class="flex items-start gap-3">
          <span class="text-lg">{item_icon(@item.type)}</span>
          <div>
            <div class="font-medium">{@item.name}</div>
            <div class="text-sm text-base-content/70">
              <%= if @item.type == :product do %>
                {format_currency(@item.unit_price)} × {@item.quantity}
              <% else %>
                <%= if @item.percent do %>
                  {@item.unit_price}% off
                <% else %>
                  {item_type_label(@item.type)}
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <span class={[
            "font-semibold tabular-nums",
            @item.type == :discount && "text-success"
          ]}>
            {format_currency(@item.line_total)}
          </span>
          <button
            type="button"
            class="btn btn-ghost btn-sm btn-circle"
            phx-click="remove_item"
            phx-value-id={@item.id}
            aria-label="Remove"
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>
      </div>

      <!-- Quantity controls for products -->
      <%= if @item.type == :product do %>
        <div class="mt-2 flex items-center gap-2">
          <button
            type="button"
            class="btn btn-ghost btn-xs btn-circle"
            phx-click="decrease_quantity"
            phx-value-id={@item.id}
          >
            <.icon name="hero-minus" class="size-3" />
          </button>
          <span class="w-8 text-center text-sm font-medium">{@item.quantity}</span>
          <button
            type="button"
            class="btn btn-ghost btn-xs btn-circle"
            phx-click="increase_quantity"
            phx-value-id={@item.id}
          >
            <.icon name="hero-plus" class="size-3" />
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  defp item_icon(:product), do: "📦"
  defp item_icon(:fee), do: "🚚"
  defp item_icon(:discount), do: "🏷️"
  defp item_icon(:tip), do: "💰"

  defp item_border_class(:discount), do: "border-success/30"
  defp item_border_class(_), do: "border-base-300"

  defp item_type_label(:fee), do: "Fee"
  defp item_type_label(:discount), do: "Discount"
  defp item_type_label(:tip), do: "Tip"
  defp item_type_label(_), do: ""

  defp format_currency(%Decimal{} = amount) do
    sign = if Decimal.negative?(amount), do: "-", else: ""
    abs_amount = Decimal.abs(amount)
    "#{sign}$#{Decimal.round(abs_amount, 2)}"
  end

  defp format_currency(_), do: "$0.00"
end
```

**Step 3: Create order summary component**

```elixir
# lib/mcp_web/components/terminal/order_summary.ex
defmodule McpWeb.Components.Terminal.OrderSummary do
  @moduledoc """
  Order summary component for the Virtual Terminal.
  Shows totals breakdown and action buttons.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1, button: 1]

  attr :subtotal, :any, required: true
  attr :tax, :any, required: true
  attr :total, :any, required: true
  attr :tax_rate, :any, default: Decimal.new("0.0825")
  attr :can_charge, :boolean, default: false
  attr :can_send_link, :boolean, default: false
  attr :can_email, :boolean, default: false
  attr :items, :list, default: []

  def order_summary(assigns) do
    # Calculate breakdown from items
    assigns = assign(assigns, :breakdown, calculate_breakdown(assigns.items))

    ~H"""
    <div class="flex h-full flex-col bg-base-200" data-testid="order-summary">
      <!-- Totals -->
      <div class="flex-1 overflow-y-auto p-4">
        <div class="space-y-2 text-sm">
          <!-- Products subtotal -->
          <div class="flex justify-between">
            <span class="text-base-content/70">Subtotal</span>
            <span class="tabular-nums">{format_currency(@breakdown.products_total)}</span>
          </div>

          <!-- Discount (if any) -->
          <%= if Decimal.gt?(@breakdown.discount_total |> Decimal.abs(), Decimal.new("0")) do %>
            <div class="flex justify-between text-success">
              <span>Discounts</span>
              <span class="tabular-nums">{format_currency(@breakdown.discount_total)}</span>
            </div>
          <% end %>

          <!-- Fees (if any) -->
          <%= if Decimal.gt?(@breakdown.fees_total, Decimal.new("0")) do %>
            <div class="flex justify-between">
              <span class="text-base-content/70">Fees</span>
              <span class="tabular-nums">{format_currency(@breakdown.fees_total)}</span>
            </div>
          <% end %>

          <!-- Tax -->
          <div class="flex justify-between">
            <span class="text-base-content/70">Tax ({format_percent(@tax_rate)})</span>
            <span class="tabular-nums">{format_currency(@tax)}</span>
          </div>

          <!-- Tip (if any) -->
          <%= if Decimal.gt?(@breakdown.tips_total, Decimal.new("0")) do %>
            <div class="flex justify-between">
              <span class="text-base-content/70">Tip</span>
              <span class="tabular-nums">{format_currency(@breakdown.tips_total)}</span>
            </div>
          <% end %>

          <!-- Total -->
          <div class="flex justify-between border-t border-base-300 pt-2 text-xl font-bold">
            <span>TOTAL</span>
            <span class="tabular-nums text-primary">{format_currency(@total)}</span>
          </div>
        </div>
      </div>

      <!-- Actions -->
      <div class="border-t border-base-300 p-4 space-y-2">
        <.button
          variant="primary"
          class="w-full btn-lg"
          phx-click="open_payment_drawer"
          disabled={!@can_charge}
        >
          <.icon name="hero-credit-card" class="size-5 mr-2" />
          Charge Card {format_currency(@total)}
        </.button>

        <div class="grid grid-cols-2 gap-2">
          <.button
            variant="outline"
            phx-click="open_send_link_modal"
            disabled={!@can_send_link}
          >
            <.icon name="hero-link" class="size-4 mr-1" />
            Send Link
          </.button>
          <.button
            variant="outline"
            phx-click="open_email_modal"
            disabled={!@can_email}
          >
            <.icon name="hero-envelope" class="size-4 mr-1" />
            Email
          </.button>
        </div>
      </div>
    </div>
    """
  end

  defp calculate_breakdown(items) do
    %{
      products_total: items |> Enum.filter(&(&1.type == :product)) |> sum_totals(),
      fees_total: items |> Enum.filter(&(&1.type == :fee)) |> sum_totals(),
      discount_total: items |> Enum.filter(&(&1.type == :discount)) |> sum_totals(),
      tips_total: items |> Enum.filter(&(&1.type == :tip)) |> sum_totals()
    }
  end

  defp sum_totals(items) do
    Enum.reduce(items, Decimal.new("0.00"), &Decimal.add(&1.line_total, &2))
  end

  defp format_currency(%Decimal{} = amount) do
    sign = if Decimal.negative?(amount), do: "-", else: ""
    abs_amount = Decimal.abs(amount)
    "$#{Decimal.round(abs_amount, 2)}"
  end

  defp format_currency(_), do: "$0.00"

  defp format_percent(%Decimal{} = rate) do
    rate
    |> Decimal.mult(100)
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
    |> Kernel.<>("%")
  end

  defp format_percent(_), do: "0%"
end
```

**Step 4: Commit**

```bash
git add lib/mcp_web/components/terminal/
git commit -m "feat(terminal): add customer section, line items, and order summary components"
```

---

## Phase 3: Main LiveView Refactor

### Task 3.1: Refactor Terminal LiveView to Single-Screen Layout

**Files:**
- Modify: `lib/mcp_web/live/store/terminal_live.ex`
- Modify: `test/mcp_web/live/store/terminal_live_test.exs`

**Step 1: Write new tests for single-screen layout**

```elixir
# Replace content of test/mcp_web/live/store/terminal_live_test.exs
defmodule McpWeb.Store.TerminalLiveTest do
  use McpWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Mcp.Accounts.Auth
  alias Mcp.Accounts.User
  alias Mcp.Platform.Tenant

  @moduletag :integration

  setup %{conn: _conn} do
    unique_id = "#{System.system_time(:millisecond)}-#{:rand.uniform(999_999)}"
    schema_name = "acq_#{String.replace(unique_id, "-", "_")}"

    tenant =
      Tenant
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Terminal Tenant #{unique_id}",
        slug: "terminal-#{unique_id}",
        subdomain: "terminal-#{unique_id}",
        company_schema: schema_name
      })
      |> Ash.create!()

    user =
      User
      |> Ash.Changeset.for_create(:register, %{
        email: "terminal_#{unique_id}@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "Test",
        last_name: "User"
      })
      |> Ash.Changeset.force_change_attribute(:tenant_id, tenant.id)
      |> Ash.create!()

    {:ok, session_data} = Auth.create_user_session(user, "127.0.0.1")

    host = "#{tenant.subdomain}.localhost"

    authed_conn =
      build_conn()
      |> Map.put(:host, host)
      |> put_req_header("x-forwarded-host", host)
      |> init_test_session(%{"tenant_id" => tenant.id})
      |> put_req_cookie("_mcp_access_token", session_data.access_token)
      |> put_req_cookie("_mcp_refresh_token", session_data.refresh_token)
      |> put_req_cookie("_mcp_session_id", session_data.session_id)

    {:ok, conn: authed_conn, tenant: tenant, user: user}
  end

  describe "Terminal LiveView - Single Screen Layout" do
    test "renders two-panel layout", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/test-store/terminal")

      assert html =~ "Virtual Terminal"
      assert html =~ ~s(data-testid="customer-section")
      assert html =~ ~s(data-testid="line-items")
      assert html =~ ~s(data-testid="order-summary")
    end

    test "shows empty state when no items", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/test-store/terminal")

      assert html =~ ~s(data-testid="empty-items")
      assert html =~ "No items yet"
    end

    test "charge button is disabled when no items", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/test-store/terminal")

      assert html =~ "disabled"
      assert html =~ "Charge Card"
    end

    test "has exit button to dashboard", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/test-store/terminal")

      assert html =~ ~s(href="/app/stores/test-store/dashboard")
    end
  end
end
```

**Step 2: Refactor the LiveView**

```elixir
# lib/mcp_web/live/store/terminal_live.ex
defmodule McpWeb.Store.TerminalLive do
  @moduledoc """
  Virtual Terminal LiveView - Single-screen payment interface.

  Features:
  - Customer search and quick-create
  - Unified line items (products, fees, discounts, tips)
  - Multiple payment methods (card, payment link, email request)
  - Transaction history
  """
  use McpWeb, :live_view

  import McpWeb.Portal.FocusedLayout
  import McpWeb.Components.Terminal.CustomerSection
  import McpWeb.Components.Terminal.LineItems
  import McpWeb.Components.Terminal.OrderSummary

  alias McpWeb.Store.Terminal.State

  @impl Phoenix.LiveView
  def mount(%{"store_slug" => store_slug}, _session, socket) do
    state = State.new(store_slug)

    socket =
      socket
      |> assign(:page_title, "Virtual Terminal")
      |> assign(:state, state)
      |> assign(:customer_search_query, "")
      |> assign(:item_search_query, "")

    {:ok, socket, layout: {McpWeb.Layouts, :focused}}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.focused_layout
      title="Virtual Terminal"
      exit={~p"/app/stores/#{@state.store_slug}/dashboard"}
      variant={:two_panel}
    >
      <:left_panel>
        <div class="flex flex-col h-full">
          <.customer_section
            customer={@state.customer}
            search_query={@customer_search_query}
          />
          <div class="flex-1 overflow-hidden">
            <.line_items
              items={@state.line_items}
              search_query={@item_search_query}
            />
          </div>
        </div>
      </:left_panel>

      <:right_panel>
        <.order_summary
          subtotal={@state.subtotal}
          tax={@state.tax}
          total={@state.total}
          tax_rate={@state.tax_rate}
          items={@state.line_items}
          can_charge={State.can_charge?(@state)}
          can_send_link={State.can_send_link?(@state)}
          can_email={State.can_email?(@state)}
        />
      </:right_panel>
    </.focused_layout>
    """
  end

  # Event Handlers

  @impl Phoenix.LiveView
  def handle_event("search_customers", %{"query" => query}, socket) do
    {:noreply, assign(socket, customer_search_query: query)}
  end

  def handle_event("search_items", %{"query" => query}, socket) do
    {:noreply, assign(socket, item_search_query: query)}
  end

  def handle_event("clear_customer", _params, socket) do
    state = State.clear_customer(socket.assigns.state)
    {:noreply, assign(socket, state: state)}
  end

  def handle_event("remove_item", %{"id" => id}, socket) do
    state = State.remove_item(socket.assigns.state, id)
    {:noreply, assign(socket, state: state)}
  end

  def handle_event("increase_quantity", %{"id" => id}, socket) do
    item = Enum.find(socket.assigns.state.line_items, &(&1.id == id))
    if item do
      state = State.update_quantity(socket.assigns.state, id, item.quantity + 1)
      {:noreply, assign(socket, state: state)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("decrease_quantity", %{"id" => id}, socket) do
    item = Enum.find(socket.assigns.state.line_items, &(&1.id == id))
    if item do
      state = State.update_quantity(socket.assigns.state, id, item.quantity - 1)
      {:noreply, assign(socket, state: state)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("open_payment_drawer", _params, socket) do
    state = State.open_payment_drawer(socket.assigns.state)
    {:noreply, assign(socket, state: state)}
  end

  def handle_event("close_payment_drawer", _params, socket) do
    state = State.close_payment_drawer(socket.assigns.state)
    {:noreply, assign(socket, state: state)}
  end

  def handle_event("open_send_link_modal", _params, socket) do
    state = State.open_send_link_modal(socket.assigns.state)
    {:noreply, assign(socket, state: state)}
  end

  def handle_event("close_send_link_modal", _params, socket) do
    state = State.close_send_link_modal(socket.assigns.state)
    {:noreply, assign(socket, state: state)}
  end

  def handle_event("open_email_modal", _params, socket) do
    state = State.open_email_modal(socket.assigns.state)
    {:noreply, assign(socket, state: state)}
  end

  def handle_event("close_email_modal", _params, socket) do
    state = State.close_email_modal(socket.assigns.state)
    {:noreply, assign(socket, state: state)}
  end

  def handle_event("new_transaction", _params, socket) do
    state = State.reset(socket.assigns.state)
    {:noreply, assign(socket, state: state, customer_search_query: "", item_search_query: "")}
  end

  # Catch-all handler
  def handle_event(event, params, socket) do
    require Logger
    Logger.debug("Unhandled terminal event: #{inspect(event)} with params: #{inspect(params)}")
    {:noreply, socket}
  end
end
```

**Step 3: Run tests**

Run: `mix test test/mcp_web/live/store/terminal_live_test.exs --seed 0`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/mcp_web/live/store/terminal_live.ex test/mcp_web/live/store/terminal_live_test.exs
git commit -m "refactor(terminal): convert to single-screen two-panel layout"
```

---

## Phase 4: Payment Drawer

### Task 4.1: Create Payment Drawer Component

**Files:**
- Create: `lib/mcp_web/components/terminal/payment_drawer.ex`

**Step 1: Create the component**

```elixir
# lib/mcp_web/components/terminal/payment_drawer.ex
defmodule McpWeb.Components.Terminal.PaymentDrawer do
  @moduledoc """
  Bottom drawer for card payment entry.
  Two-column layout: order summary (left) and card form (right).
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1, button: 1, input: 1]

  attr :show, :boolean, required: true
  attr :customer, :map, default: nil
  attr :items, :list, default: []
  attr :total, :any, required: true
  attr :tax, :any, required: true
  attr :payment_status, :atom, default: nil
  attr :transaction_result, :map, default: nil

  def payment_drawer(assigns) do
    ~H"""
    <div
      :if={@show}
      class="fixed inset-0 z-50"
      data-testid="payment-drawer"
    >
      <!-- Backdrop -->
      <div
        class="absolute inset-0 bg-base-300/50 backdrop-blur-sm"
        phx-click="close_payment_drawer"
      />

      <!-- Drawer -->
      <div class="absolute bottom-0 left-0 right-0 bg-base-100 rounded-t-2xl shadow-xl max-h-[85vh] overflow-hidden">
        <!-- Handle -->
        <div class="flex justify-center py-2">
          <div class="w-12 h-1 rounded-full bg-base-300" />
        </div>

        <!-- Header -->
        <div class="flex items-center justify-between px-6 pb-4 border-b border-base-300">
          <h2 class="text-xl font-bold">
            <%= case @payment_status do %>
              <% :success -> %>
                Payment Complete
              <% :failed -> %>
                Payment Failed
              <% _ -> %>
                Complete Payment
            <% end %>
          </h2>
          <button
            type="button"
            class="btn btn-ghost btn-sm btn-circle"
            phx-click="close_payment_drawer"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>

        <!-- Content -->
        <div class="grid grid-cols-2 gap-0 divide-x divide-base-300">
          <!-- Left: Order Summary -->
          <div class="p-6 max-h-[calc(85vh-80px)] overflow-y-auto">
            <.order_recap customer={@customer} items={@items} total={@total} tax={@tax} />
          </div>

          <!-- Right: Card Form or Result -->
          <div class="p-6 max-h-[calc(85vh-80px)] overflow-y-auto">
            <%= case @payment_status do %>
              <% :success -> %>
                <.success_state result={@transaction_result} total={@total} />
              <% :failed -> %>
                <.failed_state result={@transaction_result} />
              <% :processing -> %>
                <.processing_state />
              <% _ -> %>
                <.card_form total={@total} customer={@customer} />
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp order_recap(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- Customer -->
      <%= if @customer do %>
        <div class="rounded-lg bg-base-200/50 p-3">
          <div class="flex items-center gap-3">
            <div class="avatar placeholder">
              <div class="w-8 rounded-full bg-primary text-primary-content text-xs">
                {initials(@customer.name)}
              </div>
            </div>
            <div>
              <div class="font-medium text-sm">{@customer.name}</div>
              <div class="text-xs text-base-content/70">{@customer[:email]}</div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Line Items -->
      <div class="space-y-2">
        <%= for item <- @items do %>
          <div class="flex items-center justify-between text-sm">
            <div class="flex items-center gap-2">
              <%= if item.type == :product && item[:image_url] do %>
                <img src={item.image_url} class="w-8 h-8 rounded object-cover" />
              <% else %>
                <div class="w-8 h-8 rounded bg-base-200 flex items-center justify-center text-xs">
                  {item_icon(item.type)}
                </div>
              <% end %>
              <div>
                <div class="font-medium">{item.name}</div>
                <%= if item.type == :product do %>
                  <div class="text-xs text-base-content/70">
                    {format_currency(item.unit_price)} × {item.quantity}
                  </div>
                <% end %>
              </div>
            </div>
            <span class={[
              "font-medium tabular-nums",
              item.type == :discount && "text-success"
            ]}>
              {format_currency(item.line_total)}
            </span>
          </div>
        <% end %>
      </div>

      <!-- Totals -->
      <div class="border-t border-base-300 pt-3 space-y-1">
        <div class="flex justify-between text-sm">
          <span class="text-base-content/70">Tax</span>
          <span class="tabular-nums">{format_currency(@tax)}</span>
        </div>
        <div class="flex justify-between text-lg font-bold">
          <span>Total</span>
          <span class="tabular-nums text-primary">{format_currency(@total)}</span>
        </div>
      </div>
    </div>
    """
  end

  defp card_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <h3 class="font-semibold text-base-content/70">Card information</h3>

      <div class="space-y-3">
        <div>
          <label class="label py-1">
            <span class="label-text text-sm">Card number</span>
          </label>
          <div class="relative">
            <input
              type="text"
              placeholder="4242 4242 4242 4242"
              class="input input-bordered w-full pr-12"
              inputmode="numeric"
              maxlength="19"
              phx-change="card_number_change"
              name="card_number"
              data-testid="card-number-input"
            />
            <div class="absolute right-3 top-1/2 -translate-y-1/2">
              <.icon name="hero-credit-card" class="size-5 text-base-content/30" />
            </div>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="label py-1">
              <span class="label-text text-sm">Expiry</span>
            </label>
            <input
              type="text"
              placeholder="MM/YY"
              class="input input-bordered w-full"
              inputmode="numeric"
              maxlength="5"
              phx-change="expiry_change"
              name="expiry"
              data-testid="expiry-input"
            />
          </div>
          <div>
            <label class="label py-1">
              <span class="label-text text-sm">CVC</span>
            </label>
            <input
              type="text"
              placeholder="123"
              class="input input-bordered w-full"
              inputmode="numeric"
              maxlength="4"
              phx-change="cvv_change"
              name="cvv"
              data-testid="cvv-input"
            />
          </div>
        </div>

        <div>
          <label class="label py-1">
            <span class="label-text text-sm">Billing ZIP (optional)</span>
          </label>
          <input
            type="text"
            placeholder="12345"
            class="input input-bordered w-full"
            inputmode="numeric"
            maxlength="10"
            phx-change="zip_change"
            name="zip"
            data-testid="zip-input"
          />
        </div>

        <%= if @customer do %>
          <label class="flex items-center gap-2 cursor-pointer">
            <input type="checkbox" class="checkbox checkbox-sm" name="save_card" />
            <span class="label-text">Save card for {@customer.name}</span>
          </label>
        <% end %>
      </div>

      <.button
        variant="primary"
        class="w-full btn-lg mt-4"
        phx-click="charge_card"
        data-testid="pay-button"
      >
        Pay {format_currency(@total)}
      </.button>
    </div>
    """
  end

  defp processing_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-12">
      <div class="loading loading-spinner loading-lg text-primary mb-4" />
      <p class="font-semibold">Processing payment...</p>
      <p class="text-sm text-base-content/70">Please wait</p>
    </div>
    """
  end

  defp success_state(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-col items-center text-center">
        <div class="w-16 h-16 rounded-full bg-success/20 flex items-center justify-center mb-4">
          <.icon name="hero-check" class="size-8 text-success" />
        </div>
        <h3 class="text-xl font-bold">Approved</h3>
        <p class="text-3xl font-bold text-primary mt-2">{format_currency(@total)}</p>
        <p class="text-base-content/70 mt-1">
          {card_brand(@result[:card_brand])} •••• {@result[:last_four]}
        </p>
      </div>

      <div class="space-y-2 text-sm">
        <div class="flex justify-between">
          <span class="text-base-content/70">Transaction ID</span>
          <span class="font-mono">{@result[:transaction_id]}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-base-content/70">Date</span>
          <span>{format_datetime(@result[:timestamp])}</span>
        </div>
      </div>

      <div class="space-y-2 pt-4">
        <.button variant="outline" class="w-full" phx-click="email_receipt">
          <.icon name="hero-envelope" class="size-4 mr-2" />
          Email Receipt
        </.button>
        <.button variant="outline" class="w-full" phx-click="print_receipt">
          <.icon name="hero-printer" class="size-4 mr-2" />
          Print Receipt
        </.button>
        <.button variant="primary" class="w-full" phx-click="new_transaction">
          <.icon name="hero-plus" class="size-4 mr-2" />
          New Transaction
        </.button>
      </div>
    </div>
    """
  end

  defp failed_state(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-col items-center text-center">
        <div class="w-16 h-16 rounded-full bg-error/20 flex items-center justify-center mb-4">
          <.icon name="hero-x-mark" class="size-8 text-error" />
        </div>
        <h3 class="text-xl font-bold">Declined</h3>
        <p class="text-base-content/70 mt-2">{@result[:error_message] || "Card was declined"}</p>
      </div>

      <div class="space-y-2 pt-4">
        <.button variant="primary" class="w-full" phx-click="retry_payment">
          Try Again
        </.button>
        <.button variant="outline" class="w-full" phx-click="close_payment_drawer">
          Cancel
        </.button>
      </div>
    </div>
    """
  end

  # Helpers

  defp initials(name) when is_binary(name) do
    name |> String.split() |> Enum.take(2) |> Enum.map_join(&String.first/1) |> String.upcase()
  end
  defp initials(_), do: "?"

  defp item_icon(:product), do: "📦"
  defp item_icon(:fee), do: "🚚"
  defp item_icon(:discount), do: "🏷️"
  defp item_icon(:tip), do: "💰"

  defp format_currency(%Decimal{} = amount) do
    sign = if Decimal.negative?(amount), do: "-", else: ""
    "$#{sign}#{Decimal.abs(amount) |> Decimal.round(2)}"
  end
  defp format_currency(_), do: "$0.00"

  defp card_brand("visa"), do: "Visa"
  defp card_brand("mastercard"), do: "Mastercard"
  defp card_brand("amex"), do: "Amex"
  defp card_brand(_), do: "Card"

  defp format_datetime(nil), do: ""
  defp format_datetime(dt), do: Calendar.strftime(dt, "%B %d, %Y · %I:%M %p")
end
```

**Step 2: Add payment drawer to terminal LiveView render**

Add to the render function in `terminal_live.ex`:

```elixir
# Add import at top of terminal_live.ex
import McpWeb.Components.Terminal.PaymentDrawer

# Add to end of render function, after focused_layout closing tag:
<.payment_drawer
  show={@state.show_payment_drawer}
  customer={@state.customer}
  items={@state.line_items}
  total={@state.total}
  tax={@state.tax}
  payment_status={@state.payment_status}
  transaction_result={@state.transaction_result}
/>
```

**Step 3: Commit**

```bash
git add lib/mcp_web/components/terminal/payment_drawer.ex lib/mcp_web/live/store/terminal_live.ex
git commit -m "feat(terminal): add payment drawer with card entry and result states"
```

---

## Phase 5: Modals (Quick Create, Send Link, Email)

### Task 5.1: Create Quick Create Modal

**Files:**
- Create: `lib/mcp_web/components/terminal/quick_create_modal.ex`

*(Implementation follows same pattern - tabbed modal for Product/Fee/Discount/Tip)*

### Task 5.2: Create Send Link Modal

**Files:**
- Create: `lib/mcp_web/components/terminal/send_link_modal.ex`

### Task 5.3: Create Email Request Modal

**Files:**
- Create: `lib/mcp_web/components/terminal/email_modal.ex`

### Task 5.4: Create Customer Modal

**Files:**
- Create: `lib/mcp_web/components/terminal/customer_modal.ex`

---

## Phase 6: Browse Drawer

### Task 6.1: Create Browse Drawer Component

**Files:**
- Create: `lib/mcp_web/components/terminal/browse_drawer.ex`

*(Implementation: Right drawer with search, filters, and product/fee/discount list)*

---

## Phase 7: History Drawer

### Task 7.1: Create History Drawer Component

**Files:**
- Create: `lib/mcp_web/components/terminal/history_drawer.ex`

---

## Phase 8: Integration & Polish

### Task 8.1: Wire Up All Event Handlers

### Task 8.2: Add Loading States

### Task 8.3: Add Animations

### Task 8.4: Run Full Test Suite

```bash
mix test test/mcp_web/live/store/terminal_live_test.exs
mix precommit
```

---

## Phase 9: AI Integration (Future)

### Task 9.1: Customer Intelligence Card
### Task 9.2: Product Suggestions
### Task 9.3: Card Risk Warnings
### Task 9.4: Post-Transaction Insights
### Task 9.5: Natural Language Entry

---

## Summary

**Total Tasks:** ~25 tasks across 9 phases
**Estimated Scope:** Core functionality in Phases 1-4, polish in 5-8, AI in 9

**Key Files Created:**
- `lib/mcp_web/live/store/terminal/state.ex` - State management
- `lib/mcp_web/components/core/drawer.ex` - Reusable drawer
- `lib/mcp_web/components/terminal/*.ex` - Terminal-specific components
- `lib/mcp_web/live/store/terminal_live.ex` - Refactored LiveView

**Testing Strategy:**
- Unit tests for State module (pure functions)
- Integration tests for LiveView (user flows)
- Component tests for complex components
