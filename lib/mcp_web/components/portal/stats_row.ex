defmodule McpWeb.Portal.StatsRow do
  @moduledoc """
  Stats row component for displaying key metrics in a responsive grid layout.

  Provides a container component `stats_row/1` that arranges stats in a
  4-column grid on desktop and 2x2 grid on mobile, along with individual
  `stat/1` components for displaying metrics with optional trends.

  ## Examples

      <.stats_row>
        <.stat label="Revenue" value="$12,847" trend={+12} comparison="vs yesterday" />
        <.stat label="Transactions" value="156" trend={+8} comparison="vs yesterday" />
        <.stat label="Customers" value="89" trend={-3} comparison="vs yesterday" />
        <.stat label="Avg Order" value="$82.35" trend={+5} comparison="vs yesterday" />
      </.stats_row>
  """
  use Phoenix.Component

  import McpWeb.Core.CoreComponents, only: [icon: 1]

  @doc """
  Renders a responsive grid container for stat components.

  Uses a 2-column grid on mobile (grid-cols-2) and 4-column grid on desktop (md:grid-cols-4).

  ## Examples

      <.stats_row>
        <.stat label="Revenue" value="$12,847" />
        <.stat label="Transactions" value="156" />
      </.stats_row>
  """
  attr :class, :string, default: nil
  attr :"data-testid", :string, default: nil
  slot :inner_block, required: true

  def stats_row(assigns) do
    ~H"""
    <div
      class={[
        "grid grid-cols-2 md:grid-cols-4 gap-4",
        @class
      ]}
      data-testid={assigns[:"data-testid"]}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders an individual stat card with label, value, and optional trend.

  ## Props

  - `label` - The metric name (required)
  - `value` - The formatted value to display (required)
  - `trend` - Percentage change as an integer (+/-), shows arrow indicator
  - `comparison` - Comparison period text (e.g., "vs yesterday")
  - `icon` - Optional heroicon name (e.g., "hero-currency-dollar")
  - `href` - Optional link to detail page, makes the card clickable

  ## Examples

      <.stat label="Revenue" value="$12,847" trend={+12} comparison="vs yesterday" />
      <.stat label="Transactions" value="156" icon="hero-shopping-cart" href="/transactions" />
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :trend, :integer, default: nil
  attr :comparison, :string, default: nil
  attr :icon, :string, default: nil
  attr :href, :string, default: nil
  attr :class, :string, default: nil
  attr :"data-testid", :string, default: nil

  def stat(assigns) do
    assigns = assign(assigns, :trend_direction, get_trend_direction(assigns.trend))

    ~H"""
    <%= if @href do %>
      <.link
        href={@href}
        class={[
          "bg-base-100 rounded-box shadow-sm p-4",
          "border border-base-300/50",
          "transition-all duration-200",
          "hover:shadow-md hover:border-base-300 hover:bg-base-200/50",
          "block",
          @class
        ]}
        data-testid={assigns[:"data-testid"]}
      >
        <.stat_content
          label={@label}
          value={@value}
          trend={@trend}
          comparison={@comparison}
          icon={@icon}
          trend_direction={@trend_direction}
        />
      </.link>
    <% else %>
      <div
        class={[
          "bg-base-100 rounded-box shadow-sm p-4",
          "border border-base-300/50",
          "transition-all duration-200",
          @class
        ]}
        data-testid={assigns[:"data-testid"]}
      >
        <.stat_content
          label={@label}
          value={@value}
          trend={@trend}
          comparison={@comparison}
          icon={@icon}
          trend_direction={@trend_direction}
        />
      </div>
    <% end %>
    """
  end

  # Private component for stat content to avoid duplication
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :trend, :integer, default: nil
  attr :comparison, :string, default: nil
  attr :icon, :string, default: nil
  attr :trend_direction, :atom, default: nil

  defp stat_content(assigns) do
    ~H"""
    <div class="flex items-start justify-between">
      <div class="flex-1">
        <p class="text-sm font-medium text-base-content/70">{@label}</p>
        <p class="mt-1 text-2xl font-semibold text-base-content">{@value}</p>
        <div :if={@trend != nil || @comparison} class="mt-2 flex items-center gap-1">
          <span
            :if={@trend != nil && @trend_direction != :neutral}
            class={[
              "inline-flex items-center gap-0.5 text-sm font-medium",
              @trend_direction == :up && "text-success",
              @trend_direction == :down && "text-error"
            ]}
          >
            <.icon
              :if={@trend_direction == :up}
              name="hero-arrow-trending-up"
              class="size-4"
            />
            <.icon
              :if={@trend_direction == :down}
              name="hero-arrow-trending-down"
              class="size-4"
            />
            {format_trend(@trend)}
          </span>
          <span
            :if={@trend != nil && @trend_direction == :neutral}
            class="text-sm font-medium text-base-content/60"
          >
            {format_trend(@trend)}
          </span>
          <span :if={@comparison} class="text-sm text-base-content/60">
            {@comparison}
          </span>
        </div>
      </div>
      <div :if={@icon} class="flex-shrink-0">
        <.icon name={@icon} class="size-6 text-primary/60" />
      </div>
    </div>
    """
  end

  defp get_trend_direction(nil), do: nil
  defp get_trend_direction(trend) when trend > 0, do: :up
  defp get_trend_direction(trend) when trend < 0, do: :down
  defp get_trend_direction(0), do: :neutral

  defp format_trend(nil), do: ""
  defp format_trend(trend) when trend >= 0, do: "+#{trend}%"
  defp format_trend(trend), do: "#{trend}%"
end
