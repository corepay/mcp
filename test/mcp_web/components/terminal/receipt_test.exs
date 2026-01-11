defmodule McpWeb.Components.Terminal.ReceiptTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Components.Terminal.Receipt

  describe "receipt/1" do
    test "renders success checkmark" do
      html =
        render_component(&Receipt.receipt/1, %{
          status: :success,
          amount: Decimal.new("50.00"),
          last_four: "1111",
          transaction_id: "txn_123"
        })

      assert html =~ "Payment Successful"
      assert html =~ "hero-check-circle"
    end

    test "renders transaction details" do
      html =
        render_component(&Receipt.receipt/1, %{
          status: :success,
          amount: Decimal.new("125.50"),
          last_four: "4242",
          transaction_id: "txn_abc123"
        })

      assert html =~ "$125.50"
      assert html =~ "4242"
      assert html =~ "txn_abc123"
    end

    test "renders new transaction button" do
      html =
        render_component(&Receipt.receipt/1, %{
          status: :success,
          amount: Decimal.new("50.00"),
          last_four: "1111",
          transaction_id: "txn_123"
        })

      assert html =~ "New Transaction"
      assert html =~ ~s(data-testid="new-transaction-btn")
    end

    test "renders print receipt button" do
      html =
        render_component(&Receipt.receipt/1, %{
          status: :success,
          amount: Decimal.new("50.00"),
          last_four: "1111",
          transaction_id: "txn_123"
        })

      assert html =~ "Print Receipt"
    end
  end
end
