# test/mcp_web/components/portal/action_sidebar_test.exs
defmodule McpWeb.Portal.ActionSidebarTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Portal.ActionSidebar

  describe "action_sidebar/1" do
    test "renders action_sidebar container with correct styling" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ActionSidebar.action_sidebar>
          <:actions>
            <ActionSidebar.sidebar_action icon="hero-plus" label="Add New" href="/products/new" />
          </:actions>
        </ActionSidebar.action_sidebar>
        """)

      # Container has w-72 (288px) width and sticky positioning
      assert html =~ "w-72"
      assert html =~ "sticky"
      assert html =~ "top-20"
    end

    test "renders QUICK ACTIONS section with sidebar_action buttons" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ActionSidebar.action_sidebar>
          <:actions>
            <ActionSidebar.sidebar_action icon="hero-plus" label="Add New" href="/products/new" />
            <ActionSidebar.sidebar_action
              icon="hero-arrow-up-tray"
              label="Import"
              phx-click="open_import"
            />
          </:actions>
        </ActionSidebar.action_sidebar>
        """)

      # Section header with muted styling
      assert html =~ "QUICK ACTIONS"
      assert html =~ "text-xs"
      assert html =~ "uppercase"
      assert html =~ "tracking-wider"
      assert html =~ "text-base-content/60"

      # Action buttons content
      assert html =~ "Add New"
      assert html =~ "Import"
    end

    test "renders FILTERS section with sidebar_filter dropdowns" do
      assigns = %{
        status_options: [{"All", ""}, {"Active", "active"}, {"Inactive", "inactive"}],
        category_options: [{"All", ""}, {"Electronics", "electronics"}, {"Clothing", "clothing"}]
      }

      html =
        rendered_to_string(~H"""
        <ActionSidebar.action_sidebar>
          <:filters>
            <ActionSidebar.sidebar_filter label="Status" options={@status_options} field={:status} />
            <ActionSidebar.sidebar_filter label="Category" options={@category_options} field={:category} />
          </:filters>
        </ActionSidebar.action_sidebar>
        """)

      # Section header
      assert html =~ "FILTERS"

      # Filter labels
      assert html =~ "Status"
      assert html =~ "Category"

      # Filter options
      assert html =~ "Active"
      assert html =~ "Electronics"
    end

    test "renders AI INSIGHTS section when provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ActionSidebar.action_sidebar>
          <:insights>
            <ActionSidebar.ai_insight
              message="3 products are low on stock"
              action="View low stock"
              href="/products?filter=low_stock"
            />
          </:insights>
        </ActionSidebar.action_sidebar>
        """)

      # Section header
      assert html =~ "AI INSIGHTS"

      # Insight card with DaisyUI card styling
      assert html =~ "3 products are low on stock"
      assert html =~ "View low stock"
      assert html =~ "bg-base-200"
      assert html =~ "rounded-box"
    end

    test "hides empty sections (no :insights slot = no section header)" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ActionSidebar.action_sidebar>
          <:actions>
            <ActionSidebar.sidebar_action icon="hero-plus" label="Add New" href="/products/new" />
          </:actions>
        </ActionSidebar.action_sidebar>
        """)

      # Should have QUICK ACTIONS
      assert html =~ "QUICK ACTIONS"

      # Should NOT have AI INSIGHTS or FILTERS since they weren't provided
      refute html =~ "AI INSIGHTS"
      refute html =~ "FILTERS"
    end

    test "hides filters section when no filters provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ActionSidebar.action_sidebar>
          <:actions>
            <ActionSidebar.sidebar_action icon="hero-plus" label="Add New" href="/products/new" />
          </:actions>
          <:insights>
            <ActionSidebar.ai_insight
              message="Test insight"
              action="View"
              href="/test"
            />
          </:insights>
        </ActionSidebar.action_sidebar>
        """)

      assert html =~ "QUICK ACTIONS"
      assert html =~ "AI INSIGHTS"
      refute html =~ "FILTERS"
    end
  end

  describe "sidebar_action/1" do
    test "actions have icons and labels" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ActionSidebar.sidebar_action icon="hero-plus" label="Add New" href="/products/new" />
        """)

      # Icon
      assert html =~ "hero-plus"

      # Label
      assert html =~ "Add New"

      # Button styling
      assert html =~ "btn"
      assert html =~ "btn-ghost"
      assert html =~ "btn-sm"
      assert html =~ "justify-start"
      assert html =~ "gap-2"
      assert html =~ "w-full"
    end

    test "actions can be links (href)" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ActionSidebar.sidebar_action icon="hero-plus" label="Add New" href="/products/new" />
        """)

      assert html =~ ~r/<a[^>]*href="\/products\/new"/
      assert html =~ "Add New"
    end

    test "actions can be LiveView events (phx-click)" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ActionSidebar.sidebar_action icon="hero-arrow-up-tray" label="Import" phx-click="open_import" />
        """)

      assert html =~ ~r/<button[^>]*phx-click="open_import"/
      assert html =~ "Import"
    end

    test "actions support phx-value attributes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ActionSidebar.sidebar_action
          icon="hero-trash"
          label="Delete"
          phx-click="delete"
          phx-value-id="123"
        />
        """)

      assert html =~ "phx-click=\"delete\""
      assert html =~ "phx-value-id=\"123\""
    end
  end

  describe "sidebar_filter/1" do
    test "renders select with label and options" do
      assigns = %{
        options: [{"All", ""}, {"Active", "active"}, {"Inactive", "inactive"}]
      }

      html =
        rendered_to_string(~H"""
        <ActionSidebar.sidebar_filter label="Status" options={@options} field={:status} />
        """)

      # Label
      assert html =~ "Status"

      # Select element
      assert html =~ "<select"
      assert html =~ "name=\"status\""

      # Options
      assert html =~ "All"
      assert html =~ "Active"
      assert html =~ "Inactive"
    end

    test "supports phx-change event" do
      assigns = %{
        options: [{"All", ""}, {"Active", "active"}]
      }

      html =
        rendered_to_string(~H"""
        <ActionSidebar.sidebar_filter
          label="Status"
          options={@options}
          field={:status}
          phx-change="filter_changed"
        />
        """)

      assert html =~ "phx-change=\"filter_changed\""
    end

    test "select has proper styling" do
      assigns = %{
        options: [{"All", ""}]
      }

      html =
        rendered_to_string(~H"""
        <ActionSidebar.sidebar_filter label="Status" options={@options} field={:status} />
        """)

      assert html =~ "select"
      assert html =~ "select-bordered"
      assert html =~ "select-sm"
      assert html =~ "w-full"
    end
  end

  describe "ai_insight/1" do
    test "renders insight card with message and action" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ActionSidebar.ai_insight
          message="3 products are low on stock"
          action="View low stock"
          href="/products?filter=low_stock"
        />
        """)

      # Message
      assert html =~ "3 products are low on stock"

      # Action link
      assert html =~ "View low stock"
      assert html =~ ~r/href="\/products\?filter=low_stock"/

      # Card styling
      assert html =~ "bg-base-200"
      assert html =~ "rounded-box"
      assert html =~ "p-3"
    end

    test "renders insight with phx-click action" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ActionSidebar.ai_insight
          message="New recommendations available"
          action="View recommendations"
          phx-click="show_recommendations"
        />
        """)

      assert html =~ "New recommendations available"
      assert html =~ "View recommendations"
      assert html =~ "phx-click=\"show_recommendations\""
    end

    test "insight action link has proper styling" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ActionSidebar.ai_insight
          message="Test message"
          action="Test action"
          href="/test"
        />
        """)

      # Action should be a link with accent styling
      assert html =~ "link"
      assert html =~ "link-accent"
    end
  end
end
