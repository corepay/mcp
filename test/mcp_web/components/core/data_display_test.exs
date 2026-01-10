# test/mcp_web/components/core/data_display_test.exs
defmodule McpWeb.Core.DataDisplayTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Core.DataDisplay

  describe "stat_card/1" do
    test "renders value and label" do
      assigns = %{value: "$12,847", label: "Total Revenue"}

      html =
        rendered_to_string(~H"""
        <DataDisplay.stat_card value={@value} label={@label} />
        """)

      assert html =~ "$12,847"
      assert html =~ "Total Revenue"
      assert html =~ "stat"
    end

    test "renders trend when provided" do
      assigns = %{value: "156", label: "Transactions", trend: "+12%", trend_direction: :up}

      html =
        rendered_to_string(~H"""
        <DataDisplay.stat_card
          value={@value}
          label={@label}
          trend={@trend}
          trend_direction={@trend_direction}
        />
        """)

      assert html =~ "+12%"
      assert html =~ "text-success"
    end

    test "renders down trend with error color" do
      assigns = %{value: "89", label: "Customers", trend: "-3%", trend_direction: :down}

      html =
        rendered_to_string(~H"""
        <DataDisplay.stat_card
          value={@value}
          label={@label}
          trend={@trend}
          trend_direction={@trend_direction}
        />
        """)

      assert html =~ "-3%"
      assert html =~ "text-error"
    end

    test "renders icon when provided" do
      assigns = %{value: "$82.35", label: "Avg Order", icon: "hero-currency-dollar"}

      html =
        rendered_to_string(~H"""
        <DataDisplay.stat_card value={@value} label={@label} icon={@icon} />
        """)

      assert html =~ "hero-currency-dollar"
    end
  end
end
