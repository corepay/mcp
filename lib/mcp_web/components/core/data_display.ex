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
  attr :id, :string, default: nil
  attr :value, :string, required: true
  attr :label, :string, required: true
  attr :trend, :string, default: nil
  attr :trend_direction, :atom, default: nil, values: [nil, :up, :down]
  attr :icon, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  def stat_card(assigns) do
    ~H"""
    <div
      id={@id}
      {@rest}
      class={[
        "stat bg-base-100 rounded-box shadow-sm",
        "border border-base-300/50",
        "transition-all duration-200 hover:shadow-md hover:border-base-300",
        @class
      ]}
    >
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

  @doc """
  Renders a badge for status indicators and labels.

  ## Examples

      <.badge>Default</.badge>
      <.badge variant="success">Active</.badge>
      <.badge variant="error" size="lg">Failed</.badge>
  """
  attr :variant, :string,
    default: nil,
    values: [
      nil,
      "primary",
      "secondary",
      "accent",
      "info",
      "success",
      "warning",
      "error",
      "ghost"
    ]

  attr :size, :string, default: nil, values: [nil, "lg", "md", "sm", "xs"]
  attr :outline, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(data-testid)
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span
      class={[
        "badge",
        @variant && "badge-#{@variant}",
        @size && "badge-#{@size}",
        @outline && "badge-outline",
        "transition-colors duration-150",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  Renders an avatar with image or initials.

  ## Examples

      <.avatar src="/images/user.jpg" alt="John Doe" />
      <.avatar initials="JD" size="lg" />
      <.avatar initials="JD" online />
  """
  attr :src, :string, default: nil
  attr :alt, :string, default: "Avatar"
  attr :initials, :string, default: nil
  attr :size, :string, default: "md", values: ["xs", "sm", "md", "lg", "xl"]
  attr :online, :boolean, default: false
  attr :class, :string, default: nil

  def avatar(assigns) do
    size_classes = %{
      "xs" => "w-6",
      "sm" => "w-8",
      "md" => "w-10",
      "lg" => "w-16",
      "xl" => "w-24"
    }

    assigns = assign(assigns, :size_class, size_classes[assigns.size])

    ~H"""
    <div class={["avatar", @online && "online", @class]}>
      <div class={[
        @size_class,
        "rounded-full",
        !@src && "bg-primary text-primary-content",
        "ring ring-base-300 ring-offset-base-100 ring-offset-1",
        "transition-all duration-200"
      ]}>
        <img :if={@src} src={@src} alt={@alt} class="object-cover" />
        <span
          :if={!@src && @initials}
          class="flex items-center justify-center w-full h-full text-sm font-medium"
        >
          {@initials}
        </span>
      </div>
    </div>
    """
  end
end
