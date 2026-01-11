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

  @doc """
  Renders a top navigation bar.

  ## Examples

      <.navbar>
        <:start>Logo</:start>
        <:center>
          <a href="/dashboard">Dashboard</a>
        </:center>
        <:nav_end>
          <.avatar initials="JD" />
        </:nav_end>
      </.navbar>
  """
  attr :class, :string, default: nil

  slot :start
  slot :center
  slot :nav_end

  def navbar(assigns) do
    ~H"""
    <nav class={[
      "navbar bg-base-100 shadow-sm",
      "border-b border-base-300/50",
      "px-4 min-h-14",
      @class
    ]}>
      <div :if={@start != []} class="navbar-start gap-2">
        {render_slot(@start)}
      </div>
      <div :if={@center != []} class="navbar-center gap-1">
        {render_slot(@center)}
      </div>
      <div :if={@nav_end != []} class="navbar-end gap-2">
        {render_slot(@nav_end)}
      </div>
    </nav>
    """
  end

  @doc """
  Renders a left sidebar with grouped sections.

  ## Examples

      <.sidebar>
        <:header><span>Store Name</span></:header>
        <:section title="SELL">
          <li><a href="/pos">POS</a></li>
        </:section>
        <:footer><li><a>Settings</a></li></:footer>
      </.sidebar>
  """
  attr :class, :string, default: nil

  slot :header

  slot :section do
    attr :title, :string, required: true
    attr :collapsible, :boolean
  end

  slot :footer

  def sidebar(assigns) do
    ~H"""
    <aside class={[
      "flex flex-col w-64 min-h-screen",
      "bg-base-200 border-r border-base-300/50",
      @class
    ]}>
      <div :if={@header != []} class="p-4 border-b border-base-300/50">
        {render_slot(@header)}
      </div>

      <nav class="flex-1 overflow-y-auto p-2">
        <ul class="menu gap-1">
          <%= for section <- @section do %>
            <%= if section[:collapsible] do %>
              <li>
                <details class="collapse collapse-arrow">
                  <summary class="menu-title text-xs font-semibold text-base-content/60 uppercase tracking-wider">
                    {section.title}
                  </summary>
                  <ul class="collapse-content menu p-0 pl-2">
                    {render_slot(section)}
                  </ul>
                </details>
              </li>
            <% else %>
              <li class="menu-title text-xs font-semibold text-base-content/60 uppercase tracking-wider mt-4 first:mt-0">
                {section.title}
              </li>
              {render_slot(section)}
            <% end %>
          <% end %>
        </ul>
      </nav>

      <div :if={@footer != []} class="mt-auto border-t border-base-300/50 p-2">
        <ul class="menu gap-1">
          {render_slot(@footer)}
        </ul>
      </div>
    </aside>
    """
  end

  @doc """
  Renders horizontal navigation tabs.

  ## Examples

      <.tabs items={[
        %{label: "Dashboard", href: "/", active: true},
        %{label: "Products", href: "/products", active: false}
      ]} />
  """
  attr :items, :list, required: true
  attr :variant, :string, default: nil, values: [nil, "bordered", "boxed", "lifted"]
  attr :size, :string, default: nil, values: [nil, "xs", "sm", "md", "lg"]
  attr :class, :string, default: nil

  def tabs(assigns) do
    ~H"""
    <div
      role="tablist"
      class={[
        "tabs",
        @variant && "tabs-#{@variant}",
        @size && "tabs-#{@size}",
        @class
      ]}
    >
      <a
        :for={item <- @items}
        href={item.href}
        role="tab"
        class={[
          "tab",
          "transition-colors duration-150",
          item.active && "tab-active"
        ]}
      >
        {item.label}
      </a>
    </div>
    """
  end
end
