defmodule McpWeb.Components.Store.InventoryAdjustModalTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Components.Store.InventoryAdjustModal

  # Build a product map for testing (simple map, no factory needed)
  defp build_product(attrs \\ []) do
    defaults = %{
      id: Ecto.UUID.generate(),
      name: "Test Product",
      quantity_on_hand: 50
    }

    Map.merge(defaults, Map.new(attrs))
  end

  describe "inventory_adjust_modal/1" do
    test "renders modal with product info" do
      product = build_product(name: "Test Product", quantity_on_hand: 50)

      html =
        render_component(&InventoryAdjustModal.inventory_adjust_modal/1, %{
          product: product,
          show: true
        })

      assert html =~ "Test Product"
      assert html =~ "Current: 50"
    end

    test "has adjustment type options" do
      product = build_product()

      html =
        render_component(&InventoryAdjustModal.inventory_adjust_modal/1, %{
          product: product,
          show: true
        })

      assert html =~ "Add"
      assert html =~ "Remove"
      assert html =~ "Set"
    end

    test "has reason dropdown" do
      product = build_product()

      html =
        render_component(&InventoryAdjustModal.inventory_adjust_modal/1, %{
          product: product,
          show: true
        })

      assert html =~ "Reason"
      assert html =~ "Count adjustment"
      assert html =~ "Damaged"
    end

    test "has all reason options" do
      product = build_product()

      html =
        render_component(&InventoryAdjustModal.inventory_adjust_modal/1, %{
          product: product,
          show: true
        })

      assert html =~ "Count adjustment"
      assert html =~ "Damaged"
      assert html =~ "Received shipment"
      assert html =~ "Returned"
      assert html =~ "Other"
    end

    test "has quantity input field" do
      product = build_product()

      html =
        render_component(&InventoryAdjustModal.inventory_adjust_modal/1, %{
          product: product,
          show: true
        })

      assert html =~ "Quantity"
    end

    test "has data-testid attributes for selectors" do
      product = build_product()

      html =
        render_component(&InventoryAdjustModal.inventory_adjust_modal/1, %{
          product: product,
          show: true
        })

      assert html =~ ~s(data-testid="inventory-adjust-modal")
      assert html =~ ~s(data-testid="adjustment-type-add")
      assert html =~ ~s(data-testid="adjustment-type-remove")
      assert html =~ ~s(data-testid="adjustment-type-set")
      assert html =~ ~s(data-testid="reason-select")
      assert html =~ ~s(data-testid="quantity-input")
    end

    test "does not render when show is false" do
      product = build_product()

      html =
        render_component(&InventoryAdjustModal.inventory_adjust_modal/1, %{
          product: product,
          show: false
        })

      refute html =~ "Adjust Inventory"
      refute html =~ "Test Product"
    end

    test "uses DaisyUI modal classes" do
      product = build_product()

      html =
        render_component(&InventoryAdjustModal.inventory_adjust_modal/1, %{
          product: product,
          show: true
        })

      assert html =~ "modal"
      assert html =~ "modal-open"
    end

    test "shows selected adjustment type" do
      product = build_product()

      html =
        render_component(&InventoryAdjustModal.inventory_adjust_modal/1, %{
          product: product,
          show: true,
          adjustment_type: :add
        })

      # The "Add" button should have btn-primary when selected
      # Check that btn-primary is applied to the add button (class comes before data-testid)
      assert html =~ ~r/class="[^"]*btn-primary[^"]*"[^>]*data-testid="adjustment-type-add"/
    end
  end
end
