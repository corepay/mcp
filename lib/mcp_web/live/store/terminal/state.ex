defmodule McpWeb.Store.Terminal.State do
  @moduledoc """
  State management for the Virtual Terminal.
  Handles line items, customer, totals calculation, and UI state.
  """

  defstruct [
    :store_slug,
    :customer,
    :line_items,
    :subtotal,
    :tax,
    :total,
    :tax_rate,
    :note,
    :show_payment_drawer,
    :show_send_link_modal,
    :show_email_modal,
    :show_history_drawer,
    :show_browse_drawer,
    :browse_drawer_type,
    :payment_status,
    :transaction_result
  ]

  @default_tax_rate Decimal.new("0.0825")

  def new(store_slug) do
    %__MODULE__{
      store_slug: store_slug,
      customer: nil,
      line_items: [],
      subtotal: Decimal.new("0.00"),
      tax: Decimal.new("0.00"),
      total: Decimal.new("0.00"),
      tax_rate: @default_tax_rate,
      note: nil,
      show_payment_drawer: false,
      show_send_link_modal: false,
      show_email_modal: false,
      show_history_drawer: false,
      show_browse_drawer: false,
      browse_drawer_type: nil,
      payment_status: nil,
      transaction_result: nil
    }
  end

  @doc "Add a product to line items"
  def add_product(%__MODULE__{} = state, product, quantity) do
    existing_index =
      Enum.find_index(state.line_items, &(&1.id == product.id && &1.type == :product))

    line_items =
      if existing_index do
        List.update_at(state.line_items, existing_index, fn item ->
          new_qty = item.quantity + quantity
          %{item | quantity: new_qty, line_total: Decimal.mult(item.unit_price, new_qty)}
        end)
      else
        item = %{
          id: product.id,
          type: :product,
          name: product.name,
          unit_price: product.price,
          quantity: quantity,
          line_total: Decimal.mult(product.price, quantity),
          source_id: product.id
        }

        state.line_items ++ [item]
      end

    %{state | line_items: line_items}
    |> recalculate_totals()
  end

  @doc "Add a fee to line items"
  def add_fee(%__MODULE__{} = state, fee) do
    item = %{
      id: fee.id || generate_id(),
      type: :fee,
      name: fee.name,
      unit_price: fee.amount,
      quantity: 1,
      line_total: fee.amount,
      percent: fee[:percent] || false,
      source_id: fee[:id]
    }

    %{state | line_items: state.line_items ++ [item]}
    |> recalculate_totals()
  end

  @doc "Add a discount to line items"
  def add_discount(%__MODULE__{} = state, discount) do
    line_total =
      if discount.percent do
        # Calculate percentage of current subtotal (products + fees only)
        taxable = calculate_taxable_subtotal(state.line_items)

        Decimal.mult(taxable, Decimal.div(discount.amount, 100))
        |> Decimal.negate()
      else
        Decimal.negate(discount.amount)
      end

    item = %{
      id: discount.id || generate_id(),
      type: :discount,
      name: discount.name,
      unit_price: discount.amount,
      quantity: 1,
      line_total: line_total,
      percent: discount.percent,
      source_id: discount[:id]
    }

    %{state | line_items: state.line_items ++ [item]}
    |> recalculate_totals()
  end

  @doc "Add a tip to line items (replaces existing tip)"
  def add_tip(%__MODULE__{} = state, amount) do
    # Remove existing tip
    line_items = Enum.reject(state.line_items, &(&1.type == :tip))

    item = %{
      id: generate_id(),
      type: :tip,
      name: "Tip",
      unit_price: amount,
      quantity: 1,
      line_total: amount,
      percent: false,
      source_id: nil
    }

    %{state | line_items: line_items ++ [item]}
    |> recalculate_totals()
  end

  @doc "Remove an item by ID"
  def remove_item(%__MODULE__{} = state, item_id) do
    line_items = Enum.reject(state.line_items, &(&1.id == item_id))

    %{state | line_items: line_items}
    |> recalculate_totals()
  end

  @doc "Update quantity for a product"
  def update_quantity(%__MODULE__{} = state, item_id, quantity) when quantity <= 0 do
    remove_item(state, item_id)
  end

  def update_quantity(%__MODULE__{} = state, item_id, quantity) do
    line_items =
      Enum.map(state.line_items, fn item ->
        if item.id == item_id and item.type == :product do
          %{item | quantity: quantity, line_total: Decimal.mult(item.unit_price, quantity)}
        else
          item
        end
      end)

    %{state | line_items: line_items}
    |> recalculate_totals()
  end

  @doc "Set customer on state"
  def set_customer(%__MODULE__{} = state, customer) do
    %{state | customer: customer}
  end

  @doc "Set note on state"
  def set_note(%__MODULE__{} = state, note) do
    %{state | note: note}
  end

  @doc "Clear customer from state"
  def clear_customer(%__MODULE__{} = state) do
    %{state | customer: nil}
  end

  @doc "Toggle payment drawer visibility"
  def toggle_payment_drawer(%__MODULE__{} = state) do
    %{state | show_payment_drawer: !state.show_payment_drawer}
  end

  @doc "Open payment drawer"
  def open_payment_drawer(%__MODULE__{} = state) do
    %{state | show_payment_drawer: true}
  end

  @doc "Close payment drawer"
  def close_payment_drawer(%__MODULE__{} = state) do
    %{state | show_payment_drawer: false}
  end

  @doc "Toggle send link modal visibility"
  def toggle_send_link_modal(%__MODULE__{} = state) do
    %{state | show_send_link_modal: !state.show_send_link_modal}
  end

  @doc "Toggle email modal visibility"
  def toggle_email_modal(%__MODULE__{} = state) do
    %{state | show_email_modal: !state.show_email_modal}
  end

  @doc "Toggle history drawer visibility"
  def toggle_history_drawer(%__MODULE__{} = state) do
    %{state | show_history_drawer: !state.show_history_drawer}
  end

  @doc "Open browse drawer with specific type"
  def open_browse_drawer(%__MODULE__{} = state, type) do
    %{state | show_browse_drawer: true, browse_drawer_type: type}
  end

  @doc "Close browse drawer"
  def close_browse_drawer(%__MODULE__{} = state) do
    %{state | show_browse_drawer: false, browse_drawer_type: nil}
  end

  @doc "Clear all items and reset state"
  def clear(%__MODULE__{} = state) do
    %{state | line_items: [], customer: nil}
    |> recalculate_totals()
  end

  # Private helpers

  defp recalculate_totals(%__MODULE__{} = state) do
    # Recalculate percentage discounts first
    taxable = calculate_taxable_subtotal(state.line_items)

    line_items =
      Enum.map(state.line_items, fn item ->
        if item.type == :discount and item.percent do
          new_total = Decimal.mult(taxable, Decimal.div(item.unit_price, 100)) |> Decimal.negate()
          %{item | line_total: new_total}
        else
          item
        end
      end)

    # Calculate subtotal (all items)
    subtotal =
      Enum.reduce(line_items, Decimal.new("0.00"), fn item, acc ->
        Decimal.add(acc, item.line_total)
      end)

    # Tax applies to products + fees only (not tips or discounts)
    taxable_for_tax = calculate_taxable_subtotal(line_items)

    discount_total =
      line_items
      |> Enum.filter(&(&1.type == :discount))
      |> Enum.reduce(Decimal.new("0.00"), &Decimal.add(&1.line_total, &2))

    taxable_after_discount =
      Decimal.add(taxable_for_tax, discount_total) |> Decimal.max(Decimal.new("0.00"))

    tax = Decimal.mult(taxable_after_discount, state.tax_rate) |> Decimal.round(2)

    # Total = subtotal + tax
    total = Decimal.add(subtotal, tax)

    %{state | line_items: line_items, subtotal: subtotal, tax: tax, total: total}
  end

  defp calculate_taxable_subtotal(line_items) do
    line_items
    |> Enum.filter(&(&1.type in [:product, :fee]))
    |> Enum.reduce(Decimal.new("0.00"), &Decimal.add(&1.line_total, &2))
  end

  defp generate_id do
    "item_#{:erlang.unique_integer([:positive])}"
  end
end
