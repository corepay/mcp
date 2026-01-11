defmodule McpWeb.Components.Pos.ProductGridTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Components.Pos.ProductGrid

  describe "product_grid/1" do
    test "renders search input with barcode scan button" do
      html =
        render_component(&ProductGrid.product_grid/1, %{
          products: [],
          categories: [],
          selected_category: nil,
          search_query: ""
        })

      assert html =~ ~s(placeholder="Search or scan...")
      assert html =~ ~s(data-testid="product-search")
      assert html =~ ~s(data-testid="barcode-scan-btn")
    end

    test "renders category tabs including 'All' tab" do
      categories = ["Apparel", "Drinkware", "Electronics"]

      html =
        render_component(&ProductGrid.product_grid/1, %{
          products: [],
          categories: categories,
          selected_category: nil,
          search_query: ""
        })

      assert html =~ "All"
      assert html =~ "Apparel"
      assert html =~ "Drinkware"
      assert html =~ "Electronics"
      assert html =~ ~s(tab-active)
    end

    test "renders product tiles with name and price" do
      products = [
        %{
          id: "1",
          name: "Premium Tee",
          price: Decimal.new("29.99"),
          category: "Apparel",
          image_url: nil
        },
        %{
          id: "2",
          name: "Coffee Mug",
          price: Decimal.new("12.00"),
          category: "Drinkware",
          image_url: nil
        }
      ]

      html =
        render_component(&ProductGrid.product_grid/1, %{
          products: products,
          categories: ["Apparel", "Drinkware"],
          selected_category: nil,
          search_query: ""
        })

      assert html =~ "Premium Tee"
      assert html =~ "$29.99"
      assert html =~ "Coffee Mug"
      assert html =~ "$12.00"
      assert html =~ ~s(data-testid="product-tile")
    end

    test "renders custom item button" do
      html =
        render_component(&ProductGrid.product_grid/1, %{
          products: [],
          categories: [],
          selected_category: nil,
          search_query: ""
        })

      assert html =~ ~s(data-testid="custom-item-btn")
      assert html =~ "+ Custom Item"
    end

    test "highlights selected category tab" do
      categories = ["Apparel", "Drinkware"]

      html =
        render_component(&ProductGrid.product_grid/1, %{
          products: [],
          categories: categories,
          selected_category: "Apparel",
          search_query: ""
        })

      # Apparel should have tab-active, All and Drinkware should not
      assert html =~
               ~s(class="tab tab-active" phx-click="select_category" phx-value-category="Apparel")

      assert html =~ ~s(class="tab " phx-click="select_category" phx-value-category="")
      assert html =~ ~s(class="tab " phx-click="select_category" phx-value-category="Drinkware")
    end
  end
end
