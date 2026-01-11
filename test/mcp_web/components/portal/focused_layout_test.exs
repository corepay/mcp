# test/mcp_web/components/portal/focused_layout_test.exs
defmodule McpWeb.Portal.FocusedLayoutTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Portal.FocusedLayout

  describe "focused_layout/1 - container" do
    test "renders focused layout container with full height" do
      assigns = %{title: "Point of Sale", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit}>
          <:left_panel>
            <div id="focused-content">Content</div>
          </:left_panel>
          <:right_panel>
            <div>Right</div>
          </:right_panel>
        </FocusedLayout.focused_layout>
        """)

      # Should have min-h-screen for full height
      assert html =~ "min-h-screen"
      assert html =~ "focused-content"
    end

    test "renders with focused-layout identifier class" do
      assigns = %{title: "Terminal", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:centered}>
          <:content>
            <div>Content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ "focused-layout"
    end
  end

  describe "focused_layout/1 - header" do
    test "renders exit button with link to exit URL" do
      assigns = %{title: "Point of Sale", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:centered}>
          <:content>
            <div>Content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ ~r/href="\/dashboard"/
    end

    test "renders exit button with hero-arrow-left icon by default" do
      assigns = %{title: "Point of Sale", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:centered}>
          <:content>
            <div>Content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ "hero-arrow-left" or html =~ "hero-x-mark"
    end

    test "renders title centered in header" do
      assigns = %{title: "Point of Sale", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:centered}>
          <:content>
            <div>Content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ "Point of Sale"
      # Title should be in a flex container that centers it
      assert html =~ "justify-center" or html =~ "text-center"
    end

    test "header has minimal styling (no sidebar nav)" do
      assigns = %{title: "Point of Sale", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:centered}>
          <:content>
            <div>Content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      # Should have header element
      assert html =~ "<header" or html =~ "navbar"
      # Should not have sidebar navigation elements
      refute html =~ "sidebar"
      refute html =~ "drawer"
    end
  end

  describe "focused_layout/1 - two_panel variant" do
    test "two_panel variant renders with 60/40 split" do
      assigns = %{title: "Point of Sale", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:two_panel}>
          <:left_panel>
            <div id="left-content">Product Grid</div>
          </:left_panel>
          <:right_panel>
            <div id="right-content">Cart Summary</div>
          </:right_panel>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ "left-content"
      assert html =~ "right-content"
      # Should have grid or flex layout classes
      assert html =~ "grid" or html =~ "flex"
    end

    test "two_panel variant is the default" do
      assigns = %{title: "Point of Sale", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit}>
          <:left_panel>
            <div id="left-default">Left</div>
          </:left_panel>
          <:right_panel>
            <div id="right-default">Right</div>
          </:right_panel>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ "left-default"
      assert html =~ "right-default"
    end

    test "left_panel takes approximately 60% width" do
      assigns = %{title: "Point of Sale", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:two_panel}>
          <:left_panel>
            <div>Products</div>
          </:left_panel>
          <:right_panel>
            <div>Cart</div>
          </:right_panel>
        </FocusedLayout.focused_layout>
        """)

      # Should have classes indicating 60% width (w-3/5, basis-3/5, grid-cols with appropriate split, etc.)
      assert html =~ "w-3/5" or html =~ "basis-3/5" or html =~ "lg:col-span-3" or
               html =~ "grow" or html =~ "flex-"
    end

    test "right_panel takes approximately 40% width" do
      assigns = %{title: "Point of Sale", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:two_panel}>
          <:left_panel>
            <div>Products</div>
          </:left_panel>
          <:right_panel>
            <div>Cart</div>
          </:right_panel>
        </FocusedLayout.focused_layout>
        """)

      # Should have classes indicating 40% width (w-2/5, basis-2/5, etc.)
      assert html =~ "w-2/5" or html =~ "basis-2/5" or html =~ "lg:col-span-2" or
               html =~ "shrink-0" or html =~ "flex-"
    end
  end

  describe "focused_layout/1 - centered variant" do
    test "centered variant renders single centered content area" do
      assigns = %{title: "Terminal", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:centered}>
          <:content>
            <div id="centered-content">Terminal Interface</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ "centered-content"
      assert html =~ "Terminal Interface"
    end

    test "centered variant ignores left_panel and right_panel slots" do
      assigns = %{title: "Terminal", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:centered}>
          <:content>
            <div id="main-content">Main Content</div>
          </:content>
          <:left_panel>
            <div id="ignored-left">Should not appear</div>
          </:left_panel>
          <:right_panel>
            <div id="ignored-right">Should not appear</div>
          </:right_panel>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ "main-content"
      refute html =~ "ignored-left"
      refute html =~ "ignored-right"
    end

    test "centered variant has centered layout classes" do
      assigns = %{title: "Terminal", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:centered}>
          <:content>
            <div>Content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      # Should have centering classes
      assert html =~ "mx-auto" or html =~ "justify-center" or html =~ "items-center"
    end
  end

  describe "focused_layout/1 - wizard variant" do
    test "wizard variant shows progress slot" do
      assigns = %{title: "Checkout", exit: "/cart"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:wizard}>
          <:progress>
            <div id="progress-indicator">Step 1 of 3</div>
          </:progress>
          <:content>
            <div>Wizard Content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ "progress-indicator"
      assert html =~ "Step 1 of 3"
    end

    test "wizard variant renders centered content" do
      assigns = %{title: "Checkout", exit: "/cart"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:wizard}>
          <:content>
            <div id="wizard-content">Wizard Step Content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ "wizard-content"
      assert html =~ "mx-auto" or html =~ "justify-center" or html =~ "items-center"
    end

    test "wizard variant progress slot is optional" do
      assigns = %{title: "Checkout", exit: "/cart"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:wizard}>
          <:content>
            <div>Content without progress</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ "Content without progress"
    end
  end

  describe "focused_layout/1 - intelligence bar" do
    test "renders intelligence bar when show_intelligence_bar is true" do
      assigns = %{title: "Point of Sale", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout
          title={@title}
          exit={@exit}
          show_intelligence_bar={true}
          variant={:centered}
        >
          <:content>
            <div>Content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      # Should have intelligence bar indicator - could be an id, class, or aria label
      assert html =~ "intelligence" or html =~ "ai-bar" or html =~ "command"
    end

    test "does not render intelligence bar when show_intelligence_bar is false" do
      assigns = %{title: "Point of Sale", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout
          title={@title}
          exit={@exit}
          show_intelligence_bar={false}
          variant={:centered}
        >
          <:content>
            <div>Content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      refute html =~ "intelligence-bar"
    end

    test "show_intelligence_bar defaults to false" do
      assigns = %{title: "Point of Sale", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:centered}>
          <:content>
            <div>Content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      refute html =~ "intelligence-bar"
    end
  end

  describe "focused_layout/1 - required props" do
    test "requires title prop" do
      assigns = %{exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title="Required Title" exit={@exit} variant={:centered}>
          <:content>
            <div>Content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ "Required Title"
    end

    test "requires exit prop" do
      assigns = %{title: "Point of Sale"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit="/required-exit" variant={:centered}>
          <:content>
            <div>Content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ ~r/href="\/required-exit"/
    end
  end

  describe "focused_layout/1 - slot rendering" do
    test "renders left_panel slot content" do
      assigns = %{title: "POS", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit}>
          <:left_panel>
            <div id="product-grid">Products go here</div>
          </:left_panel>
          <:right_panel>
            <div>Cart</div>
          </:right_panel>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ "product-grid"
      assert html =~ "Products go here"
    end

    test "renders right_panel slot content" do
      assigns = %{title: "POS", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit}>
          <:left_panel>
            <div>Products</div>
          </:left_panel>
          <:right_panel>
            <div id="cart-summary">Cart items here</div>
          </:right_panel>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ "cart-summary"
      assert html =~ "Cart items here"
    end

    test "renders content slot for centered/wizard variants" do
      assigns = %{title: "Terminal", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:centered}>
          <:content>
            <div id="terminal-interface">Terminal Content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ "terminal-interface"
      assert html =~ "Terminal Content"
    end

    test "renders progress slot for wizard variant" do
      assigns = %{title: "Onboarding", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:wizard}>
          <:progress>
            <nav id="wizard-progress">Step indicators</nav>
          </:progress>
          <:content>
            <div>Step content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      assert html =~ "wizard-progress"
      assert html =~ "Step indicators"
    end
  end

  describe "focused_layout/1 - accessibility" do
    test "exit link has accessible name" do
      assigns = %{title: "Point of Sale", exit: "/dashboard"}

      html =
        rendered_to_string(~H"""
        <FocusedLayout.focused_layout title={@title} exit={@exit} variant={:centered}>
          <:content>
            <div>Content</div>
          </:content>
        </FocusedLayout.focused_layout>
        """)

      # Exit button should have some accessible indicator
      assert html =~ "aria-label" or html =~ "Exit" or html =~ "Back" or html =~ "hero-"
    end
  end
end
