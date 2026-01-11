defmodule McpWeb.Components.Pos.PaymentModalTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Components.Pos.PaymentModal

  describe "payment_modal/1" do
    test "renders total due prominently" do
      html =
        render_component(&PaymentModal.payment_modal/1, %{
          total: Decimal.new("58.44"),
          customer: nil,
          show: true
        })

      assert html =~ "Total Due:"
      assert html =~ "$58.44"
    end

    test "renders all payment method buttons" do
      html =
        render_component(&PaymentModal.payment_modal/1, %{
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

      html =
        render_component(&PaymentModal.payment_modal/1, %{
          total: Decimal.new("58.44"),
          customer: customer,
          show: true
        })

      assert html =~ "LOYALTY"
      assert html =~ "580 points"
      assert html =~ "$58.00"
      assert html =~ "Apply points"
    end

    test "renders tip options" do
      html =
        render_component(&PaymentModal.payment_modal/1, %{
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
      html =
        render_component(&PaymentModal.payment_modal/1, %{
          total: Decimal.new("58.44"),
          customer: nil,
          show: true
        })

      assert html =~ "Back"
      assert html =~ ~s(phx-click="cancel_payment")
    end

    test "does not render when show is false" do
      html =
        render_component(&PaymentModal.payment_modal/1, %{
          total: Decimal.new("58.44"),
          customer: nil,
          show: false
        })

      refute html =~ "Total Due:"
      refute html =~ "PAYMENT"
    end
  end
end
