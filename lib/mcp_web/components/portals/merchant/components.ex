defmodule McpWeb.Portals.Merchant.Components do
  @moduledoc """
  Business components for the Merchant Portal.
  """
  use Phoenix.Component
  import McpWeb.Core.Navigation, only: [dropdown: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  @doc """
  Renders a context switcher for navigating between merchant and stores.

  ## Examples

      <.context_switcher
        current_name="Acme Corp"
        current_type={:merchant}
        stores={[%{name: "Downtown", slug: "downtown"}]}
      />
  """
  attr :current_name, :string, required: true
  attr :current_type, :atom, required: true, values: [:merchant, :store]
  attr :merchant_name, :string, default: nil
  attr :stores, :list, default: []
  attr :class, :string, default: nil

  def context_switcher(assigns) do
    ~H"""
    <.dropdown class={@class}>
      <:trigger>
        <button class={[
          "btn btn-ghost gap-2",
          "font-semibold text-base-content",
          "hover:bg-base-200"
        ]}>
          <span class="max-w-[180px] truncate">{@current_name}</span>
          <.icon name="hero-chevron-down" class="size-4 opacity-60" />
        </button>
      </:trigger>
      <:content>
        <%!-- Back to merchant if in store context --%>
        <li
          :if={@current_type == :store && @merchant_name}
          class="border-b border-base-300/50 pb-2 mb-2"
        >
          <a href="/app" class="flex items-center gap-2 text-base-content/70 hover:text-base-content">
            <.icon name="hero-arrow-left" class="size-4" />
            {@merchant_name}
          </a>
        </li>

        <%!-- Current merchant indicator --%>
        <li :if={@current_type == :merchant} class="border-b border-base-300/50 pb-2 mb-2">
          <span class="flex items-center gap-2 font-medium text-primary pointer-events-none">
            <span class="w-2 h-2 rounded-full bg-primary"></span>
            {@current_name}
          </span>
        </li>

        <%!-- Store list --%>
        <li :for={store <- @stores}>
          <a
            href={"/app/stores/#{store.slug}"}
            class="flex items-center gap-2 text-base-content/80 hover:text-base-content"
          >
            <span class={[
              "w-2 h-2 rounded-full",
              @current_type == :store && store.name == @current_name && "bg-primary",
              !(@current_type == :store && store.name == @current_name) && "bg-base-300"
            ]}>
            </span>
            {store.name}
          </a>
        </li>

        <%!-- New store --%>
        <li class="border-t border-base-300/50 pt-2 mt-2">
          <a
            href="/app/stores/new"
            class="flex items-center gap-2 text-base-content/60 hover:text-base-content"
          >
            <.icon name="hero-plus" class="size-4" /> New Store
          </a>
        </li>
      </:content>
    </.dropdown>
    """
  end
end
