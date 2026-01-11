defmodule McpWeb.Merchant.Products.ShowLive do
  @moduledoc """
  Merchant Product Detail page.

  Displays comprehensive product information including:
  - Product info card (name, SKU, price, description)
  - Inventory section (when tracking enabled)
  - Variants list with add/edit capability
  - Activity log placeholder
  - Quick actions (Duplicate, Export, Archive)
  - AI insights placeholder

  Uses PageLayout with `:detail` variant for 2/3 + 1/3 split layout.
  """
  use McpWeb, :live_view

  alias Phoenix.LiveView.JS

  import McpWeb.Portal.PageLayout, only: [page_layout: 1]
  import McpWeb.Portal.DataTable, only: [data_table: 1]

  import McpWeb.Portal.ActionSidebar,
    only: [action_sidebar: 1, sidebar_action: 1]

  import McpWeb.Core.CoreComponents, only: [icon: 1, card: 1, input: 1, modal: 1, button: 1]
  import McpWeb.Core.DataDisplay, only: [badge: 1]

  @impl true
  def mount(%{"id" => product_id}, _session, socket) do
    product = find_product(product_id)
    variants = get_product_variants(product_id)
    activities = get_product_activities(product_id)

    socket =
      socket
      |> assign(:page_title, product.name)
      |> assign(:product, product)
      |> assign(:variants, variants)
      |> assign(:activities, activities)
      |> assign(:editing, false)
      |> assign(:edit_form, nil)
      |> assign(:show_variant_modal, false)
      |> assign(:variant_form, nil)
      |> assign(:show_archive_modal, false)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout
      variant={:detail}
      title={@product.name}
      back={~p"/app/products"}
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

            <%!-- Product Info --%>
            <div class="flex-1">
              <%= if @editing do %>
                <.product_edit_form form={@edit_form} />
              <% else %>
                <.product_info product={@product} />
              <% end %>
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

        <%!-- Variants Section --%>
        <.card class="mb-6" data-testid="variants-section">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-semibold">Variants</h3>
            <.button
              variant="primary"
              size="sm"
              phx-click="show_add_variant"
              data-testid="add-variant-btn"
            >
              <.icon name="hero-plus" class="size-4" /> Add Variant
            </.button>
          </div>

          <.data_table id="variants-table" rows={@variants} row_testid="variant-row">
            <:col :let={variant} label="Name" field={:name}>
              <span class="font-medium">{variant.name}</span>
            </:col>
            <:col :let={variant} label="SKU" field={:sku}>
              <span class="font-mono text-sm">{variant.sku}</span>
            </:col>
            <:col :let={variant} label="Price" field={:price} align={:right}>
              <span class="font-semibold">{format_price(variant.price)}</span>
            </:col>
            <:col :let={variant} label="Stock" field={:quantity_on_hand} align={:right}>
              {variant.quantity_on_hand}
            </:col>
            <:empty>
              <div class="text-center py-8 text-base-content/60">
                <.icon name="hero-squares-2x2" class="size-8 mb-2 mx-auto" />
                <p>No variants yet</p>
              </div>
            </:empty>
          </.data_table>
        </.card>

        <%!-- Activity Log --%>
        <.card data-testid="activity-log">
          <h3 class="text-lg font-semibold mb-4">Recent Activity</h3>
          <div class="space-y-3">
            <div
              :for={activity <- @activities}
              class="flex items-start gap-3 p-3 bg-base-200 rounded-lg"
            >
              <div class="avatar placeholder">
                <div class="bg-neutral text-neutral-content rounded-full w-8 h-8">
                  <.icon name={activity.icon} class="size-4" />
                </div>
              </div>
              <div class="flex-1">
                <p class="text-sm">{activity.message}</p>
                <p class="text-xs text-base-content/60">{format_activity_time(activity.timestamp)}</p>
              </div>
            </div>
            <div :if={@activities == []} class="text-center py-4 text-base-content/60">
              No recent activity
            </div>
          </div>
        </.card>

        <%!-- Variant Modal --%>
        <.modal id="variant-modal" show={@show_variant_modal} on_cancel={hide_modal("variant-modal")}>
          <:title>Add Variant</:title>
          <.form
            for={@variant_form}
            id="variant-form"
            phx-submit="save_variant"
            class="space-y-4"
          >
            <.input
              field={@variant_form[:name]}
              label="Name"
              placeholder="e.g., Large / Red"
              required
            />
            <.input field={@variant_form[:sku]} label="SKU" placeholder="VAR-SKU-001" required />
            <.input
              field={@variant_form[:price]}
              label="Price"
              type="number"
              step="0.01"
              placeholder="0.00"
            />
            <.input
              field={@variant_form[:quantity_on_hand]}
              label="Stock Quantity"
              type="number"
              placeholder="0"
            />
            <div class="modal-action">
              <.button variant="ghost" phx-click={hide_modal("variant-modal")}>
                Cancel
              </.button>
              <.button type="submit" variant="primary" phx-disable-with="Adding...">
                Add Variant
              </.button>
            </div>
          </.form>
        </.modal>

        <%!-- Archive Confirmation Modal --%>
        <.modal id="archive-modal" show={@show_archive_modal} on_cancel={hide_modal("archive-modal")}>
          <:title>Archive Product</:title>
          <p class="py-4">
            Are you sure you want to archive <strong>{@product.name}</strong>?
            Archived products will no longer appear in your store.
          </p>
          <div class="modal-action">
            <.button variant="ghost" phx-click={hide_modal("archive-modal")}>
              Cancel
            </.button>
            <.button
              variant="warning"
              phx-click="confirm_archive"
              data-testid="confirm-archive"
              phx-disable-with="Archiving..."
            >
              Archive Product
            </.button>
          </div>
        </.modal>
      </:content>

      <:sidebar>
        <.action_sidebar data-testid="action-sidebar">
          <:actions>
            <.sidebar_action
              :if={not @editing}
              icon="hero-pencil"
              label="Edit Product"
              phx-click="edit_product"
              data-testid="edit-btn"
            />
            <.sidebar_action
              icon="hero-document-duplicate"
              label="Duplicate"
              phx-click="duplicate_product"
              data-testid="duplicate-btn"
            />
            <.sidebar_action icon="hero-arrow-down-tray" label="Export" phx-click="export_product" />
            <%= if @product.status == :archived do %>
              <.sidebar_action
                icon="hero-arrow-path"
                label="Restore"
                phx-click="restore_product"
                data-testid="restore-btn"
              />
            <% else %>
              <.sidebar_action
                icon="hero-archive-box"
                label="Archive"
                phx-click="archive_product"
                data-testid="archive-btn"
              />
            <% end %>
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

  # Product info component (view mode)
  defp product_info(assigns) do
    ~H"""
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
    """
  end

  # Product edit form component
  defp product_edit_form(assigns) do
    ~H"""
    <.form for={@form} id="product-edit-form" phx-submit="save_product" data-testid="edit-form">
      <div class="space-y-4">
        <.input field={@form[:name]} label="Name" required />
        <.input field={@form[:sku]} label="SKU" required />
        <.input field={@form[:description]} label="Description" type="textarea" />
        <.input field={@form[:price]} label="Price" type="number" step="0.01" />
        <div class="flex gap-2 justify-end pt-4">
          <.button variant="ghost" phx-click="cancel_edit">
            Cancel
          </.button>
          <.button type="submit" variant="primary" phx-disable-with="Saving...">
            Save Changes
          </.button>
        </div>
      </div>
    </.form>
    """
  end

  # Event handlers

  @impl true
  def handle_event("edit_product", _params, socket) do
    product = socket.assigns.product

    form =
      to_form(
        %{
          "name" => product.name,
          "sku" => product.sku,
          "description" => product.description || "",
          "price" => format_price_for_input(product.price)
        },
        as: :product
      )

    {:noreply, assign(socket, editing: true, edit_form: form)}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing: false, edit_form: nil)}
  end

  @impl true
  def handle_event("save_product", %{"product" => params}, socket) do
    if valid_product_params?(params) do
      product = socket.assigns.product

      updated_product =
        product
        |> Map.put(:name, params["name"])
        |> Map.put(:description, params["description"])

      socket =
        socket
        |> assign(:product, updated_product)
        |> assign(:page_title, updated_product.name)
        |> assign(:editing, false)
        |> assign(:edit_form, nil)
        |> put_flash(:info, "Product updated successfully")

      {:noreply, socket}
    else
      # Show validation errors
      form = to_form(params, as: :product, errors: [name: {"is required", []}])
      {:noreply, assign(socket, edit_form: form)}
    end
  end

  @impl true
  def handle_event("show_add_variant", _params, socket) do
    form =
      to_form(
        %{
          "name" => "",
          "sku" => "",
          "price" => "",
          "quantity_on_hand" => "0"
        },
        as: :variant
      )

    socket =
      socket
      |> assign(:show_variant_modal, true)
      |> assign(:variant_form, form)
      |> push_event("js-exec", %{to: "#variant-modal", attr: "class", val: "modal modal-open"})

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_variant", %{"variant" => params}, socket) do
    new_variant = %{
      id: "var_#{System.unique_integer([:positive])}",
      name: params["name"],
      sku: params["sku"],
      price: parse_price(params["price"]),
      quantity_on_hand: String.to_integer(params["quantity_on_hand"] || "0"),
      option_values: %{}
    }

    variants = socket.assigns.variants ++ [new_variant]

    socket =
      socket
      |> assign(:variants, variants)
      |> assign(:show_variant_modal, false)
      |> assign(:variant_form, nil)
      |> put_flash(:info, "Variant added successfully")

    {:noreply, socket}
  end

  @impl true
  def handle_event("duplicate_product", _params, socket) do
    # In a real implementation, this would create a copy of the product
    # and redirect to the new product page
    _product = socket.assigns.product

    # Create a copy with new ID
    new_id = "#{System.unique_integer([:positive])}"

    {:noreply, push_navigate(socket, to: ~p"/app/products/#{new_id}")}
  end

  @impl true
  def handle_event("export_product", _params, socket) do
    # Placeholder for export functionality
    {:noreply, put_flash(socket, :info, "Export feature coming soon")}
  end

  @impl true
  def handle_event("archive_product", _params, socket) do
    {:noreply, assign(socket, :show_archive_modal, true)}
  end

  @impl true
  def handle_event("confirm_archive", _params, socket) do
    product = Map.put(socket.assigns.product, :status, :archived)

    socket =
      socket
      |> assign(:product, product)
      |> assign(:show_archive_modal, false)
      |> put_flash(:info, "Product archived successfully")

    {:noreply, socket}
  end

  @impl true
  def handle_event("restore_product", _params, socket) do
    product = Map.put(socket.assigns.product, :status, :active)

    socket =
      socket
      |> assign(:product, product)
      |> put_flash(:info, "Product restored successfully")

    {:noreply, socket}
  end

  # Private helper functions

  defp find_product(id) do
    # Mock product data - replace with Ash resource query
    products = get_sample_products()
    Enum.find(products, hd(products), fn p -> p.id == id end)
  end

  defp get_product_variants(product_id) do
    # Mock variants data - replace with Ash resource query
    case product_id do
      "1" ->
        [
          %{
            id: "var_1",
            name: "Small / Blue",
            sku: "SKU-WP-001-SB",
            price: Money.new(:USD, "49.99"),
            quantity_on_hand: 25,
            option_values: %{"size" => "small", "color" => "blue"}
          },
          %{
            id: "var_2",
            name: "Medium / Blue",
            sku: "SKU-WP-001-MB",
            price: Money.new(:USD, "49.99"),
            quantity_on_hand: 30,
            option_values: %{"size" => "medium", "color" => "blue"}
          }
        ]

      _ ->
        []
    end
  end

  defp get_product_activities(_product_id) do
    # Mock activity data - replace with actual activity log
    [
      %{
        icon: "hero-pencil",
        message: "Product details updated",
        timestamp: ~U[2026-01-10 14:30:00Z]
      },
      %{
        icon: "hero-plus",
        message: "Product created",
        timestamp: ~U[2026-01-05 09:00:00Z]
      }
    ]
  end

  defp get_sample_products do
    [
      %{
        id: "1",
        name: "Widget Pro",
        sku: "SKU-WP-001",
        description: "Professional grade widget for demanding applications",
        price: Money.new(:USD, "49.99"),
        status: :active,
        track_inventory: true,
        quantity_on_hand: 125,
        low_stock_threshold: 10,
        image_url: nil
      },
      %{
        id: "2",
        name: "Gadget Basic",
        sku: "SKU-GB-002",
        description: "Entry-level gadget for beginners",
        price: Money.new(:USD, "19.99"),
        status: :active,
        track_inventory: true,
        quantity_on_hand: 8,
        low_stock_threshold: 10,
        image_url: nil
      },
      %{
        id: "3",
        name: "Premium Cable",
        sku: "SKU-PC-003",
        description: "High-quality braided cable",
        price: Money.new(:USD, "12.99"),
        status: :active,
        track_inventory: false,
        quantity_on_hand: 250,
        low_stock_threshold: 20,
        image_url: nil
      }
    ]
  end

  defp format_price(%Money{} = money), do: Money.to_string!(money)
  defp format_price(_), do: "-"

  defp format_price_for_input(%Money{} = money) do
    money
    |> Money.to_decimal()
    |> Decimal.to_string(:normal)
  end

  defp format_price_for_input(_), do: ""

  defp parse_price(""), do: nil

  defp parse_price(price_string) when is_binary(price_string) do
    case Decimal.parse(price_string) do
      {decimal, _} -> Money.new(:USD, decimal)
      :error -> nil
    end
  end

  defp parse_price(_), do: nil

  defp valid_product_params?(params) do
    name = params["name"] || ""
    String.trim(name) != ""
  end

  defp format_status(:active), do: "Active"
  defp format_status(:draft), do: "Draft"
  defp format_status(:archived), do: "Archived"

  defp status_variant(:active), do: "success"
  defp status_variant(:draft), do: "warning"
  defp status_variant(:archived), do: "ghost"
  defp status_variant(_), do: nil

  defp format_activity_time(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  defp hide_modal(id) do
    JS.remove_class("modal-open", to: "##{id}")
  end
end
