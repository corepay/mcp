defmodule McpWeb.Portal.PageLayout do
  @moduledoc """
  Page layout component for portal pages.

  Provides consistent layout structure across different page types with support
  for multiple variants: dashboard, list, detail, and table.

  ## Variants

  - `:dashboard` - Full-width content area for dashboard pages
  - `:list` - 2/3 + 1/3 split with sidebar for list pages
  - `:detail` - 2/3 + 1/3 split with back navigation for detail pages
  - `:table` - Full-width content for data table pages

  ## Examples

      # Dashboard layout
      <.page_layout variant={:dashboard} title="Dashboard">
        <:stats><.stats_row>...</.stats_row></:stats>
        <:content>Full-width dashboard content</:content>
      </.page_layout>

      # List layout with sidebar
      <.page_layout variant={:list} title="Products">
        <:toolbar>
          <.search_input placeholder="Search..." />
          <.button>+ Add</.button>
        </:toolbar>
        <:content>Product list</:content>
        <:sidebar><.action_sidebar /></:sidebar>
      </.page_layout>

      # Detail layout with back navigation
      <.page_layout variant={:detail} title="Product Name" back={~p"/products"}>
        <:content>Product details</:content>
        <:sidebar><.action_sidebar /></:sidebar>
      </.page_layout>
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  @doc """
  Renders a page layout with the specified variant.

  ## Attributes

  - `variant` - Layout variant (:dashboard, :list, :detail, :table). Required.
  - `title` - Page title. Required.
  - `back` - Back link URL for detail pages. Optional.

  ## Slots

  - `:stats` - Stats row area at the top of the page. Optional.
  - `:toolbar` - Search, filters, and action buttons. Optional.
  - `:content` - Main content area. Required.
  - `:sidebar` - Sidebar for list/detail variants. Optional, ignored for dashboard/table.
  """
  attr :variant, :atom, required: true, values: [:dashboard, :list, :detail, :table]
  attr :title, :string, required: true
  attr :back, :string, default: nil

  slot :stats
  slot :toolbar
  slot :content, required: true
  slot :sidebar

  def page_layout(assigns) do
    ~H"""
    <div class="page-layout">
      <%!-- Page Header with Title and optional Back Link --%>
      <div class={header_classes(@variant, @back)}>
        <.back_link :if={@back} href={@back} />
        <h1 class="text-2xl font-bold text-base-content">{@title}</h1>
      </div>

      <%!-- Stats Row (optional) --%>
      <div :if={@stats != []} class="mb-6">
        {render_slot(@stats)}
      </div>

      <%!-- Toolbar (optional) --%>
      <div :if={@toolbar != []} class="flex items-center justify-between gap-4 mb-4">
        {render_slot(@toolbar)}
      </div>

      <%!-- Main Content Area --%>
      <%= if has_sidebar?(@variant) do %>
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div class="lg:col-span-2">
            {render_slot(@content)}
          </div>
          <div :if={@sidebar != []} class="lg:col-span-1">
            {render_slot(@sidebar)}
          </div>
        </div>
      <% else %>
        <div>
          {render_slot(@content)}
        </div>
      <% end %>
    </div>
    """
  end

  defp header_classes(variant, back) when variant in [:detail] and not is_nil(back) do
    ["flex", "items-center", "gap-3", "mb-6"]
  end

  defp header_classes(_variant, _back), do: ["mb-6"]

  defp has_sidebar?(variant) when variant in [:list, :detail], do: true
  defp has_sidebar?(_variant), do: false

  defp back_link(assigns) do
    ~H"""
    <a href={@href} class="btn btn-ghost btn-sm btn-circle hover:bg-base-200">
      <.icon name="hero-arrow-left" class="size-5" />
    </a>
    """
  end
end
