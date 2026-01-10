defmodule McpWeb.Core.Feedback do
  @moduledoc """
  Feedback components: loading states, progress, notifications.
  """
  use Phoenix.Component

  @doc """
  Renders a skeleton loading placeholder.

  ## Examples

      <.skeleton />
      <.skeleton variant="text" />
      <.skeleton variant="circle" width="w-12" height="h-12" />
  """
  attr :variant, :string, default: "rect", values: ["rect", "text", "circle"]
  attr :width, :string, default: "w-full"
  attr :height, :string, default: nil
  attr :class, :string, default: nil

  def skeleton(assigns) do
    height =
      assigns.height ||
        case assigns.variant do
          "text" -> "h-4"
          "circle" -> "h-10"
          _ -> "h-20"
        end

    shape =
      case assigns.variant do
        "circle" -> "rounded-full"
        "text" -> "rounded"
        _ -> "rounded-box"
      end

    assigns = assign(assigns, height: height, shape: shape)

    ~H"""
    <div class={[
      "skeleton animate-pulse bg-base-300/50",
      @width,
      @height,
      @shape,
      @class
    ]}>
    </div>
    """
  end

  @doc """
  Renders a skeleton placeholder for stat cards.
  """
  attr :class, :string, default: nil

  def skeleton_stat_card(assigns) do
    ~H"""
    <div class={[
      "stat bg-base-100 rounded-box shadow-sm border border-base-300/50",
      @class
    ]}>
      <div class="stat-title">
        <.skeleton variant="text" width="w-24" />
      </div>
      <div class="stat-value py-2">
        <.skeleton variant="text" width="w-32" height="h-8" />
      </div>
      <div class="stat-desc">
        <.skeleton variant="text" width="w-16" />
      </div>
    </div>
    """
  end
end
