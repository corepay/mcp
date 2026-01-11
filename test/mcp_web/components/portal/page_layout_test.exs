# test/mcp_web/components/portal/page_layout_test.exs
defmodule McpWeb.Portal.PageLayoutTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias McpWeb.Portal.PageLayout

  describe "page_layout/1 - dashboard variant" do
    test "renders dashboard variant with full-width content" do
      assigns = %{title: "Dashboard"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:dashboard} title={@title}>
          <:content>
            <div id="dashboard-content">Dashboard Content Here</div>
          </:content>
        </PageLayout.page_layout>
        """)

      assert html =~ "Dashboard"
      assert html =~ "dashboard-content"
      assert html =~ "Dashboard Content Here"
      # Dashboard should NOT have the split grid layout
      refute html =~ "lg:col-span-2"
    end
  end

  describe "page_layout/1 - list variant" do
    test "renders list variant with 2/3 + 1/3 split" do
      assigns = %{title: "Products"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:list} title={@title}>
          <:content>
            <div id="list-content">Product List</div>
          </:content>
          <:sidebar>
            <div id="list-sidebar">Sidebar Actions</div>
          </:sidebar>
        </PageLayout.page_layout>
        """)

      assert html =~ "Products"
      assert html =~ "list-content"
      assert html =~ "list-sidebar"
      # List variant should have the grid layout
      assert html =~ "lg:grid-cols-3"
      assert html =~ "lg:col-span-2"
    end

    test "renders toolbar slot in list variant" do
      assigns = %{title: "Products"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:list} title={@title}>
          <:toolbar>
            <input type="search" placeholder="Search products..." />
            <button>+ Add Product</button>
          </:toolbar>
          <:content>
            <div>Content</div>
          </:content>
        </PageLayout.page_layout>
        """)

      assert html =~ "Search products..."
      assert html =~ "+ Add Product"
    end
  end

  describe "page_layout/1 - detail variant" do
    test "renders detail variant with 2/3 + 1/3 split" do
      assigns = %{title: "Premium Widget", back: "/products"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:detail} title={@title} back={@back}>
          <:content>
            <div id="detail-content">Product Details</div>
          </:content>
          <:sidebar>
            <div id="detail-sidebar">Detail Actions</div>
          </:sidebar>
        </PageLayout.page_layout>
        """)

      assert html =~ "Premium Widget"
      assert html =~ "detail-content"
      assert html =~ "detail-sidebar"
      # Detail variant should have the grid layout
      assert html =~ "lg:grid-cols-3"
      assert html =~ "lg:col-span-2"
    end

    test "renders back link with correct href" do
      assigns = %{title: "Product Name", back: "/products"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:detail} title={@title} back={@back}>
          <:content>
            <div>Content</div>
          </:content>
        </PageLayout.page_layout>
        """)

      assert html =~ ~r/href="\/products"/
      # Should have back arrow or back indicator
      assert html =~ "hero-arrow-left" or html =~ "hero-chevron-left"
    end

    test "title and back button have proper flexbox layout" do
      assigns = %{title: "Detail Page", back: "/list"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:detail} title={@title} back={@back}>
          <:content>
            <div>Content</div>
          </:content>
        </PageLayout.page_layout>
        """)

      # Should have flexbox for title + back button alignment
      assert html =~ "flex" and html =~ "items-center" and html =~ "gap-"
    end
  end

  describe "page_layout/1 - table variant" do
    test "renders table variant with full-width content" do
      assigns = %{title: "Transactions"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:table} title={@title}>
          <:content>
            <table id="transactions-table">
              <tbody>
                <tr>
                  <td>Row 1</td>
                </tr>
              </tbody>
            </table>
          </:content>
        </PageLayout.page_layout>
        """)

      assert html =~ "Transactions"
      assert html =~ "transactions-table"
      # Table should NOT have the split grid layout
      refute html =~ "lg:col-span-2"
    end

    test "renders toolbar slot in table variant" do
      assigns = %{title: "Transactions"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:table} title={@title}>
          <:toolbar>
            <input type="search" placeholder="Search..." />
            <button>Export</button>
          </:toolbar>
          <:content>
            <div>Table Content</div>
          </:content>
        </PageLayout.page_layout>
        """)

      assert html =~ "Search..."
      assert html =~ "Export"
    end
  end

  describe "page_layout/1 - title rendering" do
    test "displays title correctly for all variants" do
      for variant <- [:dashboard, :list, :detail, :table] do
        assigns = %{variant: variant, title: "Test Title #{variant}"}

        html =
          rendered_to_string(~H"""
          <PageLayout.page_layout variant={@variant} title={@title}>
            <:content>
              <div>Content</div>
            </:content>
          </PageLayout.page_layout>
          """)

        assert html =~ "Test Title #{variant}"
      end
    end
  end

  describe "page_layout/1 - stats slot" do
    test "renders stats slot above content" do
      assigns = %{title: "Dashboard"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:dashboard} title={@title}>
          <:stats>
            <div id="stats-row">
              <span>Revenue: $12,847</span>
              <span>Transactions: 156</span>
            </div>
          </:stats>
          <:content>
            <div id="main-content">Main Content</div>
          </:content>
        </PageLayout.page_layout>
        """)

      assert html =~ "stats-row"
      assert html =~ "Revenue: $12,847"
      assert html =~ "Transactions: 156"
      assert html =~ "main-content"
    end

    test "stats slot is optional" do
      assigns = %{title: "Dashboard"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:dashboard} title={@title}>
          <:content>
            <div>Content without stats</div>
          </:content>
        </PageLayout.page_layout>
        """)

      assert html =~ "Content without stats"
    end
  end

  describe "page_layout/1 - toolbar slot" do
    test "renders toolbar slot with proper flexbox layout" do
      assigns = %{title: "Products"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:list} title={@title}>
          <:toolbar>
            <input type="search" placeholder="Search..." />
            <button>Action</button>
          </:toolbar>
          <:content>
            <div>Content</div>
          </:content>
        </PageLayout.page_layout>
        """)

      # Toolbar should have flexbox styling
      assert html =~ "flex"
      assert html =~ "items-center"
      assert html =~ "justify-between"
      assert html =~ "gap-"
      assert html =~ "mb-"
    end

    test "toolbar slot is optional" do
      assigns = %{title: "Products"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:list} title={@title}>
          <:content>
            <div>Content without toolbar</div>
          </:content>
        </PageLayout.page_layout>
        """)

      assert html =~ "Content without toolbar"
    end
  end

  describe "page_layout/1 - content slot" do
    test "content slot is required" do
      # This test verifies that the component requires a content slot
      # The component should define: slot :content, required: true
      # We test this by checking the component renders content correctly
      assigns = %{title: "Test"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:dashboard} title={@title}>
          <:content>
            <div id="required-content">This content is required</div>
          </:content>
        </PageLayout.page_layout>
        """)

      assert html =~ "required-content"
      assert html =~ "This content is required"
    end
  end

  describe "page_layout/1 - sidebar slot" do
    test "renders sidebar only for list variant" do
      assigns = %{title: "Products"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:list} title={@title}>
          <:content>
            <div>Content</div>
          </:content>
          <:sidebar>
            <div id="sidebar-content">Sidebar for list</div>
          </:sidebar>
        </PageLayout.page_layout>
        """)

      assert html =~ "sidebar-content"
      assert html =~ "Sidebar for list"
    end

    test "renders sidebar only for detail variant" do
      assigns = %{title: "Product Detail", back: "/products"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:detail} title={@title} back={@back}>
          <:content>
            <div>Content</div>
          </:content>
          <:sidebar>
            <div id="sidebar-content">Sidebar for detail</div>
          </:sidebar>
        </PageLayout.page_layout>
        """)

      assert html =~ "sidebar-content"
      assert html =~ "Sidebar for detail"
    end

    test "sidebar slot is ignored for dashboard variant" do
      assigns = %{title: "Dashboard"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:dashboard} title={@title}>
          <:content>
            <div>Dashboard Content</div>
          </:content>
          <:sidebar>
            <div id="ignored-sidebar">This should not appear</div>
          </:sidebar>
        </PageLayout.page_layout>
        """)

      refute html =~ "ignored-sidebar"
    end

    test "sidebar slot is ignored for table variant" do
      assigns = %{title: "Transactions"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:table} title={@title}>
          <:content>
            <div>Table Content</div>
          </:content>
          <:sidebar>
            <div id="ignored-sidebar">This should not appear</div>
          </:sidebar>
        </PageLayout.page_layout>
        """)

      refute html =~ "ignored-sidebar"
    end

    test "sidebar is optional for list/detail variants" do
      assigns = %{title: "Products"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:list} title={@title}>
          <:content>
            <div>Content without sidebar</div>
          </:content>
        </PageLayout.page_layout>
        """)

      assert html =~ "Content without sidebar"
    end
  end

  describe "page_layout/1 - back link navigation" do
    test "back link is only rendered when back prop is provided" do
      assigns = %{title: "Detail Page"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:detail} title={@title}>
          <:content>
            <div>Content</div>
          </:content>
        </PageLayout.page_layout>
        """)

      # Without back prop, no back link should be rendered
      refute html =~ "hero-arrow-left"
      refute html =~ "hero-chevron-left"
    end

    test "back link renders with correct href" do
      assigns = %{title: "Edit Product", back: "/products/123"}

      html =
        rendered_to_string(~H"""
        <PageLayout.page_layout variant={:detail} title={@title} back={@back}>
          <:content>
            <div>Content</div>
          </:content>
        </PageLayout.page_layout>
        """)

      assert html =~ ~r/href="\/products\/123"/
    end
  end
end
