defmodule McpWeb.Store.PosLive do
  use McpWeb, :live_view

  import McpWeb.Portal.FocusedLayout
  import McpWeb.Components.Pos.ProductGrid
  import McpWeb.Components.Pos.Cart
  import McpWeb.Components.Pos.PaymentModal

  @impl true
  def mount(%{"store_slug" => store_slug}, _session, socket) do
    products = load_products()
    categories = extract_categories(products)

    socket =
      socket
      |> assign(:page_title, "Point of Sale")
      |> assign(:store_slug, store_slug)
      |> assign(:products, products)
      |> assign(:filtered_products, products)
      |> assign(:categories, categories)
      |> assign(:selected_category, nil)
      |> assign(:search_query, "")
      |> assign(:cart_items, [])
      |> assign(:customer, nil)
      |> assign(:subtotal, Decimal.new("0.00"))
      |> assign(:tax, Decimal.new("0.00"))
      |> assign(:total, Decimal.new("0.00"))
      |> assign(:show_payment, false)
      |> assign(:selected_tip, nil)

    {:ok, socket, layout: {McpWeb.Layouts, :focused}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.focused_layout title="Point of Sale" exit={~p"/app/stores/#{@store_slug}/dashboard"}>
      <:left_panel>
        <.product_grid
          products={@filtered_products}
          categories={@categories}
          selected_category={@selected_category}
          search_query={@search_query}
        />
      </:left_panel>
      <:right_panel>
        <.cart
          items={@cart_items}
          customer={@customer}
          subtotal={@subtotal}
          tax={@tax}
          total={@total}
        />
      </:right_panel>
    </.focused_layout>

    <.payment_modal
      :if={@show_payment}
      total={@total}
      selected_tip={@selected_tip}
    />
    """
  end

  @impl true
  def handle_event("search_products", %{"query" => query}, socket) do
    filtered = filter_products(socket.assigns.products, query, socket.assigns.selected_category)

    {:noreply, assign(socket, search_query: query, filtered_products: filtered)}
  end

  def handle_event("select_category", %{"category" => category}, socket) do
    selected_category = if category == "", do: nil, else: category

    filtered =
      filter_products(socket.assigns.products, socket.assigns.search_query, selected_category)

    {:noreply, assign(socket, selected_category: selected_category, filtered_products: filtered)}
  end

  def handle_event("add_to_cart", %{"product_id" => product_id}, socket) do
    product = Enum.find(socket.assigns.products, &(&1.id == product_id))

    if product do
      cart_items = add_to_cart(socket.assigns.cart_items, product)
      {subtotal, tax, total} = calculate_totals(cart_items)

      {:noreply,
       assign(socket, cart_items: cart_items, subtotal: subtotal, tax: tax, total: total)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("increase_qty", %{"product_id" => product_id}, socket) do
    cart_items = update_quantity(socket.assigns.cart_items, product_id, 1)
    {subtotal, tax, total} = calculate_totals(cart_items)

    {:noreply, assign(socket, cart_items: cart_items, subtotal: subtotal, tax: tax, total: total)}
  end

  def handle_event("decrease_qty", %{"product_id" => product_id}, socket) do
    cart_items = update_quantity(socket.assigns.cart_items, product_id, -1)
    {subtotal, tax, total} = calculate_totals(cart_items)

    {:noreply, assign(socket, cart_items: cart_items, subtotal: subtotal, tax: tax, total: total)}
  end

  def handle_event("remove_item", %{"product_id" => product_id}, socket) do
    cart_items = Enum.reject(socket.assigns.cart_items, &(&1.id == product_id))
    {subtotal, tax, total} = calculate_totals(cart_items)

    {:noreply, assign(socket, cart_items: cart_items, subtotal: subtotal, tax: tax, total: total)}
  end

  def handle_event("checkout", _params, socket) do
    {:noreply, assign(socket, show_payment: true)}
  end

  def handle_event("cancel_payment", _params, socket) do
    {:noreply, assign(socket, show_payment: false, selected_tip: nil)}
  end

  def handle_event("clear_cart", _params, socket) do
    {:noreply,
     assign(socket,
       cart_items: [],
       subtotal: Decimal.new("0.00"),
       tax: Decimal.new("0.00"),
       total: Decimal.new("0.00")
     )}
  end

  # Catch-all handler for unimplemented events
  def handle_event(event, params, socket) do
    require Logger
    Logger.debug("Unhandled event: #{inspect(event)} with params: #{inspect(params)}")
    {:noreply, socket}
  end

  # Helper Functions

  defp load_products do
    [
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
      },
      %{id: "3", name: "Backpack", price: Decimal.new("49.00"), category: "Bags", image_url: nil},
      %{
        id: "4",
        name: "Water Bottle",
        price: Decimal.new("24.99"),
        category: "Drinkware",
        image_url: nil
      },
      %{id: "5", name: "Cap", price: Decimal.new("19.99"), category: "Apparel", image_url: nil},
      %{
        id: "6",
        name: "Phone Case",
        price: Decimal.new("15.00"),
        category: "Electronics",
        image_url: nil
      }
    ]
  end

  defp extract_categories(products) do
    products
    |> Enum.map(& &1.category)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp filter_products(products, query, category) do
    products
    |> filter_by_category(category)
    |> filter_by_query(query)
  end

  defp filter_by_category(products, nil), do: products

  defp filter_by_category(products, category) do
    Enum.filter(products, &(&1.category == category))
  end

  defp filter_by_query(products, ""), do: products

  defp filter_by_query(products, query) do
    query_lower = String.downcase(query)

    Enum.filter(products, fn product ->
      String.contains?(String.downcase(product.name), query_lower)
    end)
  end

  defp add_to_cart(cart_items, product) do
    case Enum.find_index(cart_items, &(&1.id == product.id)) do
      nil -> cart_items ++ [Map.put(product, :quantity, 1)]
      index -> List.update_at(cart_items, index, &increment_quantity/1)
    end
  end

  defp increment_quantity(item), do: %{item | quantity: item.quantity + 1}

  defp update_quantity(cart_items, product_id, delta) do
    cart_items
    |> Enum.map(fn item ->
      if item.id == product_id do
        %{item | quantity: max(0, item.quantity + delta)}
      else
        item
      end
    end)
    |> Enum.reject(&(&1.quantity == 0))
  end

  defp calculate_totals(cart_items) do
    subtotal =
      cart_items
      |> Enum.reduce(Decimal.new("0.00"), fn item, acc ->
        line_total = Decimal.mult(item.price, Decimal.new(item.quantity))
        Decimal.add(acc, line_total)
      end)

    # Tax rate: 8.25%
    tax = Decimal.mult(subtotal, Decimal.new("0.0825"))
    total = Decimal.add(subtotal, tax)

    {subtotal, tax, total}
  end
end
