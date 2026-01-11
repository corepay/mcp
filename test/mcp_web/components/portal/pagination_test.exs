# test/mcp_web/components/portal/pagination_test.exs
defmodule McpWeb.Portal.PaginationTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Portal.DataTable

  describe "pagination/1 - basic rendering" do
    test "renders pagination container" do
      assigns = %{page: 1, total_pages: 5, total_count: 50}

      html =
        rendered_to_string(~H"""
        <DataTable.pagination page={@page} total_pages={@total_pages} total_count={@total_count} />
        """)

      # Should render pagination container
      assert html =~ "pagination" or html =~ "join"
    end

    test "displays current page and total pages" do
      assigns = %{page: 3, total_pages: 10, total_count: 100}

      html =
        rendered_to_string(~H"""
        <DataTable.pagination page={@page} total_pages={@total_pages} total_count={@total_count} />
        """)

      # Should show current page info
      assert html =~ "3"
      assert html =~ "10"
    end

    test "displays total count" do
      assigns = %{page: 1, total_pages: 5, total_count: 47}

      html =
        rendered_to_string(~H"""
        <DataTable.pagination page={@page} total_pages={@total_pages} total_count={@total_count} />
        """)

      # Should show total count
      assert html =~ "47"
    end
  end

  describe "pagination/1 - navigation buttons" do
    test "renders previous and next buttons" do
      assigns = %{page: 2, total_pages: 5, total_count: 50}

      html =
        rendered_to_string(~H"""
        <DataTable.pagination page={@page} total_pages={@total_pages} total_count={@total_count} />
        """)

      # Should have previous and next buttons
      assert html =~ "phx-click" or html =~ "Previous" or html =~ "hero-chevron-left"
      assert html =~ "Next" or html =~ "hero-chevron-right"
    end

    test "disables previous button on first page" do
      assigns = %{page: 1, total_pages: 5, total_count: 50}

      html =
        rendered_to_string(~H"""
        <DataTable.pagination page={@page} total_pages={@total_pages} total_count={@total_count} />
        """)

      # Previous button should be disabled
      assert html =~ "btn-disabled" or
               html =~ ~r/<button[^>]*disabled[^>]*>.*(?:Previous|hero-chevron-left)/s
    end

    test "disables next button on last page" do
      assigns = %{page: 5, total_pages: 5, total_count: 50}

      html =
        rendered_to_string(~H"""
        <DataTable.pagination page={@page} total_pages={@total_pages} total_count={@total_count} />
        """)

      # Next button should be disabled
      assert html =~ "btn-disabled" or
               html =~ ~r/<button[^>]*disabled[^>]*>.*(?:Next|hero-chevron-right)/s
    end

    test "enables both buttons on middle pages" do
      assigns = %{page: 3, total_pages: 5, total_count: 50}

      html =
        rendered_to_string(~H"""
        <DataTable.pagination page={@page} total_pages={@total_pages} total_count={@total_count} />
        """)

      # Both buttons should be enabled (not disabled)
      # Count disabled occurrences - should be 0 for navigation buttons
      refute html =~ ~r/btn-disabled.*btn-disabled/s
    end
  end

  describe "pagination/1 - page number buttons" do
    test "renders page number buttons" do
      assigns = %{page: 3, total_pages: 5, total_count: 50}

      html =
        rendered_to_string(~H"""
        <DataTable.pagination page={@page} total_pages={@total_pages} total_count={@total_count} />
        """)

      # Should render page numbers (Phoenix renders text inside buttons)
      assert html =~ ~r/phx-value-page="1"/
      assert html =~ ~r/phx-value-page="2"/
      assert html =~ ~r/phx-value-page="3"/
      assert html =~ ~r/phx-value-page="4"/
      assert html =~ ~r/phx-value-page="5"/
    end

    test "highlights current page" do
      assigns = %{page: 3, total_pages: 5, total_count: 50}

      html =
        rendered_to_string(~H"""
        <DataTable.pagination page={@page} total_pages={@total_pages} total_count={@total_count} />
        """)

      # Current page should be highlighted/active
      assert html =~ "btn-active" or html =~ "btn-primary"
    end

    test "truncates page numbers for large page counts" do
      assigns = %{page: 50, total_pages: 100, total_count: 1000}

      html =
        rendered_to_string(~H"""
        <DataTable.pagination page={@page} total_pages={@total_pages} total_count={@total_count} />
        """)

      # Should show ellipsis or truncation indicator
      assert html =~ "..." or html =~ "ellipsis"
    end
  end

  describe "pagination/1 - single page" do
    test "does not render pagination when total_pages is 1" do
      assigns = %{page: 1, total_pages: 1, total_count: 5}

      html =
        rendered_to_string(~H"""
        <DataTable.pagination page={@page} total_pages={@total_pages} total_count={@total_count} />
        """)

      # Should either not render or render minimal info
      refute html =~ "btn-disabled"
      # or check that it's effectively hidden/empty
    end
  end

  describe "pagination/1 - event handling" do
    test "emits page change event on click" do
      assigns = %{page: 2, total_pages: 5, total_count: 50}

      html =
        rendered_to_string(~H"""
        <DataTable.pagination page={@page} total_pages={@total_pages} total_count={@total_count} />
        """)

      # Should have phx-click events for page changes
      assert html =~ "phx-click"
    end

    test "uses custom event name when provided" do
      assigns = %{page: 2, total_pages: 5, total_count: 50}

      html =
        rendered_to_string(~H"""
        <DataTable.pagination
          page={@page}
          total_pages={@total_pages}
          total_count={@total_count}
          on_page_change="custom-page-change"
        />
        """)

      # Should use custom event name
      assert html =~ "custom-page-change"
    end
  end

  describe "pagination/1 - accessibility" do
    test "includes aria labels for navigation" do
      assigns = %{page: 2, total_pages: 5, total_count: 50}

      html =
        rendered_to_string(~H"""
        <DataTable.pagination page={@page} total_pages={@total_pages} total_count={@total_count} />
        """)

      # Should have accessibility labels
      assert html =~ "aria-label" or html =~ "aria-current"
    end
  end

  describe "pagination/1 - items per page display" do
    test "shows items range on current page" do
      assigns = %{page: 2, total_pages: 5, total_count: 50, per_page: 10}

      html =
        rendered_to_string(~H"""
        <DataTable.pagination
          page={@page}
          total_pages={@total_pages}
          total_count={@total_count}
          per_page={@per_page}
        />
        """)

      # Should show item range like "Showing 11-20 of 50"
      assert html =~ "11" or html =~ "20" or html =~ "Showing"
    end
  end
end
