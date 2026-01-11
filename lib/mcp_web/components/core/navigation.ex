# lib/mcp_web/components/core/navigation.ex
defmodule McpWeb.Core.Navigation do
  @moduledoc """
  Navigation components: navbar, sidebar, dropdown, tabs.
  """
  use Phoenix.Component

  @doc """
  Renders a dropdown menu.

  ## Examples

      <.dropdown>
        <:trigger>
          <button class="btn">Menu</button>
        </:trigger>
        <:content>
          <li><a>Profile</a></li>
          <li><a>Settings</a></li>
        </:content>
      </.dropdown>
  """
  attr :position, :string, default: nil, values: [nil, "end", "top", "bottom", "left", "right"]
  attr :hover, :boolean, default: false
  attr :class, :string, default: nil

  slot :trigger, required: true
  slot :content, required: true

  def dropdown(assigns) do
    ~H"""
    <div class={[
      "dropdown",
      @position && "dropdown-#{@position}",
      @hover && "dropdown-hover",
      @class
    ]}>
      <div tabindex="0" role="button">
        {render_slot(@trigger)}
      </div>
      <ul
        tabindex="0"
        class={[
          "dropdown-content menu",
          "bg-base-100 rounded-box shadow-xl",
          "border border-base-300/50",
          "z-50 w-52 p-2",
          "transition-all duration-200"
        ]}
      >
        {render_slot(@content)}
      </ul>
    </div>
    """
  end
end
