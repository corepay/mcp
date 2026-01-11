defmodule McpWeb.Components.Terminal.CardEntryTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Components.Terminal.CardEntry

  describe "card_entry/1" do
    test "renders card number input" do
      html =
        render_component(&CardEntry.card_entry/1, %{
          card_number: "",
          expiry: "",
          cvv: "",
          amount: Decimal.new("50.00")
        })

      assert html =~ "Card Number"
      assert html =~ ~s(data-testid="card-number-input")
    end

    test "renders expiry and CVV inputs" do
      html =
        render_component(&CardEntry.card_entry/1, %{
          card_number: "",
          expiry: "",
          cvv: "",
          amount: Decimal.new("50.00")
        })

      assert html =~ "MM/YY"
      assert html =~ "CVV"
      assert html =~ ~s(data-testid="expiry-input")
      assert html =~ ~s(data-testid="cvv-input")
    end

    test "renders amount being charged" do
      html =
        render_component(&CardEntry.card_entry/1, %{
          card_number: "",
          expiry: "",
          cvv: "",
          amount: Decimal.new("125.50")
        })

      assert html =~ "$125.50"
    end

    test "renders charge button" do
      html =
        render_component(&CardEntry.card_entry/1, %{
          card_number: "4111111111111111",
          expiry: "12/25",
          cvv: "123",
          amount: Decimal.new("50.00")
        })

      assert html =~ "Charge"
      assert html =~ ~s(data-testid="charge-btn")
    end
  end
end
