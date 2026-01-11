defmodule McpWeb.Components.Terminal.AiProductSuggestions do
  @moduledoc """
  AI Product Suggestions component.
  Shows suggested products based on customer context.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  attr :suggestions, :list, default: []
  attr :on_add, :string, default: "add_suggested_product"
  attr :class, :string, default: nil

  def ai_product_suggestions(assigns) do
    ~H"""
    <div
      :if={length(@suggestions) > 0}
      class={["ai-suggestions mt-4 p-3 bg-info/5 border border-info/20 rounded-lg", @class]}
    >
      <div class="flex items-center gap-2 mb-3">
        <.icon name="hero-sparkles" class="size-4 text-info" />
        <span class="text-sm font-medium text-base-content/80">Suggested for this customer</span>
      </div>
      <div class="flex flex-wrap gap-2">
        <button
          :for={suggestion <- @suggestions}
          type="button"
          class="btn btn-sm btn-outline gap-2 bg-base-100/50 hover:bg-base-100"
          phx-click={@on_add}
          phx-value-id={suggestion.id}
        >
          <span>{suggestion.name}</span>
          <span class="badge badge-ghost badge-sm">{format_amount(suggestion.price)}</span>
        </button>
      </div>
    </div>
    """
  end

  defp format_amount(amount) do
    amount
    |> Decimal.to_string(:normal)
    |> String.split(".")
    |> case do
      [dollars] ->
        "$#{dollars}.00"

      [dollars, cents] ->
        "$#{dollars}.#{String.pad_trailing(cents, 2, "0") |> String.slice(0, 2)}"
    end
  end
end
