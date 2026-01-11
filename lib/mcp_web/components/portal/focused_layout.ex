defmodule McpWeb.Portal.FocusedLayout do
  @moduledoc """
  Focused layout component for distraction-free experiences.

  Used for POS, Terminal, Wizards and other full-screen focused workflows
  that need minimal chrome and maximum content space.

  ## Variants

  - `:two_panel` - Two-panel layout with 60/40 split (default)
  - `:centered` - Single centered content panel
  - `:wizard` - Progress indicator with centered content

  ## Examples

      # Two-panel POS layout (default)
      <.focused_layout title="Point of Sale" exit={~p"/dashboard"}>
        <:left_panel>Product grid</:left_panel>
        <:right_panel>Cart summary</:right_panel>
      </.focused_layout>

      # Centered terminal layout
      <.focused_layout title="Terminal" exit={~p"/dashboard"} variant={:centered}>
        <:content>Terminal interface</:content>
      </.focused_layout>

      # Wizard with progress
      <.focused_layout title="Checkout" exit={~p"/cart"} variant={:wizard}>
        <:progress>Step 1 of 3</:progress>
        <:content>Wizard step content</:content>
      </.focused_layout>
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  @doc """
  Renders a focused layout for distraction-free experiences.

  ## Attributes

  - `title` - Page title displayed in header. Required.
  - `exit` - Exit URL for the back/close button. Required.
  - `variant` - Layout variant (:two_panel, :centered, :wizard). Default :two_panel.
  - `show_intelligence_bar` - Whether to show the AI intelligence bar. Default false.
  - `class` - Additional CSS classes for the container.

  ## Slots

  - `:left_panel` - Left panel content for two_panel variant (60% width).
  - `:right_panel` - Right panel content for two_panel variant (40% width).
  - `:content` - Main content area for centered/wizard variants.
  - `:progress` - Progress indicator for wizard variant.
  """
  attr :title, :string, required: true
  attr :exit, :string, required: true
  attr :variant, :atom, default: :two_panel, values: [:two_panel, :centered, :wizard]
  attr :show_intelligence_bar, :boolean, default: false
  attr :class, :string, default: nil

  slot :left_panel
  slot :right_panel
  slot :content
  slot :progress

  def focused_layout(assigns) do
    ~H"""
    <div class={["focused-layout min-h-screen flex flex-col bg-base-100", @class]}>
      <.focused_header
        title={@title}
        exit={@exit}
        show_intelligence_bar={@show_intelligence_bar}
      />

      <.progress_bar :if={@variant == :wizard and @progress != []} progress={@progress} />

      <main class="flex-1 flex overflow-hidden">
        <.layout_content variant={@variant} assigns={assigns} />
      </main>
    </div>
    """
  end

  # Private component: Minimal focused header
  defp focused_header(assigns) do
    ~H"""
    <header class="navbar bg-base-200 border-b border-base-300 px-4">
      <div class="flex-none">
        <a href={@exit} class="btn btn-ghost btn-sm btn-circle" aria-label="Exit">
          <.icon name="hero-arrow-left" class="size-5" />
        </a>
      </div>
      <div class="flex-1 justify-center">
        <h1 class="text-lg font-semibold text-base-content">{@title}</h1>
      </div>
      <div class="flex-none">
        <div :if={@show_intelligence_bar} class="intelligence-bar">
          <button class="btn btn-ghost btn-sm" aria-label="Command palette">
            <.icon name="hero-command-line" class="size-5" />
          </button>
        </div>
      </div>
    </header>
    """
  end

  # Private component: Progress bar for wizard variant
  defp progress_bar(assigns) do
    ~H"""
    <div class="px-6 py-4 bg-base-200 border-b border-base-300">
      {render_slot(@progress)}
    </div>
    """
  end

  # Private component: Layout content based on variant
  defp layout_content(%{variant: :two_panel} = assigns) do
    assigns = Map.get(assigns, :assigns, assigns)

    ~H"""
    <div class="flex w-full h-full">
      <div class="w-3/5 flex-shrink-0 overflow-auto border-r border-base-300 p-4">
        {render_slot(@left_panel)}
      </div>
      <div class="w-2/5 flex-shrink-0 overflow-auto bg-base-200 p-4">
        {render_slot(@right_panel)}
      </div>
    </div>
    """
  end

  defp layout_content(%{variant: variant} = assigns) when variant in [:centered, :wizard] do
    assigns = Map.get(assigns, :assigns, assigns)

    ~H"""
    <div class="flex-1 flex items-center justify-center p-6">
      <div class="w-full max-w-2xl mx-auto">
        {render_slot(@content)}
      </div>
    </div>
    """
  end
end
