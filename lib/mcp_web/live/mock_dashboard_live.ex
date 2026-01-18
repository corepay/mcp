defmodule McpWeb.MockDashboardLive do
  use McpWeb, :live_view

  def mount(_params, _session, socket) do
    host = get_connect_info(socket, :host) || "localhost"
    context = get_portal_context(host)

    socket =
      socket
      |> assign(:page_title, "#{String.capitalize(Atom.to_string(context))} Dashboard")
      |> assign(:context, context)
      |> assign(:stats, get_mock_stats(context))
      |> assign(:activities, get_mock_activities(context))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-base-100 overflow-hidden font-sans">
      <%!-- Contextual Mock Header (Thin) --%>
      <header class="bg-base-100 border-b border-base-200/50 px-8 py-4 z-30 flex items-center justify-between">
        <div class="flex items-center gap-4">
          <div class="bg-base-200 p-2 rounded-lg text-primary">
            <.icon name={domain_icon(@context)} class="size-5" />
          </div>
          <div class="flex flex-col gap-0.5">
            <h1 class="text-sm font-black uppercase tracking-widest text-base-content/90">
              {String.capitalize(Atom.to_string(@context))} Dashboard
            </h1>
            <p class="text-[10px] font-medium text-base-content/40 uppercase tracking-tight">
              Overview of your {@context} operations and strategic metrics.
            </p>
          </div>
        </div>

        <div class="flex items-center gap-3">
          <McpWeb.Core.CoreComponents.button variant="primary" size="sm" class="rounded-xl px-4">
            <McpWeb.Core.CoreComponents.icon name="hero-plus" class="size-4 mr-2" /> New Action
          </McpWeb.Core.CoreComponents.button>
        </div>
      </header>

      <div class="flex-1 overflow-y-auto p-12 custom-scrollbar">
        <!-- Stats Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8 mb-12">
          <div
            :for={stat <- @stats}
            class="glass-panel p-6 rounded-2xl flex flex-col items-start relative overflow-hidden group hover:border-primary/50 transition-all"
          >
            <div class="size-10 rounded-xl bg-base-200 flex items-center justify-center mb-4 group-hover:bg-primary/10 transition-colors">
              <McpWeb.Core.CoreComponents.icon
                name={stat.icon}
                class="size-5 text-base-content/40 group-hover:text-primary"
              />
            </div>
            <div class="text-[10px] uppercase font-black text-base-content/30 tracking-widest leading-none mb-1">
              {stat.label}
            </div>
            <div class="text-2xl font-black text-base-content tracking-tighter">{stat.value}</div>
            <div class="text-[10px] font-mono text-primary mt-2">{stat.desc}</div>
          </div>
        </div>
        
    <!-- Main Content Area -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-12">
          <!-- Recent Activity -->
          <div class="lg:col-span-2 space-y-8">
            <div class="glass-panel rounded-3xl overflow-hidden">
              <div class="p-6 border-b border-base-200 flex justify-between items-center">
                <h3 class="font-black text-base-content uppercase tracking-widest text-xs">
                  Recent Activity
                </h3>
                <span class="text-[10px] font-mono text-base-content/30 uppercase">
                  Last 24 Hours
                </span>
              </div>
              <div class="overflow-x-auto">
                <table class="table w-full">
                  <thead>
                    <tr class="text-[10px] uppercase tracking-widest text-base-content/30 border-b border-base-200">
                      <th class="px-6 py-4">Event</th>
                      <th class="px-6 py-4">User</th>
                      <th class="px-6 py-4">Timestamp</th>
                      <th class="px-6 py-4 text-right">Status</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-base-200">
                    <tr :for={activity <- @activities} class="hover:bg-base-200/30 transition-colors">
                      <td class="px-6 py-4">
                        <div class="flex items-center gap-4">
                          <div class="size-8 rounded-lg bg-base-200 flex items-center justify-center font-bold text-xs text-base-content/40">
                            {String.at(activity.event, 0)}
                          </div>
                          <div>
                            <div class="text-sm font-bold text-base-content">{activity.event}</div>
                            <div class="text-[10px] font-mono opacity-30 tracking-tighter">
                              {activity.id}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td class="px-6 py-4 text-sm font-medium text-base-content/60">
                        {activity.user}
                      </td>
                      <td class="px-6 py-4 text-sm font-mono text-base-content/30">
                        {activity.date}
                      </td>
                      <td class="px-6 py-4 text-right">
                        <div class={[
                          "badge badge-sm font-black text-[9px] uppercase tracking-widest rounded-md",
                          status_color(activity.status)
                        ]}>
                          {activity.status}
                        </div>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
          
    <!-- Sidebar / Quick Actions -->
          <div class="space-y-8">
            <div class="glass-panel p-6 rounded-3xl">
              <h3 class="font-black text-base-content uppercase tracking-widest text-xs mb-6">
                Quick Actions
              </h3>
              <div class="grid gap-2">
                <button class="flex items-center gap-4 p-4 rounded-2xl hover:bg-base-200 transition-all group">
                  <div class="size-10 rounded-xl bg-base-200 flex items-center justify-center group-hover:bg-primary/10 transition-colors">
                    <McpWeb.Core.CoreComponents.icon
                      name="hero-cog-6-tooth"
                      class="size-5 text-base-content/40 group-hover:text-primary"
                    />
                  </div>
                  <span class="text-xs font-bold text-base-content/60 group-hover:text-base-content">
                    Domain Settings
                  </span>
                </button>
                <button class="flex items-center gap-4 p-4 rounded-2xl hover:bg-base-200 transition-all group">
                  <div class="size-10 rounded-xl bg-base-200 flex items-center justify-center group-hover:bg-primary/10 transition-colors">
                    <McpWeb.Core.CoreComponents.icon
                      name="hero-users"
                      class="size-5 text-base-content/40 group-hover:text-primary"
                    />
                  </div>
                  <span class="text-xs font-bold text-base-content/60 group-hover:text-base-content">
                    User Management
                  </span>
                </button>
                <button class="flex items-center gap-4 p-4 rounded-2xl hover:bg-base-200 transition-all group">
                  <div class="size-10 rounded-xl bg-base-200 flex items-center justify-center group-hover:bg-primary/10 transition-colors">
                    <McpWeb.Core.CoreComponents.icon
                      name="hero-document-text"
                      class="size-5 text-base-content/40 group-hover:text-primary"
                    />
                  </div>
                  <span class="text-xs font-bold text-base-content/60 group-hover:text-base-content">
                    Operational Ledger
                  </span>
                </button>
              </div>
            </div>

            <div class="p-8 rounded-3xl bg-primary text-black relative overflow-hidden group">
              <div class="absolute -right-4 -top-4 size-24 bg-white/10 rounded-full blur-2xl group-hover:bg-white/20 transition-all">
              </div>
              <h3 class="font-black uppercase tracking-widest text-xs mb-2">Network Status</h3>
              <p class="text-4xl font-black tracking-tighter mb-4 leading-none">Healthy</p>
              <div class="h-1.5 w-full bg-black/10 rounded-full overflow-hidden">
                <div class="bg-black/40 h-full w-[98%]"></div>
              </div>
              <p class="text-[10px] font-bold mt-4 opacity-50 uppercase tracking-widest">
                Global Plane Up-time: 99.9%
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_portal_context(host) do
    cond do
      String.starts_with?(host, "admin.") -> :admin
      String.starts_with?(host, "app.") -> :merchant
      String.starts_with?(host, "developers.") -> :developer
      String.starts_with?(host, "partners.") -> :reseller
      String.starts_with?(host, "store.") -> :customer
      String.starts_with?(host, "vendors.") -> :vendor
      true -> :tenant
    end
  end

  defp get_mock_stats(:admin) do
    [
      %{
        label: "Total Tenants",
        value: "124",
        desc: "↗︎ 12% more than last month",
        icon: "hero-building-office-2"
      },
      %{
        label: "Active Users",
        value: "4.2k",
        desc: "↗︎ 8% more than last month",
        icon: "hero-users"
      },
      %{
        label: "System Load",
        value: "24%",
        desc: "↘︎ 2% less than last month",
        icon: "hero-server"
      },
      %{
        label: "Revenue",
        value: "$45k",
        desc: "↗︎ 18% more than last month",
        icon: "hero-currency-dollar"
      }
    ]
  end

  defp get_mock_stats(:merchant) do
    [
      %{
        label: "Total Orders",
        value: "1,204",
        desc: "↗︎ 22% more than last month",
        icon: "hero-shopping-cart"
      },
      %{
        label: "Revenue",
        value: "$84.2k",
        desc: "↗︎ 14% more than last month",
        icon: "hero-currency-dollar"
      },
      %{
        label: "Customers",
        value: "892",
        desc: "↗︎ 5% more than last month",
        icon: "hero-user-group"
      },
      %{
        label: "Avg Order",
        value: "$72",
        desc: "↘︎ 1% less than last month",
        icon: "hero-chart-bar"
      }
    ]
  end

  defp get_mock_stats(_) do
    [
      %{label: "Metric A", value: "100", desc: "↗︎ 10% change", icon: "hero-chart-pie"},
      %{label: "Metric B", value: "50%", desc: "↘︎ 5% change", icon: "hero-bolt"},
      %{label: "Metric C", value: "1.2k", desc: "↗︎ 20% change", icon: "hero-users"},
      %{label: "Metric D", value: "$10k", desc: "↗︎ 15% change", icon: "hero-currency-dollar"}
    ]
  end

  defp get_mock_activities(_) do
    [
      %{
        event: "Login",
        user: "Alice Smith",
        date: "2 mins ago",
        id: "EVT-1023",
        status: "success"
      },
      %{
        event: "Update Profile",
        user: "Bob Jones",
        date: "15 mins ago",
        id: "EVT-1022",
        status: "info"
      },
      %{
        event: "Failed Login",
        user: "Unknown",
        date: "1 hour ago",
        id: "EVT-1021",
        status: "error"
      },
      %{
        event: "Subscription Renewed",
        user: "Charlie Brown",
        date: "2 hours ago",
        id: "EVT-1020",
        status: "success"
      },
      %{
        event: "Settings Changed",
        user: "Alice Smith",
        date: "5 hours ago",
        id: "EVT-1019",
        status: "warning"
      }
    ]
  end

  defp status_color("success"), do: "badge-success"
  defp status_color("error"), do: "badge-error"
  defp status_color("warning"), do: "badge-warning"
  defp status_color("info"), do: "badge-info"
  defp status_color(_), do: "badge-ghost"

  defp domain_icon(:admin), do: "hero-cpu-chip"
  defp domain_icon(:merchant), do: "hero-building-office"
  defp domain_icon(:developer), do: "hero-code-bracket"
  defp domain_icon(:reseller), do: "hero-share"
  defp domain_icon(:customer), do: "hero-user"
  defp domain_icon(:vendor), do: "hero-briefcase"
  defp domain_icon(_), do: "hero-briefcase"
end
