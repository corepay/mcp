defmodule McpWeb.Components.Terminal.AmountEntryTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Components.Terminal.AmountEntry

  describe "amount_entry/1" do
    test "renders amount display" do
      html =
        render_component(&AmountEntry.amount_entry/1, %{
          amount: Decimal.new("0.00")
        })

      assert html =~ "$0.00"
      assert html =~ ~s(data-testid="amount-display")
    end

    test "renders numeric keypad" do
      html =
        render_component(&AmountEntry.amount_entry/1, %{
          amount: Decimal.new("0.00")
        })

      # Should have digits 0-9
      assert html =~ ~r/>\s*1\s*</
      assert html =~ ~r/>\s*2\s*</
      assert html =~ ~r/>\s*0\s*</
      assert html =~ ~s(data-testid="keypad")
    end

    test "renders clear and backspace buttons" do
      html =
        render_component(&AmountEntry.amount_entry/1, %{
          amount: Decimal.new("0.00")
        })

      assert html =~ "Clear"
      assert html =~ ~s(phx-click="clear_amount")
      assert html =~ ~s(phx-click="backspace")
    end

    test "renders continue button" do
      html =
        render_component(&AmountEntry.amount_entry/1, %{
          amount: Decimal.new("50.00")
        })

      assert html =~ "Continue"
      assert html =~ ~s(data-testid="continue-btn")
    end
  end
end
