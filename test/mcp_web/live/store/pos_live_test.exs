defmodule McpWeb.Store.PosLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  @moduletag :skip

  describe "POS LiveView" do
    test "renders POS interface with focused layout", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/test-store/pos")

      # Uses focused layout
      assert html =~ "Point of Sale"
      # Has product grid
      assert html =~ ~s(data-testid="product-search")
      # Has cart
      assert html =~ "CART"
    end

    test "displays sample products", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/test-store/pos")

      # Should have product tiles
      assert html =~ ~s(data-testid="product-tile")
      # Sample products
      assert html =~ "Premium Tee" or html =~ "Coffee Mug"
    end

    test "displays category tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/test-store/pos")

      assert html =~ "All"
      assert html =~ ~s(tab-active)
    end

    test "cart starts empty", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/test-store/pos")

      assert html =~ ~s(data-testid="empty-cart")
      assert html =~ "Cart is empty"
    end

    test "pay button is disabled when cart empty", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/app/stores/test-store/pos")

      assert html =~ ~s(data-testid="pay-btn")
      assert html =~ "disabled"
    end
  end
end
