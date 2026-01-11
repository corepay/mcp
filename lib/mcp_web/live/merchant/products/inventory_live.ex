defmodule McpWeb.Merchant.Products.InventoryLive do
  @moduledoc """
  Merchant Inventory overview page - displays inventory table with stats, filters, and adjustment modals.

  Uses PageLayout with table variant for full-width data-focused view.
  Supports filtering by stock status, single product adjustments, and bulk adjustments.
  """
  use McpWeb, :live_view

  alias Phoenix.LiveView.JS

  import McpWeb.Portal.PageLayout, only: [page_layout: 1]
  import McpWeb.Portal.StatsRow, only: [stats_row: 1, stat: 1]
  import McpWeb.Portal.DataTable, only: [data_table: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1, modal: 1, button: 1, input: 1]

  @impl true
  def mount(_params, _session, socket) do
    inventory = get_sample_inventory()
    stats = calculate_stats(inventory)

    socket =
      socket
      |> assign(:page_title, "Inventory")
      |> assign(:inventory, inventory)
      |> assign(:filtered_inventory, inventory)
      |> assign(:stats, stats)
      |> assign(:filter, "all")
      |> assign(:selected_ids, MapSet.new())
      |> assign(:show_adjustment_modal, false)
      |> assign(:show_bulk_adjustment_modal, false)
      |> assign(:adjusting_product, nil)
      |> assign(:adjustment_form, nil)
      |> assign(:bulk_adjustment_form, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout variant={:table} title="Inventory" data-testid="page-layout-table">
      <:stats>
        <.stats_row>
          <.stat
            label="Total Items"
            value={@stats.total_items}
            icon="hero-archive-box"
            data-testid="stat-total-items"
          />
          <.stat
            label="Low Stock"
            value={@stats.low_stock_count}
            icon="hero-exclamation-triangle"
            data-testid="stat-low-stock"
          />
          <.stat
            label="Out of Stock"
            value={@stats.out_of_stock_count}
            icon="hero-x-circle"
            data-testid="stat-out-of-stock"
          />
          <.stat
            label="Total Value"
            value={@stats.total_value}
            icon="hero-currency-dollar"
            data-testid="stat-total-value"
          />
        </.stats_row>
      </:stats>

      <:toolbar>
        <div class="flex items-center gap-2">
          <.filter_button
            label="All"
            active={@filter == "all"}
            phx-click="filter"
            phx-value-filter="all"
            data-testid="filter-all"
          />
          <.filter_button
            label="Low Stock"
            active={@filter == "low_stock"}
            phx-click="filter"
            phx-value-filter="low_stock"
            data-testid="filter-low-stock"
          />
          <.filter_button
            label="Out of Stock"
            active={@filter == "out_of_stock"}
            phx-click="filter"
            phx-value-filter="out_of_stock"
            data-testid="filter-out-of-stock"
          />
        </div>
        <div class="flex items-center gap-2">
          <.button
            :if={MapSet.size(@selected_ids) > 0}
            variant="secondary"
            phx-click="open_bulk_adjustment"
            data-testid="bulk-adjust-btn"
          >
            <.icon name="hero-adjustments-horizontal" class="size-4" />
            Bulk Adjust ({MapSet.size(@selected_ids)})
          </.button>
          <.button variant="ghost" phx-click="export" data-testid="export-btn">
            <.icon name="hero-arrow-down-tray" class="size-4" /> Export
          </.button>
        </div>
      </:toolbar>

      <:content>
        <div class="card bg-base-100 shadow-sm" data-testid="data-table">
          <div class="card-body p-0">
            <.data_table
              id="inventory-table"
              rows={@filtered_inventory}
              selectable
              row_testid="product-row"
            >
              <:col :let={product} label="Product" field={:name}>
                <div class="flex items-center gap-3">
                  <div class="avatar placeholder">
                    <div class="bg-neutral text-neutral-content rounded w-10">
                      <%= if product.image_url do %>
                        <img src={product.image_url} alt={product.name} class="rounded" />
                      <% else %>
                        <.icon name="hero-cube" class="size-5" />
                      <% end %>
                    </div>
                  </div>
                  <div>
                    <p class="font-medium">{product.name}</p>
                    <p class="text-sm text-base-content/60">{product.sku}</p>
                  </div>
                </div>
              </:col>

              <:col :let={product} label="Price" field={:price} align={:right}>
                <span class="font-semibold">{format_price(product.price)}</span>
              </:col>

              <:col :let={product} label="Cost" field={:cost} align={:right}>
                <span class="text-base-content/70">{format_price(product.cost)}</span>
              </:col>

              <:col :let={product} label="Quantity" field={:quantity} align={:right}>
                <div class="flex items-center justify-end gap-2">
                  <span
                    class={[
                      "font-semibold",
                      quantity_color(product)
                    ]}
                    data-testid={"quantity-#{product.id}"}
                  >
                    {product.quantity_on_hand}
                  </span>
                  <.stock_badge product={product} />
                </div>
              </:col>

              <:col :let={product} label="Threshold" field={:threshold} align={:right}>
                <span class="text-base-content/60">{product.low_stock_threshold}</span>
              </:col>

              <:action :let={product}>
                <.button
                  variant="ghost"
                  size="sm"
                  phx-click="open_adjustment"
                  phx-value-id={product.id}
                  data-testid={"adjust-#{product.id}"}
                >
                  <.icon name="hero-pencil-square" class="size-4" /> Adjust
                </.button>
              </:action>

              <:empty>
                <div class="flex flex-col items-center justify-center py-12 text-base-content/60">
                  <.icon name="hero-archive-box" class="size-12 mb-2" />
                  <p>No inventory items found</p>
                </div>
              </:empty>
            </.data_table>
          </div>
        </div>
      </:content>
    </.page_layout>

    <%!-- Stock Adjustment Modal (Single Product) --%>
    <.modal
      id="adjustment-modal"
      show={@show_adjustment_modal}
      on_cancel={hide_modal("adjustment-modal")}
      data-testid="adjustment-modal"
    >
      <:title>
        Adjust Stock - {(@adjusting_product && @adjusting_product.name) || "Product"}
      </:title>
      <.form
        :if={@adjustment_form}
        for={@adjustment_form}
        id="adjustment-form"
        phx-submit="adjust_stock"
        class="space-y-4"
      >
        <input
          type="hidden"
          name="adjustment[product_id]"
          value={(@adjusting_product && @adjusting_product.id) || ""}
        />

        <div class="form-control">
          <label class="label">
            <span class="label-text">Adjustment Type</span>
          </label>
          <select name="adjustment[type]" class="select select-bordered w-full" required>
            <option value="add">Add Stock</option>
            <option value="remove">Remove Stock</option>
            <option value="set">Set Quantity</option>
          </select>
        </div>

        <.input
          field={@adjustment_form[:quantity]}
          label="Quantity"
          type="number"
          min="0"
          required
        />

        <.input
          field={@adjustment_form[:reason]}
          label="Reason"
          placeholder="e.g., Restock, Damage, Inventory count"
        />

        <div class="modal-action">
          <.button variant="ghost" type="button" phx-click={hide_modal("adjustment-modal")}>
            Cancel
          </.button>
          <.button type="submit" variant="primary" phx-disable-with="Adjusting...">
            Apply Adjustment
          </.button>
        </div>
      </.form>
    </.modal>

    <%!-- Bulk Adjustment Modal --%>
    <.modal
      id="bulk-adjustment-modal"
      show={@show_bulk_adjustment_modal}
      on_cancel={hide_modal("bulk-adjustment-modal")}
      data-testid="bulk-adjustment-modal"
    >
      <:title>
        Bulk Adjust Stock ({MapSet.size(@selected_ids)} items)
      </:title>
      <.form
        :if={@bulk_adjustment_form}
        for={@bulk_adjustment_form}
        id="bulk-adjustment-form"
        phx-submit="bulk_adjust_stock"
        class="space-y-4"
      >
        <div class="form-control">
          <label class="label">
            <span class="label-text">Adjustment Type</span>
          </label>
          <select name="bulk_adjustment[type]" class="select select-bordered w-full" required>
            <option value="add">Add Stock</option>
            <option value="remove">Remove Stock</option>
          </select>
        </div>

        <.input
          field={@bulk_adjustment_form[:quantity]}
          label="Quantity"
          type="number"
          min="0"
          required
        />

        <.input
          field={@bulk_adjustment_form[:reason]}
          label="Reason"
          placeholder="e.g., Bulk restock, Inventory audit"
        />

        <div class="modal-action">
          <.button variant="ghost" type="button" phx-click={hide_modal("bulk-adjustment-modal")}>
            Cancel
          </.button>
          <.button type="submit" variant="primary" phx-disable-with="Adjusting...">
            Apply to All
          </.button>
        </div>
      </.form>
    </.modal>
    """
  end

  # Filter button component
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :rest, :global

  defp filter_button(assigns) do
    ~H"""
    <.button
      type="button"
      variant={if @active, do: "primary", else: "ghost"}
      size="sm"
      {@rest}
    >
      {@label}
    </.button>
    """
  end

  # Stock badge component
  attr :product, :map, required: true

  defp stock_badge(assigns) do
    ~H"""
    <%= cond do %>
      <% @product.quantity_on_hand == 0 -> %>
        <span class="badge badge-error badge-sm">Out</span>
      <% @product.is_low_stock -> %>
        <span class="badge badge-warning badge-sm">Low</span>
      <% true -> %>
        <span></span>
    <% end %>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    filtered = filter_inventory(socket.assigns.inventory, filter)

    socket =
      socket
      |> assign(:filter, filter)
      |> assign(:filtered_inventory, filtered)
      |> assign(:selected_ids, MapSet.new())

    {:noreply, socket}
  end

  @impl true
  def handle_event("select-all", _params, socket) do
    current_selected = socket.assigns.selected_ids
    all_ids = Enum.map(socket.assigns.filtered_inventory, & &1.id) |> MapSet.new()

    new_selected =
      if MapSet.size(current_selected) == MapSet.size(all_ids) do
        MapSet.new()
      else
        all_ids
      end

    {:noreply, assign(socket, :selected_ids, new_selected)}
  end

  @impl true
  def handle_event("select-row", %{"id" => row_id}, socket) do
    # Extract actual ID from "row-{id}" format
    product_id = String.replace_prefix(row_id, "row-", "")

    new_selected =
      if MapSet.member?(socket.assigns.selected_ids, product_id) do
        MapSet.delete(socket.assigns.selected_ids, product_id)
      else
        MapSet.put(socket.assigns.selected_ids, product_id)
      end

    {:noreply, assign(socket, :selected_ids, new_selected)}
  end

  @impl true
  def handle_event("open_adjustment", %{"id" => product_id}, socket) do
    product = Enum.find(socket.assigns.inventory, &(&1.id == product_id))
    form = to_form(%{"quantity" => "", "reason" => ""}, as: :adjustment)

    socket =
      socket
      |> assign(:show_adjustment_modal, true)
      |> assign(:adjusting_product, product)
      |> assign(:adjustment_form, form)

    {:noreply, socket}
  end

  @impl true
  def handle_event("adjust_stock", %{"adjustment" => params}, socket) do
    product_id = params["product_id"]
    adjustment_type = params["type"]
    quantity = String.to_integer(params["quantity"])
    _reason = params["reason"]

    updated_inventory =
      update_product_quantity(socket.assigns.inventory, product_id, adjustment_type, quantity)

    stats = calculate_stats(updated_inventory)
    filtered = filter_inventory(updated_inventory, socket.assigns.filter)

    socket =
      socket
      |> assign(:inventory, updated_inventory)
      |> assign(:filtered_inventory, filtered)
      |> assign(:stats, stats)
      |> assign(:show_adjustment_modal, false)
      |> assign(:adjusting_product, nil)
      |> assign(:adjustment_form, nil)
      |> put_flash(:info, "Stock adjusted successfully")

    {:noreply, socket}
  end

  @impl true
  def handle_event("open_bulk_adjustment", _params, socket) do
    form = to_form(%{"quantity" => "", "reason" => ""}, as: :bulk_adjustment)

    socket =
      socket
      |> assign(:show_bulk_adjustment_modal, true)
      |> assign(:bulk_adjustment_form, form)

    {:noreply, socket}
  end

  @impl true
  def handle_event("bulk_adjust_stock", %{"bulk_adjustment" => params}, socket) do
    selected_ids = socket.assigns.selected_ids
    adjustment_type = params["type"]
    quantity = String.to_integer(params["quantity"])
    _reason = params["reason"]

    updated_inventory =
      bulk_update_quantities(socket.assigns.inventory, selected_ids, adjustment_type, quantity)

    stats = calculate_stats(updated_inventory)
    filtered = filter_inventory(updated_inventory, socket.assigns.filter)

    socket =
      socket
      |> assign(:inventory, updated_inventory)
      |> assign(:filtered_inventory, filtered)
      |> assign(:stats, stats)
      |> assign(:show_bulk_adjustment_modal, false)
      |> assign(:bulk_adjustment_form, nil)
      |> assign(:selected_ids, MapSet.new())
      |> put_flash(:info, "Bulk adjustment applied to #{MapSet.size(selected_ids)} items")

    {:noreply, socket}
  end

  @impl true
  def handle_event("export", _params, socket) do
    # Placeholder for export functionality
    {:noreply, put_flash(socket, :info, "Export functionality coming soon")}
  end

  # Private helper functions

  defp hide_modal(id) do
    JS.remove_class("modal-open", to: "##{id}")
  end

  defp update_product_quantity(inventory, product_id, adjustment_type, quantity) do
    Enum.map(inventory, fn product ->
      if product.id == product_id do
        new_quantity = calculate_new_quantity(product, adjustment_type, quantity)
        update_product_with_quantity(product, new_quantity)
      else
        product
      end
    end)
  end

  defp bulk_update_quantities(inventory, selected_ids, adjustment_type, quantity) do
    Enum.map(inventory, fn product ->
      if MapSet.member?(selected_ids, product.id) do
        new_quantity = calculate_new_quantity(product, adjustment_type, quantity)
        update_product_with_quantity(product, new_quantity)
      else
        product
      end
    end)
  end

  defp calculate_new_quantity(product, "add", quantity), do: product.quantity_on_hand + quantity

  defp calculate_new_quantity(product, "remove", quantity),
    do: max(0, product.quantity_on_hand - quantity)

  defp calculate_new_quantity(_product, "set", quantity), do: quantity

  defp update_product_with_quantity(product, new_quantity) do
    is_low = new_quantity < product.low_stock_threshold and new_quantity > 0
    %{product | quantity_on_hand: new_quantity, is_low_stock: is_low}
  end

  defp get_sample_inventory do
    [
      %{
        id: "1",
        name: "Widget Pro",
        sku: "SKU-WP-001",
        image_url: nil,
        price: Money.new(:USD, "49.99"),
        cost: Money.new(:USD, "25.00"),
        quantity_on_hand: 125,
        low_stock_threshold: 10,
        is_low_stock: false,
        track_inventory: true
      },
      %{
        id: "2",
        name: "Gadget Basic",
        sku: "SKU-GB-002",
        image_url: nil,
        price: Money.new(:USD, "19.99"),
        cost: Money.new(:USD, "10.00"),
        quantity_on_hand: 5,
        low_stock_threshold: 10,
        is_low_stock: true,
        track_inventory: true
      },
      %{
        id: "3",
        name: "Smart Sensor",
        sku: "SKU-SS-003",
        image_url: nil,
        price: Money.new(:USD, "89.99"),
        cost: nil,
        quantity_on_hand: 0,
        low_stock_threshold: 5,
        is_low_stock: false,
        track_inventory: true
      }
    ]
  end

  defp calculate_stats(inventory) do
    total_items = length(inventory)

    low_stock_count =
      Enum.count(inventory, fn p ->
        p.track_inventory and p.quantity_on_hand > 0 and
          p.quantity_on_hand < p.low_stock_threshold
      end)

    out_of_stock_count =
      Enum.count(inventory, fn p -> p.track_inventory and p.quantity_on_hand == 0 end)

    total_value =
      inventory
      |> Enum.filter(fn p -> p.cost != nil end)
      |> Enum.reduce(Money.new(:USD, 0), fn product, acc ->
        item_value = Money.mult!(product.cost, product.quantity_on_hand)
        Money.add!(acc, item_value)
      end)

    %{
      total_items: to_string(total_items),
      low_stock_count: to_string(low_stock_count),
      out_of_stock_count: to_string(out_of_stock_count),
      total_value: Money.to_string!(total_value)
    }
  end

  defp filter_inventory(inventory, "all"), do: inventory

  defp filter_inventory(inventory, "low_stock") do
    Enum.filter(inventory, fn p ->
      p.track_inventory and p.quantity_on_hand > 0 and
        p.quantity_on_hand < p.low_stock_threshold
    end)
  end

  defp filter_inventory(inventory, "out_of_stock") do
    Enum.filter(inventory, fn p -> p.track_inventory and p.quantity_on_hand == 0 end)
  end

  defp quantity_color(product) do
    cond do
      product.quantity_on_hand == 0 -> "text-error"
      product.is_low_stock -> "text-warning"
      true -> "text-base-content"
    end
  end

  defp format_price(%Money{} = money) do
    Money.to_string!(money)
  end

  defp format_price(nil), do: "-"
  defp format_price(_), do: "-"
end
