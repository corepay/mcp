defmodule McpWeb.Core.DataDisplay do
  @moduledoc """
  Data display components: stat cards, badges, progress indicators.
  """
  use Phoenix.Component

  @doc """
  Renders a stat card for dashboard metrics.

  ## Examples

      <.stat_card value="$12,847" label="Today's Revenue" />
      <.stat_card value="156" label="Transactions" trend="+12%" trend_direction={:up} />
  """
  attr :value, :string, required: true
  attr :label, :string, required: true
  attr :trend, :string, default: nil
  attr :trend_direction, :atom, default: nil, values: [nil, :up, :down]
  attr :icon, :string, default: nil
  attr :class, :string, default: nil

  def stat_card(assigns) do
    ~H"""
    <div class={[
      "stat bg-base-100 rounded-box shadow-sm",
      "border border-base-300/50",
      "transition-all duration-200 hover:shadow-md hover:border-base-300",
      @class
    ]}>
      <div :if={@icon} class="stat-figure text-primary">
        <span class={[@icon, "size-8 opacity-60"]} />
      </div>
      <div class="stat-title text-base-content/70 text-sm font-medium">{@label}</div>
      <div class="stat-value text-2xl font-semibold text-base-content">{@value}</div>
      <div
        :if={@trend}
        class={[
          "stat-desc text-sm font-medium",
          @trend_direction == :up && "text-success",
          @trend_direction == :down && "text-error",
          @trend_direction == nil && "text-base-content/60"
        ]}
      >
        <span :if={@trend_direction == :up}>↑</span>
        <span :if={@trend_direction == :down}>↓</span>
        {@trend}
      </div>
    </div>
    """
  end
end
