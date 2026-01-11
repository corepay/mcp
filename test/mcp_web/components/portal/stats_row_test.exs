defmodule McpWeb.Portal.StatsRowTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Portal.StatsRow

  describe "stats_row/1" do
    test "renders container with 4-column grid classes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <StatsRow.stats_row>
          <StatsRow.stat label="Revenue" value="$12,847" />
        </StatsRow.stats_row>
        """)

      assert html =~ "grid"
      assert html =~ "grid-cols-2"
      assert html =~ "md:grid-cols-4"
    end

    test "renders multiple stat children" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <StatsRow.stats_row>
          <StatsRow.stat label="Revenue" value="$12,847" />
          <StatsRow.stat label="Transactions" value="156" />
          <StatsRow.stat label="Customers" value="89" />
          <StatsRow.stat label="Avg Order" value="$82.35" />
        </StatsRow.stats_row>
        """)

      assert html =~ "Revenue"
      assert html =~ "$12,847"
      assert html =~ "Transactions"
      assert html =~ "156"
      assert html =~ "Customers"
      assert html =~ "89"
      assert html =~ "Avg Order"
      assert html =~ "$82.35"
    end
  end

  describe "stat/1" do
    test "renders stat with label and value" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <StatsRow.stat label="Revenue" value="$12,847" />
        """)

      assert html =~ "Revenue"
      assert html =~ "$12,847"
      assert html =~ "bg-base-100"
      assert html =~ "rounded-box"
      assert html =~ "shadow-sm"
    end

    test "shows positive trend in green with up arrow" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <StatsRow.stat label="Revenue" value="$12,847" trend={12} comparison="vs yesterday" />
        """)

      assert html =~ "text-success"
      assert html =~ "hero-arrow-trending-up"
      assert html =~ "+12%"
      assert html =~ "vs yesterday"
    end

    test "shows negative trend in red with down arrow" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <StatsRow.stat label="Customers" value="89" trend={-3} comparison="vs yesterday" />
        """)

      assert html =~ "text-error"
      assert html =~ "hero-arrow-trending-down"
      assert html =~ "-3%"
      assert html =~ "vs yesterday"
    end

    test "shows neutral trend (0) with no arrow" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <StatsRow.stat label="Orders" value="100" trend={0} comparison="vs yesterday" />
        """)

      # Should not contain trend arrows
      refute html =~ "hero-arrow-trending-up"
      refute html =~ "hero-arrow-trending-down"
      # Should still show the comparison text
      assert html =~ "vs yesterday"
      # Should show 0%
      assert html =~ "0%"
    end

    test "links to detail page when href provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <StatsRow.stat label="Revenue" value="$12,847" href="/dashboard/revenue" />
        """)

      assert html =~ "href=\"/dashboard/revenue\""
      # Should have hover state for clickable
      assert html =~ "hover:"
    end

    test "displays comparison text" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <StatsRow.stat label="Revenue" value="$12,847" trend={5} comparison="vs last week" />
        """)

      assert html =~ "vs last week"
    end

    test "renders icon when provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <StatsRow.stat label="Revenue" value="$12,847" icon="hero-currency-dollar" />
        """)

      assert html =~ "hero-currency-dollar"
    end

    test "renders without trend when not provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <StatsRow.stat label="Revenue" value="$12,847" />
        """)

      # Should not have trend arrow classes
      refute html =~ "hero-arrow-trending-up"
      refute html =~ "hero-arrow-trending-down"
    end
  end
end
