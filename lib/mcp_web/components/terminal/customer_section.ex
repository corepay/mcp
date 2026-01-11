defmodule McpWeb.Components.Terminal.CustomerSection do
  @moduledoc """
  Customer section component for the Virtual Terminal.
  Shows search state when no customer, or customer card when selected.
  Includes AI insight card per design contract lines 82-93.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  attr :customer, :map, default: nil
  attr :on_search, :string, default: "customer_search"
  attr :on_clear, :string, default: "clear_customer"
  attr :on_new, :string, default: "new_customer"
  attr :class, :string, default: nil

  def customer_section(assigns) do
    ~H"""
    <div class={["customer-section bg-base-200/50 rounded-xl p-4", @class]}>
      <%= if @customer do %>
        <.customer_card customer={@customer} on_clear={@on_clear} />
      <% else %>
        <.customer_search on_search={@on_search} on_new={@on_new} />
      <% end %>
    </div>
    """
  end

  defp customer_search(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <div class="flex-1">
        <label class="input input-bordered flex items-center gap-2">
          <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
          <input
            type="text"
            placeholder="Search or add customer..."
            class="grow border-none focus:ring-0"
            phx-keyup={@on_search}
            phx-debounce="300"
            name="customer_query"
          />
        </label>
      </div>
      <button type="button" class="btn btn-outline btn-sm" phx-click={@on_new}>
        <.icon name="hero-plus" class="size-4" />
        <span class="hidden sm:inline">New Customer</span>
      </button>
    </div>
    """
  end

  defp customer_card(assigns) do
    ~H"""
    <div class="flex items-start gap-4">
      <div class="avatar placeholder">
        <div class="bg-primary text-primary-content rounded-full w-12">
          <span class="text-lg">{initials(@customer.name)}</span>
        </div>
      </div>

      <div class="flex-1 min-w-0">
        <div class="flex items-center justify-between">
          <h4 class="font-semibold text-base-content truncate">{@customer.name}</h4>
          <button
            type="button"
            class="btn btn-ghost btn-xs btn-circle"
            phx-click={@on_clear}
            aria-label="Remove customer"
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>

        <div class="text-sm text-base-content/70 space-y-0.5">
          <p :if={@customer[:email]}>{@customer.email}</p>
          <p :if={@customer[:phone]}>{@customer.phone}</p>
        </div>
        
    <!-- AI INSIGHT CARD - PER DESIGN CONTRACT LINES 88-91 -->
        <%= if @customer[:insight] or @customer[:ai] do %>
          <div class="mt-3 p-3 bg-info/5 border border-info/20 rounded-lg">
            <div class="flex items-start gap-2">
              <.icon name="hero-sparkles" class="size-4 text-info mt-0.5 flex-shrink-0" />
              <div class="flex-1 min-w-0">
                <%= if @customer[:ai] do %>
                  <!-- Full AI intelligence with tier badge -->
                  <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs">
                    <span class="inline-flex items-center gap-1">
                      <span class={[
                        "badge badge-sm",
                        @customer.ai.tier == "VIP" && "badge-warning",
                        @customer.ai.tier == "Regular" && "badge-ghost",
                        @customer.ai.tier == "New" && "badge-info"
                      ]}>
                        {@customer.ai.tier}
                      </span>
                      customer
                    </span>
                    <span class="text-base-content/70">
                      <span class="font-medium">{@customer.ai.order_count}</span>
                      orders · <span class="font-medium">{@customer.ai.lifetime_spend}</span>
                      lifetime
                    </span>
                    <span class="text-base-content/60">
                      Last order: {@customer.ai.last_order}
                    </span>
                  </div>
                  <p
                    :if={@customer.ai.purchase_pattern}
                    class="text-xs text-base-content/60 mt-1 truncate"
                  >
                    {@customer.ai.purchase_pattern}
                  </p>
                <% else %>
                  <!-- Simple insight text -->
                  <span class="text-sm text-base-content/80">{@customer[:insight]}</span>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp initials(nil), do: "?"

  defp initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end
end
