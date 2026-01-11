defmodule McpWeb.Layouts.StoreShell do
  @moduledoc """
  Store Portal shell layout with left sidebar navigation.

  This shell provides navigation infrastructure (left sidebar, top bar) while portal
  components provide content structure within the shell.

  ## Integration with Portal Components

  The shell makes portal layout components available for use in LiveViews:

  - `page_layout/1` - Provides content structure (dashboard, list, detail, table variants)
  - `stats_row/1`, `stat/1` - Key metrics display
  - `action_sidebar/1`, `sidebar_action/1`, `sidebar_filter/1`, `ai_insight/1` - Sidebar actions/filters
  - `data_table/1`, `pagination/1` - Data tables with pagination

  ## Usage Pattern

  Normal pages use the shell for navigation + page_layout for content:

      defmodule McpWeb.Store.Orders.IndexLive do
        use McpWeb, :live_view

        def render(assigns) do
          ~H\"\"\"
          <.page_layout variant={:list} title="Orders">
            <:stats>
              <.stats_row>
                <.stat label="Today" value="24" trend={+12} comparison="vs yesterday" />
                <.stat label="Revenue" value="$1,847" trend={+8} comparison="vs yesterday" />
              </.stats_row>
            </:stats>
            <:content>
              <.data_table id="orders" rows={@orders}>
                <:col :let={order} label="Order #" field={:number}>{order.number}</:col>
                <:col :let={order} label="Customer" field={:customer}>{order.customer_name}</:col>
                <:col :let={order} label="Total" field={:total} align={:right}>{order.total}</:col>
              </.data_table>
            </:content>
            <:sidebar>
              <.action_sidebar>
                <:actions>
                  <.sidebar_action icon="hero-plus" label="New Order" href={~p"/app/stores/\#{@store_slug}/orders/new"} />
                </:actions>
                <:filters>
                  <.sidebar_filter label="Status" options={@status_options} field={:status} />
                </:filters>
              </.action_sidebar>
            </:sidebar>
          </.page_layout>
          \"\"\"
        end
      end

  For focused pages (POS, Terminal, Wizards), bypass the shell entirely using
  `layout {McpWeb.Layouts, :focused}` - see `McpWeb.Portal.FocusedLayout`.

      defmodule McpWeb.Store.PosLive do
        use McpWeb, :live_view

        # Use focused layout instead of shell
        @impl true
        def mount(_params, _session, socket) do
          {:ok, socket, layout: {McpWeb.Layouts, :focused}}
        end

        def render(assigns) do
          ~H\"\"\"
          <.focused_layout title="Point of Sale" exit={~p"/app/stores/\#{@store_slug}"}>
            <:left_panel>Product grid</:left_panel>
            <:right_panel>Cart summary</:right_panel>
          </.focused_layout>
          \"\"\"
        end
      end
  """
  use Phoenix.Component
  import McpWeb.Core.Navigation, only: [dropdown: 1]
  import McpWeb.Core.DataDisplay, only: [avatar: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1]
  import McpWeb.Portals.Merchant.Components, only: [context_switcher: 1]

  # Note: Portal layout components (stats_row, page_layout, action_sidebar, data_table)
  # are globally available via McpWeb html_helpers - no need to import here.

  # Navigation sections - visibility controlled by vertical
  @nav_sections [
    %{
      id: :sell,
      title: "SELL",
      items: [
        %{label: "POS", href: "/pos", icon: "hero-shopping-cart", verticals: :all},
        %{label: "Terminal", href: "/terminal", icon: "hero-computer-desktop", verticals: :all},
        %{
          label: "Orders",
          href: "/orders",
          icon: "hero-clipboard-document-list",
          verticals: [:retail, :restaurant]
        },
        %{
          label: "Invoices",
          href: "/invoices",
          icon: "hero-document-text",
          verticals: [:retail, :services, :subscription]
        }
      ]
    },
    %{
      id: :manage,
      title: "MANAGE",
      items: [
        %{label: "Customers", href: "/customers", icon: "hero-users", verticals: :all},
        %{label: "Products", href: "/products", icon: "hero-cube", verticals: :all},
        %{
          label: "Inventory",
          href: "/inventory",
          icon: "hero-archive-box",
          verticals: [:retail, :restaurant]
        },
        %{
          label: "Subscriptions",
          href: "/subscriptions",
          icon: "hero-arrow-path",
          verticals: [:subscription]
        },
        %{label: "Loyalty", href: "/loyalty", icon: "hero-gift", verticals: :all}
      ]
    },
    %{
      id: :schedule,
      title: "SCHEDULE",
      items: [
        %{
          label: "Appointments",
          href: "/appointments",
          icon: "hero-calendar",
          verticals: [:services]
        },
        %{label: "Tables", href: "/tables", icon: "hero-table-cells", verticals: [:restaurant]},
        %{label: "Staff", href: "/staff", icon: "hero-user-group", verticals: :all}
      ]
    },
    %{
      id: :money,
      title: "MONEY",
      items: [
        %{label: "Refunds", href: "/refunds", icon: "hero-receipt-refund", verticals: :all},
        %{
          label: "Tips",
          href: "/tips",
          icon: "hero-banknotes",
          verticals: [:restaurant, :services]
        },
        %{label: "Reports", href: "/reports", icon: "hero-chart-bar", verticals: :all}
      ]
    }
  ]

  @doc """
  Renders the Store Portal shell with left sidebar navigation.

  ## Examples

      <.store_shell
        store_name="Downtown Store"
        store_slug="downtown"
        merchant_name="Acme Corp"
        current_path="/app/stores/downtown"
        user_initials="JD"
        vertical={:retail}
      >
        <p>Content</p>
      </.store_shell>
  """
  attr :store_name, :string, required: true
  attr :store_slug, :string, required: true
  attr :merchant_name, :string, required: true
  attr :current_path, :string, required: true
  attr :user_initials, :string, default: "?"
  attr :user_name, :string, default: nil

  attr :vertical, :atom,
    default: :retail,
    values: [:retail, :restaurant, :services, :subscription]

  attr :shift_start, :string, default: nil
  attr :other_stores, :list, default: []
  attr :class, :string, default: nil

  slot :inner_block, required: true

  def store_shell(assigns) do
    base_path = "/app/stores/#{assigns.store_slug}"
    nav_sections = filter_nav_for_vertical(@nav_sections, assigns.vertical, base_path)
    assigns = assign(assigns, nav_sections: nav_sections, base_path: base_path)

    ~H"""
    <div class={["min-h-screen bg-base-200 flex", @class]}>
      <%!-- Left Sidebar --%>
      <aside class="w-64 bg-base-100 border-r border-base-300/50 flex flex-col">
        <%!-- Header with context switcher --%>
        <div class="p-3 border-b border-base-300/50">
          <.context_switcher
            current_name={@store_name}
            current_type={:store}
            merchant_name={@merchant_name}
            stores={@other_stores}
          />
        </div>

        <%!-- Navigation sections --%>
        <nav class="flex-1 overflow-y-auto p-2">
          <%!-- Dashboard link --%>
          <ul class="menu gap-1 mb-2">
            <li>
              <a
                href={@base_path}
                class={[
                  "flex items-center gap-3",
                  active?(@current_path, @base_path, true) && "active"
                ]}
              >
                <.icon name="hero-home" class="size-5" /> Dashboard
              </a>
            </li>
          </ul>

          <%!-- Grouped sections --%>
          <div :for={section <- @nav_sections} class="mb-4">
            <div class="menu-title text-xs font-semibold text-base-content/60 uppercase tracking-wider px-4 py-2">
              {section.title}
            </div>
            <ul class="menu gap-1">
              <li :for={item <- section.items}>
                <a
                  href={item.full_href}
                  class={[
                    "flex items-center gap-3",
                    active?(@current_path, item.full_href, false) && "active"
                  ]}
                >
                  <.icon name={item.icon} class="size-5" />
                  {item.label}
                </a>
              </li>
            </ul>
          </div>
        </nav>

        <%!-- Footer with settings and shift --%>
        <div class="mt-auto border-t border-base-300/50 p-2">
          <ul class="menu gap-1">
            <li>
              <a href={"#{@base_path}/settings"} class="flex items-center gap-3">
                <.icon name="hero-cog-6-tooth" class="size-5" /> Settings
              </a>
            </li>
            <li>
              <a href={"#{@base_path}/close-shift"} class="flex items-center gap-3">
                <.icon name="hero-clock" class="size-5" /> Close Shift
              </a>
            </li>
          </ul>

          <%!-- Shift info --%>
          <div :if={@shift_start} class="px-4 py-2 text-xs text-base-content/60">
            Shift: {@shift_start} - Close
          </div>
        </div>
      </aside>

      <%!-- Main content area --%>
      <div class="flex-1 flex flex-col">
        <%!-- Top bar (slimmer than merchant) --%>
        <header class="h-12 bg-base-100 border-b border-base-300/50 flex items-center justify-end px-4 gap-2">
          <%!-- Search --%>
          <button class="btn btn-ghost btn-sm btn-circle">
            <.icon name="hero-magnifying-glass" class="size-4" />
          </button>

          <%!-- Help --%>
          <button class="btn btn-ghost btn-sm btn-circle">
            <.icon name="hero-question-mark-circle" class="size-4" />
          </button>

          <%!-- Notifications --%>
          <button class="btn btn-ghost btn-sm btn-circle indicator">
            <span class="indicator-item badge badge-primary badge-xs"></span>
            <.icon name="hero-bell" class="size-4" />
          </button>

          <%!-- User menu --%>
          <.dropdown position="end">
            <:trigger>
              <.avatar initials={@user_initials} size="xs" />
            </:trigger>
            <:content>
              <li :if={@user_name} class="menu-title">{@user_name}</li>
              <li><a href={"#{@base_path}/settings"}>Settings</a></li>
              <li><a href="/sign-out" data-method="delete">Sign out</a></li>
            </:content>
          </.dropdown>
        </header>

        <%!-- Main content --%>
        <main class="flex-1 p-6 overflow-auto">
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>
    """
  end

  defp filter_nav_for_vertical(sections, vertical, base_path) do
    sections
    |> Enum.map(fn section ->
      items =
        section.items
        |> Enum.filter(fn item ->
          item.verticals == :all || vertical in item.verticals
        end)
        |> Enum.map(fn item ->
          Map.put(item, :full_href, base_path <> item.href)
        end)

      %{section | items: items}
    end)
    |> Enum.reject(fn section -> section.items == [] end)
  end

  defp active?(current_path, href, exact) do
    if exact do
      current_path == href
    else
      String.starts_with?(current_path, href)
    end
  end
end
