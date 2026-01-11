# test/mcp_web/components/core/navigation_test.exs
defmodule McpWeb.Core.NavigationTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Core.Navigation

  describe "dropdown/1" do
    test "renders dropdown with trigger and content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Navigation.dropdown>
          <:trigger>
            <button>Open</button>
          </:trigger>
          <:content>
            <li><a>Item 1</a></li>
            <li><a>Item 2</a></li>
          </:content>
        </Navigation.dropdown>
        """)

      assert html =~ "dropdown"
      assert html =~ "Open"
      assert html =~ "Item 1"
    end

    test "renders with position" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Navigation.dropdown position="end">
          <:trigger>Menu</:trigger>
          <:content>
            <li>Item</li>
          </:content>
        </Navigation.dropdown>
        """)

      assert html =~ "dropdown-end"
    end

    test "renders with hover trigger" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Navigation.dropdown hover>
          <:trigger>Hover</:trigger>
          <:content>
            <li>Item</li>
          </:content>
        </Navigation.dropdown>
        """)

      assert html =~ "dropdown-hover"
    end
  end
end
