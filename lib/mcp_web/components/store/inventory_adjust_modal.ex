defmodule McpWeb.Components.Store.InventoryAdjustModal do
  @moduledoc """
  Store Inventory Adjustment Modal Component.

  Provides a modal for store staff to quickly adjust inventory levels.
  Supports three adjustment types (Add, Remove, Set) with configurable
  reasons for tracking inventory changes.

  ## Example

      <.inventory_adjust_modal
        product={@product}
        show={@show_adjust_modal}
        adjustment_type={@adjustment_type}
        on_cancel="close_adjust_modal"
        on_submit="submit_adjustment"
      />
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1, button: 1, input: 1]

  @adjustment_reasons [
    "Count adjustment",
    "Damaged",
    "Received shipment",
    "Returned",
    "Other"
  ]

  @doc """
  Renders an inventory adjustment modal.

  ## Attributes

    * `product` - The product map with :name and :quantity_on_hand fields (required)
    * `show` - Whether to show the modal (default: false)
    * `adjustment_type` - The selected adjustment type: :add, :remove, or :set (default: :add)
    * `on_cancel` - The event name for canceling the modal (default: "close_adjust_modal")
    * `on_submit` - The event name for submitting the adjustment (default: "submit_adjustment")
    * `on_type_change` - The event name for changing the adjustment type (default: "change_adjustment_type")
  """
  attr :product, :map, required: true, doc: "Product with :name and :quantity_on_hand"
  attr :show, :boolean, default: false, doc: "Whether to show the modal"
  attr :adjustment_type, :atom, default: :add, doc: "Selected adjustment type"
  attr :on_cancel, :string, default: "close_adjust_modal"
  attr :on_submit, :string, default: "submit_adjustment"
  attr :on_type_change, :string, default: "change_adjustment_type"

  def inventory_adjust_modal(assigns) do
    assigns = assign(assigns, :reasons, @adjustment_reasons)

    ~H"""
    <%= if @show do %>
      <div class="modal modal-open" data-testid="inventory-adjust-modal">
        <div class="modal-box bg-base-100">
          <%!-- Header --%>
          <div class="flex items-center justify-between mb-4">
            <h3 class="font-bold text-lg">Adjust Inventory</h3>
            <.button
              type="button"
              variant="ghost"
              size="sm"
              class="btn-circle"
              phx-click={@on_cancel}
              data-testid="close-modal-button"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </.button>
          </div>

          <%!-- Product Info --%>
          <div class="mb-6 p-4 bg-base-200 rounded-lg" data-testid="product-info">
            <div class="font-semibold text-base-content">{@product.name}</div>
            <div class="text-sm text-base-content/70">
              Current: {@product.quantity_on_hand}
            </div>
          </div>

          <%!-- Adjustment Type Buttons --%>
          <div class="mb-4">
            <div class="label">
              <span class="label-text font-medium">Adjustment Type</span>
            </div>
            <div class="flex gap-2">
              <.button
                type="button"
                variant={if(@adjustment_type == :add, do: "primary", else: "outline")}
                class="flex-1"
                phx-click={@on_type_change}
                phx-value-type="add"
                data-testid="adjustment-type-add"
              >
                <.icon name="hero-plus" class="size-4 mr-1" /> Add
              </.button>
              <.button
                type="button"
                variant={if(@adjustment_type == :remove, do: "primary", else: "outline")}
                class="flex-1"
                phx-click={@on_type_change}
                phx-value-type="remove"
                data-testid="adjustment-type-remove"
              >
                <.icon name="hero-minus" class="size-4 mr-1" /> Remove
              </.button>
              <.button
                type="button"
                variant={if(@adjustment_type == :set, do: "primary", else: "outline")}
                class="flex-1"
                phx-click={@on_type_change}
                phx-value-type="set"
                data-testid="adjustment-type-set"
              >
                <.icon name="hero-equals" class="size-4 mr-1" /> Set
              </.button>
            </div>
          </div>

          <%!-- Quantity Input --%>
          <div class="mb-4">
            <.input
              type="number"
              name="quantity"
              id="adjustment-quantity"
              label="Quantity"
              min="0"
              data-testid="quantity-input"
            />
          </div>

          <%!-- Reason Dropdown --%>
          <div class="mb-6">
            <.input
              type="select"
              name="reason"
              id="adjustment-reason"
              label="Reason"
              options={@reasons}
              data-testid="reason-select"
            />
          </div>

          <%!-- Action Buttons --%>
          <div class="modal-action">
            <.button variant="ghost" phx-click={@on_cancel} data-testid="cancel-button">
              Cancel
            </.button>
            <.button variant="primary" phx-click={@on_submit} data-testid="submit-button">
              Apply Adjustment
            </.button>
          </div>
        </div>
        <div class="modal-backdrop" phx-click={@on_cancel}>
          <.button type="button" variant="ghost" class="sr-only">close</.button>
        </div>
      </div>
    <% end %>
    """
  end
end
