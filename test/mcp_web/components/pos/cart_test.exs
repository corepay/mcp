defmodule McpWeb.Components.Pos.CartTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Components.Pos.Cart

  describe "cart/1" do
    test "renders empty cart message when no items" do
      html =
        render_component(&Cart.cart/1, %{
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
      html =
        render_component(&Cart.cart/1, %{
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

      html =
        render_component(&Cart.cart/1, %{
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
          product: %{id: "1", name: "Premium Tee", price: Decimal.new("29.99")},
          quantity: 1,
          subtotal: Decimal.new("29.99")
        }
      ]

      html =
        render_component(&Cart.cart/1, %{
          items: items,
          customer: nil,
          subtotal: Decimal.new("29.99"),
          tax: Decimal.new("2.47"),
          total: Decimal.new("32.46")
        })

      assert html =~ "Premium Tee"
      assert html =~ "$29.99"
      assert html =~ ~s(data-testid="qty-decrease")
      assert html =~ ~s(data-testid="qty-increase")
      assert html =~ ~s(data-testid="remove-item")
    end

    test "renders totals section" do
      items = [
        %{
          id: "1",
          product: %{id: "1", name: "Test", price: Decimal.new("50.00")},
          quantity: 1,
          subtotal: Decimal.new("50.00")
        }
      ]

      html =
        render_component(&Cart.cart/1, %{
          items: items,
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
      items = [
        %{
          id: "1",
          product: %{id: "1", name: "Test", price: Decimal.new("50.00")},
          quantity: 1,
          subtotal: Decimal.new("50.00")
        }
      ]

      html =
        render_component(&Cart.cart/1, %{
          items: items,
          customer: nil,
          subtotal: Decimal.new("53.99"),
          tax: Decimal.new("4.45"),
          total: Decimal.new("58.44")
        })

      assert html =~ "PAY"
      assert html =~ "$58.44"
      assert html =~ ~s(data-testid="pay-btn")
    end

    test "renders discount and note buttons when cart has items" do
      items = [
        %{
          id: "1",
          product: %{id: "1", name: "Test", price: Decimal.new("50.00")},
          quantity: 1,
          subtotal: Decimal.new("50.00")
        }
      ]

      html =
        render_component(&Cart.cart/1, %{
          items: items,
          customer: nil,
          subtotal: Decimal.new("50.00"),
          tax: Decimal.new("0.00"),
          total: Decimal.new("50.00")
        })

      assert html =~ "+ Discount"
      assert html =~ "+ Note"
    end

    test "renders hold and clear buttons when cart has items" do
      items = [
        %{
          id: "1",
          product: %{id: "1", name: "Test", price: Decimal.new("50.00")},
          quantity: 1,
          subtotal: Decimal.new("50.00")
        }
      ]

      html =
        render_component(&Cart.cart/1, %{
          items: items,
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
