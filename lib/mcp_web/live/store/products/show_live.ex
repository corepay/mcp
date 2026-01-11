defmodule McpWeb.Store.Products.ShowLive do
  @moduledoc """
  Store Product Detail page - READ-ONLY for store staff.

  Displays product information including:
  - Product info (name, SKU, price, description)
  - Inventory section (stock quantity, low stock warning)
  - Quick actions (Add to POS, Adjust Stock)

  Store staff can view product details and adjust stock levels,
  but cannot edit product information (merchant-only action).

  Uses PageLayout with `:detail` variant for 2/3 + 1/3 split layout.
  """
  use McpWeb, :live_view

  alias Phoenix.LiveView.JS

  import McpWeb.Portal.PageLayout, only: [page_layout: 1]

  import McpWeb.Portal.ActionSidebar,
    only: [action_sidebar: 1, sidebar_action: 1]

  import McpWeb.Core.CoreComponents, only: [icon: 1, card: 1, input: 1, modal: 1, button: 1]
  import McpWeb.Core.DataDisplay, only: [badge: 1]

  @impl true
  def mount(%{"store_slug" => store_slug, "id" => product_id}, _session, socket) do
    product = get_sample_product(product_id)

    socket =
      socket
      |> assign(:page_title, product.name)
      |> assign(:store_slug, store_slug)
      |> assign(:product, product)
      |> assign(:show_adjustment_modal, false)
      |> assign(:adjustment_form, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout
      variant={:detail}
      title={@product.name}
      back={~p"/app/stores/#{@store_slug}/products"}
      data-testid="page-layout-detail"
    >
      <:content>
        <%!-- Product Info Card --%>
        <.card class="mb-6">
          <div class="flex items-start gap-6">
            <%!-- Product Image --%>
            <div class="avatar placeholder">
              <div class="bg-neutral text-neutral-content rounded-lg w-24 h-24">
                <%= if @product.image_url do %>
                  <img src={@product.image_url} alt={@product.name} class="rounded-lg object-cover" />
                <% else %>
                  <.icon name="hero-cube" class="size-10" />
                <% end %>
              </div>
            </div>

            <%!-- Product Info (Read-only) --%>
            <div class="flex-1">
              <div class="flex items-start justify-between mb-4">
                <div>
                  <h2 class="text-2xl font-bold text-base-content" data-testid="product-name">
                    {@product.name}
                  </h2>
                  <p class="text-base-content/60 font-mono text-sm mt-1" data-testid="product-sku">
                    {@product.sku}
                  </p>
                </div>
                <.badge variant={status_variant(@product.status)} size="lg" data-testid="status-badge">
                  {format_status(@product.status)}
                </.badge>
              </div>

              <p class="text-lg font-semibold text-primary mb-3" data-testid="product-price">
                {format_price(@product.price)}
              </p>

              <p class="text-base-content/80" data-testid="product-description">
                {@product.description || "No description"}
              </p>
            </div>
          </div>
        </.card>

        <%!-- Inventory Section (conditional) --%>
        <.card :if={@product.track_inventory} class="mb-6" data-testid="inventory-section">
          <h3 class="text-lg font-semibold mb-4">Inventory</h3>
          <div class="grid grid-cols-2 gap-4">
            <div class="stat bg-base-200 rounded-box p-4">
              <div class="stat-title">Stock Quantity</div>
              <div
                class={[
                  "stat-value text-2xl",
                  @product.quantity_on_hand < @product.low_stock_threshold && "text-error"
                ]}
                data-testid="stock-quantity"
              >
                {@product.quantity_on_hand}
              </div>
              <div
                :if={@product.quantity_on_hand < @product.low_stock_threshold}
                class="stat-desc text-error"
              >
                Low stock
              </div>
            </div>
            <div class="stat bg-base-200 rounded-box p-4">
              <div class="stat-title">Low Stock Threshold</div>
              <div class="stat-value text-2xl" data-testid="low-stock-threshold">
                {@product.low_stock_threshold}
              </div>
            </div>
          </div>
        </.card>

        <%!-- Stock Adjustment Modal --%>
        <.modal
          id="adjustment-modal"
          show={@show_adjustment_modal}
          on_cancel={hide_modal("adjustment-modal")}
          data-testid="adjustment-modal"
        >
          <:title>Adjust Stock</:title>
          <.form
            for={@adjustment_form}
            id="adjustment-form"
            phx-submit="save_adjustment"
            class="space-y-4"
          >
            <.input
              field={@adjustment_form[:adjustment_type]}
              label="Adjustment Type"
              type="select"
              options={["add", "remove", "set"]}
            />
            <.input
              field={@adjustment_form[:quantity]}
              label="Quantity"
              type="number"
              min="0"
              placeholder="0"
              required
            />
            <.input
              field={@adjustment_form[:reason]}
              label="Reason"
              placeholder="e.g., Received shipment, Inventory count"
            />
            <div class="modal-action">
              <.button variant="ghost" phx-click={hide_modal("adjustment-modal")}>
                Cancel
              </.button>
              <.button type="submit" variant="primary" phx-disable-with="Adjusting...">
                Adjust Stock
              </.button>
            </div>
          </.form>
        </.modal>
      </:content>

      <:sidebar>
        <.action_sidebar data-testid="action-sidebar">
          <:actions>
            <%!-- Quick Actions for Store Staff --%>
            <.sidebar_action
              icon="hero-shopping-cart"
              label="Add to POS"
              phx-click="add_to_pos"
              data-testid="add-to-cart-btn"
            />
            <.sidebar_action
              :if={@product.track_inventory}
              icon="hero-adjustments-vertical"
              label="Adjust Stock"
              phx-click="show_adjust_stock"
              data-testid="adjust-stock-btn"
            />
          </:actions>

          <:insights>
            <div class="text-center text-sm text-base-content/50 py-4">
              AI insights coming in Phase 5
            </div>
          </:insights>
        </.action_sidebar>
      </:sidebar>
    </.page_layout>
    """
  end

  # Event handlers

  @impl true
  def handle_event("add_to_pos", _params, socket) do
    # Placeholder for POS integration - will be implemented in later phase
    {:noreply, put_flash(socket, :info, "Added to POS")}
  end

  @impl true
  def handle_event("show_adjust_stock", _params, socket) do
    form =
      to_form(
        %{
          "adjustment_type" => "add",
          "quantity" => "",
          "reason" => ""
        },
        as: :adjustment
      )

    socket =
      socket
      |> assign(:show_adjustment_modal, true)
      |> assign(:adjustment_form, form)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_adjustment", %{"adjustment" => params}, socket) do
    product = socket.assigns.product
    quantity = String.to_integer(params["quantity"] || "0")

    new_quantity =
      case params["adjustment_type"] do
        "add" -> product.quantity_on_hand + quantity
        "remove" -> max(0, product.quantity_on_hand - quantity)
        "set" -> quantity
        _ -> product.quantity_on_hand
      end

    updated_product = %{product | quantity_on_hand: new_quantity}

    socket =
      socket
      |> assign(:product, updated_product)
      |> assign(:show_adjustment_modal, false)
      |> assign(:adjustment_form, nil)
      |> put_flash(:info, "Stock adjusted successfully")

    {:noreply, socket}
  end

  # Private helper functions

  defp get_sample_product(id) do
    products = [
      %{
        id: "1",
        name: "Premium Tee",
        sku: "TEE-001",
        description: "High-quality premium t-shirt",
        price: Money.new(:USD, "29.99"),
        status: :active,
        track_inventory: true,
        quantity_on_hand: 50,
        low_stock_threshold: 10,
        image_url: nil
      },
      %{
        id: "2",
        name: "Coffee Mug",
        sku: "MUG-001",
        description: "Ceramic coffee mug with logo",
        price: Money.new(:USD, "14.99"),
        status: :active,
        track_inventory: true,
        quantity_on_hand: 3,
        low_stock_threshold: 10,
        image_url: nil
      }
    ]

    Enum.find(products, hd(products), fn p -> p.id == id end)
  end

  defp format_price(%Money{} = money), do: Money.to_string!(money)
  defp format_price(_), do: "-"

  defp format_status(:active), do: "Active"
  defp format_status(:draft), do: "Draft"
  defp format_status(:archived), do: "Archived"

  defp status_variant(:active), do: "success"
  defp status_variant(:draft), do: "warning"
  defp status_variant(:archived), do: "ghost"
  defp status_variant(_), do: nil

  defp hide_modal(id) do
    JS.remove_class("modal-open", to: "##{id}")
  end
end
