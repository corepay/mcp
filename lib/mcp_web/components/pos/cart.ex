defmodule McpWeb.Components.Pos.Cart do
  @moduledoc """
  POS Cart component - displays shopping cart with items, customer info, and checkout actions.
  """

  use Phoenix.Component
  import McpWeb.Core.CoreComponents

  @doc """
  Renders a POS cart with items, customer information, totals, and actions.

  ## Attributes
    * `items` - List of cart items, each with id, product, quantity, and subtotal
    * `customer` - Optional customer map with id, name, loyalty_points, loyalty_tier
    * `subtotal` - Cart subtotal as Decimal
    * `tax` - Tax amount as Decimal
    * `total` - Total amount as Decimal

  ## Examples

      <Cart.cart
        items={@cart_items}
        customer={@customer}
        subtotal={@subtotal}
        tax={@tax}
        total={@total}
      />
  """
  attr :items, :list, required: true
  attr :customer, :map, default: nil
  attr :subtotal, :any, required: true
  attr :tax, :any, required: true
  attr :total, :any, required: true

  def cart(assigns) do
    ~H"""
    <div class="flex h-full flex-col bg-base-100">
      <!-- Header -->
      <div class="border-b border-base-300 p-4">
        <h2 class="text-lg font-bold">CART</h2>
      </div>
      
    <!-- Customer Section -->
      <div class="border-b border-base-300 p-4">
        <%= if @customer do %>
          <div class="flex items-center gap-3" data-testid="customer-info">
            <div class="avatar placeholder">
              <div class="w-10 rounded-full bg-primary text-primary-content">
                <span class="text-xs">{initials(@customer.name)}</span>
              </div>
            </div>
            <div class="flex-1">
              <div class="font-semibold">{@customer.name}</div>
              <div class="text-sm text-base-content/70">
                {@customer.loyalty_points} pts
              </div>
            </div>
            <%= if @customer.loyalty_tier == :vip do %>
              <span class="badge badge-primary">VIP</span>
            <% end %>
          </div>
        <% else %>
          <button
            type="button"
            class="btn btn-outline btn-sm w-full"
            data-testid="add-customer-btn"
          >
            + Add Customer
          </button>
        <% end %>
      </div>
      
    <!-- Cart Items -->
      <div class="flex-1 overflow-y-auto p-4">
        <%= if Enum.empty?(@items) do %>
          <div class="flex flex-col items-center justify-center py-12" data-testid="empty-cart">
            <.icon name="hero-shopping-cart" class="h-16 w-16 text-base-content/30" />
            <p class="mt-4 text-base-content/70">Cart is empty</p>
          </div>
        <% else %>
          <div class="space-y-3">
            <%= for item <- @items do %>
              <div class="rounded-lg border border-base-300 p-3">
                <div class="flex items-start justify-between">
                  <div class="flex-1">
                    <div class="font-semibold">{item.product.name}</div>
                    <div class="text-sm text-base-content/70">
                      ${format_decimal(item.product.price)}
                    </div>
                  </div>
                  <div class="text-right font-semibold">
                    ${format_decimal(item.subtotal)}
                  </div>
                </div>
                <div class="mt-2 flex items-center justify-between">
                  <div class="btn-group">
                    <button
                      type="button"
                      class="btn btn-ghost btn-sm"
                      data-testid="qty-decrease"
                    >
                      -
                    </button>
                    <button type="button" class="btn btn-ghost btn-sm">
                      {item.quantity}
                    </button>
                    <button
                      type="button"
                      class="btn btn-ghost btn-sm"
                      data-testid="qty-increase"
                    >
                      +
                    </button>
                  </div>
                  <button
                    type="button"
                    class="btn btn-ghost btn-sm text-error"
                    data-testid="remove-item"
                  >
                    <.icon name="hero-trash" class="h-4 w-4" />
                  </button>
                </div>
              </div>
            <% end %>
          </div>
          
    <!-- Discount and Note Buttons -->
          <div class="mt-4 flex gap-2">
            <button type="button" class="btn btn-outline btn-sm flex-1">
              + Discount
            </button>
            <button type="button" class="btn btn-outline btn-sm flex-1">
              + Note
            </button>
          </div>
        <% end %>
      </div>
      
    <!-- Totals Section -->
      <div class="border-t border-base-300 p-4">
        <div class="space-y-2">
          <div class="flex justify-between text-sm">
            <span>Subtotal</span>
            <span>${format_decimal(@subtotal)}</span>
          </div>
          <div class="flex justify-between text-sm">
            <span>Tax</span>
            <span>${format_decimal(@tax)}</span>
          </div>
          <div class="flex justify-between border-t border-base-300 pt-2 text-lg font-bold">
            <span>TOTAL</span>
            <span>${format_decimal(@total)}</span>
          </div>
        </div>
        
    <!-- Pay Button -->
        <button
          type="button"
          class={"btn btn-primary btn-lg w-full mt-4 #{if Enum.empty?(@items), do: "btn-disabled"}"}
          data-testid="pay-btn"
          disabled={Enum.empty?(@items)}
        >
          PAY ${format_decimal(@total)}
        </button>
        
    <!-- Hold and Clear Buttons -->
        <%= if not Enum.empty?(@items) do %>
          <div class="mt-2 flex gap-2">
            <button type="button" class="btn btn-ghost btn-sm flex-1">
              Hold Order
            </button>
            <button type="button" class="btn btn-ghost btn-sm flex-1 text-error">
              Clear Cart
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper Functions

  defp initials(name) when is_binary(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  defp format_decimal(%Decimal{} = decimal) do
    decimal
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
  end
end
