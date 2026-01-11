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

  describe "navbar/1" do
    test "renders navbar with start, center, end zones" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Navigation.navbar>
          <:start>
            <span>Logo</span>
          </:start>
          <:center>
            <a>Dashboard</a>
            <a>Products</a>
          </:center>
          <:nav_end>
            <button>Profile</button>
          </:nav_end>
        </Navigation.navbar>
        """)

      assert html =~ "navbar"
      assert html =~ "Logo"
      assert html =~ "Dashboard"
      assert html =~ "Profile"
      assert html =~ "navbar-start"
      assert html =~ "navbar-center"
      assert html =~ "navbar-end"
    end

    test "renders with custom background" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Navigation.navbar class="bg-primary">
          <:start>Logo</:start>
        </Navigation.navbar>
        """)

      assert html =~ "bg-primary"
    end
  end

  describe "sidebar/1" do
    test "renders sidebar with header and items" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Navigation.sidebar>
          <:header>
            <span>Store Name</span>
          </:header>
          <:section title="SELL">
            <li><a>POS</a></li>
            <li><a>Terminal</a></li>
          </:section>
          <:footer>
            <li><a>Settings</a></li>
          </:footer>
        </Navigation.sidebar>
        """)

      assert html =~ "Store Name"
      assert html =~ "SELL"
      assert html =~ "POS"
      assert html =~ "Settings"
    end

    test "renders collapsible sections" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Navigation.sidebar>
          <:section title="MANAGE" collapsible>
            <li><a>Customers</a></li>
          </:section>
        </Navigation.sidebar>
        """)

      assert html =~ "MANAGE"
      assert html =~ "collapse"
    end
  end

  describe "tabs/1" do
    test "renders tabs with items" do
      assigns = %{
        items: [
          %{label: "Dashboard", href: "/", active: true},
          %{label: "Products", href: "/products", active: false},
          %{label: "Settings", href: "/settings", active: false}
        ]
      }

      html =
        rendered_to_string(~H"""
        <Navigation.tabs items={@items} />
        """)

      assert html =~ "tabs"
      assert html =~ "Dashboard"
      assert html =~ "Products"
      assert html =~ "tab-active"
    end

    test "renders with bordered variant" do
      assigns = %{items: [%{label: "Tab 1", href: "#", active: true}]}

      html =
        rendered_to_string(~H"""
        <Navigation.tabs items={@items} variant="bordered" />
        """)

      assert html =~ "tabs-bordered"
    end

    test "renders with boxed variant" do
      assigns = %{items: [%{label: "Tab 1", href: "#", active: true}]}

      html =
        rendered_to_string(~H"""
        <Navigation.tabs items={@items} variant="boxed" />
        """)

      assert html =~ "tabs-boxed"
    end

    test "renders with lifted variant" do
      assigns = %{items: [%{label: "Tab 1", href: "#", active: true}]}

      html =
        rendered_to_string(~H"""
        <Navigation.tabs items={@items} variant="lifted" />
        """)

      assert html =~ "tabs-lifted"
    end

    test "renders with size attribute" do
      assigns = %{items: [%{label: "Tab 1", href: "#", active: true}]}

      html =
        rendered_to_string(~H"""
        <Navigation.tabs items={@items} size="lg" />
        """)

      assert html =~ "tabs-lg"
    end

    test "includes accessibility attributes" do
      assigns = %{items: [%{label: "Tab 1", href: "#", active: true}]}

      html =
        rendered_to_string(~H"""
        <Navigation.tabs items={@items} />
        """)

      assert html =~ ~r/role="tablist"/
      assert html =~ ~r/role="tab"/
    end
  end
end
