defmodule McpWeb.Components.Terminal.HistoryDrawer do
  @moduledoc """
  Transaction history drawer for the Virtual Terminal.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  attr :transactions, :list, default: []
  attr :loading, :boolean, default: false
  attr :filter, :atom, default: :all, values: [:all, :approved, :declined, :pending]
  attr :selected_transaction, :map, default: nil
  attr :on_filter, :string, default: "history_filter"
  attr :on_select, :string, default: "history_select"
  attr :on_repeat, :string, default: "history_repeat"
  attr :on_refund, :string, default: "history_refund"
  attr :class, :string, default: nil

  def history_drawer(assigns) do
    ~H"""
    <div class={["history-drawer flex flex-col h-full", @class]}>
      <div class="flex-shrink-0 pb-4 border-b border-base-300">
        <div class="tabs tabs-boxed">
          <button
            :for={f <- [:all, :approved, :declined]}
            type="button"
            class={["tab", @filter == f && "tab-active"]}
            phx-click={@on_filter}
            phx-value-filter={f}
          >
            {filter_label(f)}
          </button>
        </div>
      </div>

      <div class="flex-1 overflow-y-auto py-4">
        <%= if @loading do %>
          <.loading_state />
        <% else %>
          <%= if length(@transactions) == 0 do %>
            <.empty_state />
          <% else %>
            <.transactions_list transactions={@transactions} on_select={@on_select} />
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp transactions_list(assigns) do
    ~H"""
    <div class="space-y-2">
      <button
        :for={txn <- @transactions}
        type="button"
        class="w-full flex items-center gap-3 p-3 rounded-lg hover:bg-base-200 transition-colors text-left"
        phx-click={@on_select}
        phx-value-id={txn.id}
      >
        <div class={[
          "w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0",
          status_bg(txn.status)
        ]}>
          <.icon name={status_icon(txn.status)} class={"size-5 #{status_color(txn.status)}"} />
        </div>

        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2">
            <p class="font-medium truncate">{txn.customer_name || "Guest"}</p>
            <span class={["badge badge-sm", status_badge(txn.status)]}>
              {status_label(txn.status)}
            </span>
          </div>
          <p class="text-sm text-base-content/60">
            {card_summary(txn)} · {format_time(txn.created_at)}
          </p>
        </div>

        <div class="text-right flex-shrink-0">
          <p class="font-semibold tabular-nums">{format_amount(txn.amount)}</p>
        </div>
      </button>
    </div>
    """
  end

  defp loading_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-12">
      <div class="loading loading-spinner loading-lg text-primary mb-2"></div>
      <p class="text-sm text-base-content/70">Loading transactions...</p>
    </div>
    """
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-12 text-center">
      <div class="w-16 h-16 bg-base-200 rounded-full flex items-center justify-center mb-4">
        <.icon name="hero-clock" class="size-8 text-base-content/30" />
      </div>
      <p class="font-medium">No transactions yet</p>
      <p class="text-sm text-base-content/70">Transactions will appear here</p>
    </div>
    """
  end

  defp filter_label(:all), do: "All"
  defp filter_label(:approved), do: "Approved"
  defp filter_label(:declined), do: "Declined"

  defp status_label(:approved), do: "Approved"
  defp status_label(:declined), do: "Declined"
  defp status_label(:pending), do: "Pending"
  defp status_label(_), do: "Unknown"

  defp status_icon(:approved), do: "hero-check"
  defp status_icon(:declined), do: "hero-x-mark"
  defp status_icon(:pending), do: "hero-clock"
  defp status_icon(_), do: "hero-question-mark-circle"

  defp status_color(:approved), do: "text-success"
  defp status_color(:declined), do: "text-error"
  defp status_color(:pending), do: "text-warning"
  defp status_color(_), do: "text-base-content/50"

  defp status_bg(:approved), do: "bg-success/20"
  defp status_bg(:declined), do: "bg-error/20"
  defp status_bg(:pending), do: "bg-warning/20"
  defp status_bg(_), do: "bg-base-200"

  defp status_badge(:approved), do: "badge-success"
  defp status_badge(:declined), do: "badge-error"
  defp status_badge(:pending), do: "badge-warning"
  defp status_badge(_), do: ""

  defp card_summary(%{card_brand: brand, last_four: last_four}) do
    "#{brand_label(brand)} ••#{last_four}"
  end

  defp card_summary(_), do: "Card"

  defp brand_label(:visa), do: "Visa"
  defp brand_label(:mastercard), do: "MC"
  defp brand_label(:amex), do: "Amex"
  defp brand_label(:discover), do: "Disc"
  defp brand_label(_), do: "Card"

  defp format_amount(amount) do
    "$#{format_decimal(amount)}"
  end

  defp format_decimal(decimal) do
    decimal
    |> Decimal.to_string(:normal)
    |> String.split(".")
    |> case do
      [dollars] -> "#{dollars}.00"
      [dollars, cents] -> "#{dollars}.#{String.pad_trailing(cents, 2, "0") |> String.slice(0, 2)}"
    end
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end
end
