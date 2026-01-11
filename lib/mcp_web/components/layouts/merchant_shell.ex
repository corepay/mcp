defmodule McpWeb.Layouts.MerchantShell do
  @moduledoc """
  Merchant Portal shell layout with top nav + contextual sidebar.
  """
  use Phoenix.Component
  import McpWeb.Core.Navigation, only: [navbar: 1, dropdown: 1]
  import McpWeb.Core.DataDisplay, only: [avatar: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1]
  import McpWeb.Portals.Merchant.Components, only: [context_switcher: 1]

  @nav_items [
    %{label: "Dashboard", href: "/app", icon: "hero-home"},
    %{label: "Products", href: "/app/products", icon: "hero-cube"},
    %{label: "Stores", href: "/app/stores", icon: "hero-building-storefront"},
    %{label: "Payments", href: "/app/payments", icon: "hero-credit-card"},
    %{label: "Customers", href: "/app/customers", icon: "hero-users"}
  ]

  @doc """
  Renders the Merchant Portal shell with top nav and optional contextual sidebar.

  ## Examples

      <.merchant_shell merchant_name="Acme" stores={[]} current_path="/app" user_initials="JD">
        <p>Content</p>
      </.merchant_shell>
  """
  attr :merchant_name, :string, required: true
  attr :stores, :list, default: []
  attr :current_path, :string, required: true
  attr :user_initials, :string, default: "?"
  attr :user_name, :string, default: nil
  attr :class, :string, default: nil

  slot :sidebar
  slot :inner_block, required: true

  def merchant_shell(assigns) do
    assigns = assign(assigns, :nav_items, @nav_items)

    ~H"""
    <div class={["min-h-screen bg-base-200 flex flex-col", @class]}>
      <%!-- Top Navigation Bar --%>
      <.navbar class="bg-base-100 sticky top-0 z-40">
        <:start>
          <.context_switcher
            current_name={@merchant_name}
            current_type={:merchant}
            stores={@stores}
          />
        </:start>

        <:center>
          <div class="hidden lg:flex gap-1">
            <a
              :for={item <- @nav_items}
              href={item.href}
              class={[
                "btn btn-ghost btn-sm gap-2",
                "font-medium",
                active?(@current_path, item.href) && "bg-base-200 text-primary"
              ]}
            >
              <.icon name={item.icon} class="size-4" />
              {item.label}
            </a>
          </div>
        </:center>

        <:nav_end>
          <%!-- Search --%>
          <button class="btn btn-ghost btn-circle">
            <.icon name="hero-magnifying-glass" class="size-5" />
          </button>

          <%!-- Help --%>
          <button class="btn btn-ghost btn-circle">
            <.icon name="hero-question-mark-circle" class="size-5" />
          </button>

          <%!-- Notifications --%>
          <button class="btn btn-ghost btn-circle indicator">
            <span class="indicator-item badge badge-primary badge-xs"></span>
            <.icon name="hero-bell" class="size-5" />
          </button>

          <%!-- User menu --%>
          <.dropdown position="end">
            <:trigger>
              <.avatar initials={@user_initials} size="sm" />
            </:trigger>
            <:content>
              <li :if={@user_name} class="menu-title">{@user_name}</li>
              <li><a href="/app/settings">Settings</a></li>
              <li><a href="/sign-out" data-method="delete">Sign out</a></li>
            </:content>
          </.dropdown>
        </:nav_end>
      </.navbar>

      <%!-- Content Area with optional sidebar --%>
      <div class="flex flex-1">
        <%!-- Contextual Sidebar (if provided) --%>
        <aside
          :if={@sidebar != []}
          class="hidden lg:block w-60 bg-base-100 border-r border-base-300/50 p-4"
        >
          <ul class="menu gap-1">
            {render_slot(@sidebar)}
          </ul>
        </aside>

        <%!-- Main Content --%>
        <main class="flex-1 p-6">
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>
    """
  end

  defp active?(current_path, href) do
    if href == "/app" do
      current_path == "/app"
    else
      String.starts_with?(current_path, href)
    end
  end
end
