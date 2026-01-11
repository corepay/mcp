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

      fee = %{
        id: "fee_1",
        name: "Rush Delivery",
        amount: Decimal.new("25.00"),
        type: :fee,
        percent: false
      }

      state = State.add_fee(state, fee)

      assert length(state.line_items) == 1
      [item] = state.line_items
      assert item.type == :fee
      assert Decimal.eq?(item.line_total, Decimal.new("25.00"))
    end

    test "add_discount/2 adds a percentage discount" do
      state =
        State.new("downtown")
        |> State.add_product(
          %{id: "prod_1", name: "Tee", price: Decimal.new("100.00"), type: :product},
          1
        )

      discount = %{
        id: "disc_1",
        name: "Summer Sale",
        amount: Decimal.new("10"),
        type: :discount,
        percent: true
      }

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
      state =
        State.new("downtown")
        |> State.add_product(
          %{id: "prod_1", name: "Tee", price: Decimal.new("29.99"), type: :product},
          1
        )
        |> State.add_product(
          %{id: "prod_2", name: "Mug", price: Decimal.new("12.00"), type: :product},
          1
        )

      state = State.remove_item(state, "prod_1")

      assert length(state.line_items) == 1
      assert hd(state.line_items).id == "prod_2"
    end

    test "update_quantity/3 updates product quantity" do
      state =
        State.new("downtown")
        |> State.add_product(
          %{id: "prod_1", name: "Tee", price: Decimal.new("29.99"), type: :product},
          2
        )

      state = State.update_quantity(state, "prod_1", 5)

      [item] = state.line_items
      assert item.quantity == 5
      assert Decimal.eq?(item.line_total, Decimal.new("149.95"))
    end

    test "update_quantity/3 removes item when quantity is 0" do
      state =
        State.new("downtown")
        |> State.add_product(
          %{id: "prod_1", name: "Tee", price: Decimal.new("29.99"), type: :product},
          2
        )

      state = State.update_quantity(state, "prod_1", 0)

      assert state.line_items == []
    end
  end

  describe "totals calculation" do
    test "calculates subtotal from all items" do
      state =
        State.new("downtown")
        |> State.add_product(
          %{id: "prod_1", name: "Tee", price: Decimal.new("29.99"), type: :product},
          2
        )
        |> State.add_fee(%{id: "fee_1", name: "Shipping", amount: Decimal.new("5.00")})

      # 2 * 29.99 + 5.00 = 64.98
      assert Decimal.eq?(state.subtotal, Decimal.new("64.98"))
    end

    test "calculates tax on products and fees only" do
      state =
        State.new("downtown")
        |> State.add_product(
          %{id: "prod_1", name: "Tee", price: Decimal.new("100.00"), type: :product},
          1
        )
        |> State.add_fee(%{id: "fee_1", name: "Shipping", amount: Decimal.new("10.00")})
        |> State.add_tip(Decimal.new("15.00"))

      # Tax rate is 8.25%
      # Taxable: 100 + 10 = 110
      # Tax: 110 * 0.0825 = 9.075, rounded to 9.08
      # Subtotal: 100 + 10 + 15 = 125
      # Total: 125 + 9.08 = 134.08
      assert Decimal.eq?(state.tax, Decimal.new("9.08"))
      assert Decimal.eq?(state.subtotal, Decimal.new("125.00"))
      assert Decimal.eq?(state.total, Decimal.new("134.08"))
    end

    test "discounts reduce taxable amount" do
      state =
        State.new("downtown")
        |> State.add_product(
          %{id: "prod_1", name: "Tee", price: Decimal.new("100.00"), type: :product},
          1
        )
        |> State.add_discount(%{
          id: "disc_1",
          name: "10% Off",
          amount: Decimal.new("10"),
          percent: true
        })

      # Taxable: 100, Discount: -10
      # Tax: (100 - 10) * 0.0825 = 7.425, rounded to 7.43
      # Subtotal: 100 - 10 = 90
      # Total: 90 + 7.43 = 97.43
      assert Decimal.eq?(state.subtotal, Decimal.new("90.00"))
      assert Decimal.eq?(state.tax, Decimal.new("7.43"))
      assert Decimal.eq?(state.total, Decimal.new("97.43"))
    end

    test "percentage discounts recalculate when taxable changes" do
      state =
        State.new("downtown")
        |> State.add_product(
          %{id: "prod_1", name: "Tee", price: Decimal.new("100.00"), type: :product},
          1
        )
        |> State.add_discount(%{
          id: "disc_1",
          name: "10% Off",
          amount: Decimal.new("10"),
          percent: true
        })

      # Initial: $100 product, -$10 discount = $90 subtotal
      assert Decimal.eq?(state.subtotal, Decimal.new("90.00"))

      # Add another product - discount should recalculate
      state =
        State.add_product(
          state,
          %{id: "prod_2", name: "Mug", price: Decimal.new("50.00"), type: :product},
          1
        )

      # Now: $150 taxable, 10% = -$15
      # Subtotal: 150 - 15 = 135
      discount_item = Enum.find(state.line_items, &(&1.type == :discount))
      assert Decimal.eq?(discount_item.line_total, Decimal.new("-15.00"))
      assert Decimal.eq?(state.subtotal, Decimal.new("135.00"))
    end
  end

  describe "customer management" do
    test "set_customer/2 sets customer on state" do
      state = State.new("downtown")
      customer = %{id: "cust_1", name: "John Doe", email: "john@example.com"}

      state = State.set_customer(state, customer)

      assert state.customer == customer
    end

    test "clear_customer/1 removes customer from state" do
      state = State.new("downtown")
      customer = %{id: "cust_1", name: "John Doe", email: "john@example.com"}

      state =
        state
        |> State.set_customer(customer)
        |> State.clear_customer()

      assert state.customer == nil
    end
  end

  describe "UI state toggles" do
    test "toggle_payment_drawer/1 toggles visibility" do
      state = State.new("downtown")

      assert state.show_payment_drawer == false

      state = State.toggle_payment_drawer(state)
      assert state.show_payment_drawer == true

      state = State.toggle_payment_drawer(state)
      assert state.show_payment_drawer == false
    end

    test "toggle_send_link_modal/1 toggles visibility" do
      state = State.new("downtown")

      state = State.toggle_send_link_modal(state)
      assert state.show_send_link_modal == true
    end

    test "toggle_email_modal/1 toggles visibility" do
      state = State.new("downtown")

      state = State.toggle_email_modal(state)
      assert state.show_email_modal == true
    end

    test "toggle_history_drawer/1 toggles visibility" do
      state = State.new("downtown")

      state = State.toggle_history_drawer(state)
      assert state.show_history_drawer == true
    end

    test "open_browse_drawer/2 opens drawer with type" do
      state = State.new("downtown")

      state = State.open_browse_drawer(state, :products)

      assert state.show_browse_drawer == true
      assert state.browse_drawer_type == :products
    end

    test "close_browse_drawer/1 closes drawer and clears type" do
      state =
        State.new("downtown")
        |> State.open_browse_drawer(:products)
        |> State.close_browse_drawer()

      assert state.show_browse_drawer == false
      assert state.browse_drawer_type == nil
    end
  end

  describe "clear/1" do
    test "resets line items and customer" do
      state =
        State.new("downtown")
        |> State.add_product(
          %{id: "prod_1", name: "Tee", price: Decimal.new("29.99"), type: :product},
          1
        )
        |> State.set_customer(%{id: "cust_1", name: "John Doe"})
        |> State.clear()

      assert state.line_items == []
      assert state.customer == nil
      assert Decimal.eq?(state.subtotal, Decimal.new("0.00"))
      assert Decimal.eq?(state.total, Decimal.new("0.00"))
    end
  end

  describe "set_note/2" do
    test "sets note on state" do
      state = State.new("downtown")

      state = State.set_note(state, "Customer requested expedited shipping")

      assert state.note == "Customer requested expedited shipping"
    end

    test "clears note when nil is passed" do
      state =
        State.new("downtown")
        |> State.set_note("Some note")

      state = State.set_note(state, nil)

      assert state.note == nil
    end

    test "updates existing note" do
      state =
        State.new("downtown")
        |> State.set_note("Original note")

      state = State.set_note(state, "Updated note")

      assert state.note == "Updated note"
    end
  end
end
