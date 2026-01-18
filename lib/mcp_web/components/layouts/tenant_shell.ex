defmodule McpWeb.Layouts.TenantShell do
  @moduledoc """
  Tenant Portal shell layout featuring a horizontal mega-header and fluid workspace.
  """
  use Phoenix.Component
  use McpWeb, :verified_routes
  import McpWeb.Core.Navigation, only: [navbar: 1, dropdown: 1]
  import McpWeb.Core.DataDisplay, only: [avatar: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1]

  @domains [
    %{
      label: "Portfolio",
      id: "portfolio",
      icon: "hero-briefcase",
      active_prefix: "/tenant/merchants",
      sub_items: [
        %{
          label: "Merchant Accounts",
          href: "/tenant/merchants",
          icon: "hero-users",
          desc: "Manage active relationships and account hierarchies."
        },
        %{
          label: "Partner Network",
          href: "/partners",
          icon: "hero-share",
          desc: "Manage Agent, ISO, and Reseller organizations."
        },
        %{
          label: "Asset Inventory",
          href: "/tenant/terminals",
          icon: "hero-device-tablet",
          desc: "Hardware lifecycle and terminal estate tracking."
        }
      ]
    },
    %{
      label: "Onboarding",
      id: "onboarding",
      icon: "hero-arrow-path-rounded-square",
      active_prefix: "/tenant/underwriting",
      sub_items: [
        %{
          label: "Underwriting Workbench",
          href: "/tenant/underwriting",
          icon: "hero-rectangle-stack",
          desc: "Expert triage of forensic risk and new applications."
        },
        %{
          label: "Lead Pipeline",
          href: "/tenant/leads",
          icon: "hero-funnel",
          desc: "Strategic acquisition and pre-score discovery."
        },
        %{
          label: "Case Management",
          href: "/tenant/cases",
          icon: "hero-clipboard-document-check",
          desc: "Pending verifications and information requests."
        }
      ]
    },
    %{
      label: "Treasury",
      id: "treasury",
      icon: "hero-banknotes",
      active_prefix: "/tenant/billing",
      sub_items: [
        %{
          label: "Funding & Settlements",
          href: "/tenant/settlements",
          icon: "hero-currency-dollar",
          desc: "Daily net-funding and merchant payout monitoring."
        },
        %{
          label: "Pricing & Billing",
          href: "/tenant/fees",
          icon: "hero-receipt-percent",
          desc: "Configure fee schedules, margins, and commissions."
        },
        %{
          label: "Ledger Reconciliation",
          href: "/tenant/billing",
          icon: "hero-book-open",
          desc: "Cross-processor balancing and unitary accounting."
        }
      ]
    },
    %{
      label: "Compliance",
      id: "compliance",
      icon: "hero-shield-check",
      active_prefix: "/tenant/monitoring",
      sub_items: [
        %{
          label: "Risk Monitoring",
          href: "/tenant/monitoring",
          icon: "hero-eye",
          desc: "Continuous signal scanning for portfolio anomalies."
        },
        %{
          label: "Dispute Center",
          href: "/tenant/disputes",
          icon: "hero-exclamation-triangle",
          desc: "Chargeback management and retrieval tracking."
        },
        %{
          label: "Audit & Lineage",
          href: "/tenant/lineage",
          icon: "hero-fingerprint",
          desc: "Verifiable SHA-256 audit trails and KYC logs."
        }
      ]
    },
    %{
      label: "Operations",
      id: "ops",
      icon: "hero-cpu-chip",
      active_prefix: "/tenant/settings",
      sub_items: [
        %{
          label: "Connectivity & MIDs",
          href: "/tenant/underwriting/boarding",
          icon: "hero-rocket",
          desc: "Processor gateways and MID provisioning logs."
        },
        %{
          label: "Performance BI",
          href: "/tenant/dashboard",
          icon: "hero-presentation-chart-line",
          desc: "Executive dashboards and strategic analytics."
        },
        %{
          label: "Enterprise Settings",
          href: "/tenant/settings",
          icon: "hero-adjustments-vertical",
          desc: "Security, branding, and global platform config."
        }
      ]
    }
  ]

  attr :title, :string, default: "Intelligence Plane"
  attr :theme, :string, default: "noir"
  attr :current_path, :string, required: true
  attr :user_initials, :string, default: "?"

  slot :sidebar
  slot :inner_block, required: true

  def tenant_shell(assigns) do
    assigns = assign(assigns, :domains, @domains)

    ~H"""
    <div class="min-h-screen bg-base-100 flex flex-col font-sans" data-theme={@theme}>
      <%!-- Global Mega-Header --%>
      <.navbar class="bg-base-100 border-b border-base-300 sticky top-0 z-50 h-16">
        <:start>
          <div class="flex items-center gap-4 px-2">
            <div class="bg-primary p-1.5 rounded-lg shadow-lg shadow-primary/20">
              <.icon name="hero-cube-transparent" class="size-6 text-primary-content" />
            </div>
            <span class="text-lg font-black tracking-tighter uppercase whitespace-nowrap">
              Base <span class="text-primary opacity-80">MCP</span>
            </span>
          </div>
        </:start>

        <:center>
          <div class="hidden lg:flex items-center gap-1 bg-base-200/50 p-1 rounded-xl border border-base-300/50">
            <.link
              navigate={~p"/tenant/dashboard"}
              class={[
                "flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-semibold transition-all duration-200 cursor-pointer",
                active?(@current_path, "/tenant/dashboard") &&
                  "bg-base-100 text-primary shadow-sm border border-base-300/50",
                !active?(@current_path, "/tenant/dashboard") &&
                  "text-base-content/60 hover:text-base-content hover:bg-base-100/50"
              ]}
            >
              <.icon name="hero-rectangle-group" class="size-4" /> Dashboard
            </.link>

            <%= for domain <- @domains do %>
              <.dropdown hover class="group">
                <:trigger>
                  <div class={[
                    "flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-semibold transition-all duration-200 cursor-pointer",
                    active?(@current_path, domain.active_prefix) &&
                      "bg-base-100 text-primary shadow-sm border border-base-300/50",
                    !active?(@current_path, domain.active_prefix) &&
                      "text-base-content/60 group-hover:text-base-content group-hover:bg-base-100/50"
                  ]}>
                    <.icon name={domain.icon} class="size-4" />
                    {domain.label}
                    <.icon
                      name="hero-chevron-down"
                      class="size-3 opacity-40 group-hover:rotate-180 transition-transform duration-200"
                    />
                  </div>
                </:trigger>
                <:content>
                  <div class="p-2 w-80 dropdown-content-glass rounded-xl">
                    <div class="px-2 py-1 mb-2 text-[10px] font-black uppercase tracking-widest text-primary opacity-60">
                      {domain.label} Menu
                    </div>
                    <%= for item <- domain.sub_items do %>
                      <.link
                        navigate={item.href}
                        class="flex gap-4 p-3 rounded-xl hover:bg-base-200 transition-all group/item"
                      >
                        <div class="bg-base-300 p-2 rounded-lg group-hover/item:text-primary transition-colors">
                          <.icon name={item.icon} class="size-5" />
                        </div>
                        <div class="flex flex-col">
                          <span class="text-sm font-bold text-base-content">{item.label}</span>
                          <span class="text-[11px] text-base-content/50 leading-tight">
                            {item.desc}
                          </span>
                        </div>
                      </.link>
                    <% end %>
                  </div>
                </:content>
              </.dropdown>
            <% end %>
          </div>
        </:center>

        <:nav_end>
          <div class="flex items-center gap-3">
            <%!-- Notifications --%>
            <button class="btn btn-ghost btn-sm btn-circle indicator text-base-content/60">
              <span class="indicator-item badge badge-primary badge-xs"></span>
              <.icon name="hero-bell" class="size-5" />
            </button>
            <div class="h-4 w-px bg-base-300"></div>
            <.dropdown position="end">
              <:trigger>
                <div class="btn btn-ghost btn-sm gap-2 pl-1 pr-2 rounded-full border border-base-300">
                  <.avatar
                    initials={@user_initials}
                    size="xs"
                    class="bg-primary/20 text-primary text-[10px]"
                  />
                  <span class="text-xs font-semibold">jd_admin</span>
                </div>
              </:trigger>
              <:content>
                <li class="menu-title text-[10px] uppercase tracking-widest opacity-50">Identity</li>
                <li><a class="text-xs">Profile</a></li>
                <li><a class="text-xs">Security</a></li>
                <div class="divider my-1"></div>
                <li>
                  <.link method="delete" href={~p"/sign-out"} class="text-xs text-error">
                    Sign out
                  </.link>
                </li>
              </:content>
            </.dropdown>
          </div>
        </:nav_end>
      </.navbar>

      <%!-- Main Layout Container --%>
      <div class="flex flex-1 overflow-hidden">
        <%!-- Mini-Rail Sidebar (Contextual) --%>
        <aside
          :if={@sidebar != []}
          class="hidden lg:flex flex-col w-64 bg-base-200/30 border-r border-base-300 p-3 gap-1 overflow-y-auto"
        >
          {render_slot(@sidebar)}
        </aside>

        <%!-- Fluid Workspace Canvas --%>
        <main class="flex-1 overflow-y-auto relative bg-base-100">
          <div class="h-full">
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>
    </div>
    """
  end

  defp active?(current_path, prefix) do
    String.starts_with?(current_path, prefix)
  end
end
