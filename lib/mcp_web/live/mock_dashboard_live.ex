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
    <div>
      <McpWeb.Core.CoreComponents.header>
        {String.capitalize(Atom.to_string(@context))} Dashboard
        <:subtitle>Overview of your {@context} operations.</:subtitle>
        <:actions>
          <McpWeb.Core.CoreComponents.button variant="primary" size="sm">
            <McpWeb.Core.CoreComponents.icon name="hero-plus" class="size-4 mr-2" /> New Action
          </McpWeb.Core.CoreComponents.button>
        </:actions>
      </McpWeb.Core.CoreComponents.header>
      
    <!-- Stats Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mt-8">
        <div :for={stat <- @stats} class="stats shadow bg-base-100 border border-base-200">
          <div class="stat">
            <div class="stat-figure text-primary">
              <McpWeb.Core.CoreComponents.icon name={stat.icon} class="size-8" />
            </div>
            <div class="stat-title">{stat.label}</div>
            <div class="stat-value text-primary">{stat.value}</div>
            <div class="stat-desc">{stat.desc}</div>
          </div>
        </div>
      </div>
      
    <!-- Main Content Area -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8 mt-8">
        <!-- Recent Activity -->
        <div class="lg:col-span-2 space-y-6">
          <McpWeb.Core.CoreComponents.card>
            <h3 class="font-bold text-lg mb-4">Recent Activity</h3>
            <div class="overflow-x-auto">
              <table class="table">
                <thead>
                  <tr>
                    <th>Event</th>
                    <th>User</th>
                    <th>Date</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={activity <- @activities} class="hover">
                    <td>
                      <div class="flex items-center gap-3">
                        <div class="avatar placeholder">
                          <div class="bg-neutral text-neutral-content rounded-full w-8">
                            <span class="text-xs">{String.at(activity.event, 0)}</span>
                          </div>
                        </div>
                        <div>
                          <div class="font-bold">{activity.event}</div>
                          <div class="text-sm opacity-50">{activity.id}</div>
                        </div>
                      </div>
                    </td>
                    <td>{activity.user}</td>
                    <td>{activity.date}</td>
                    <td>
                      <div class={["badge badge-sm", status_color(activity.status)]}>
                        {activity.status}
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </McpWeb.Core.CoreComponents.card>
          
    <!-- Chart Placeholder -->
          <McpWeb.Core.CoreComponents.card>
            <h3 class="font-bold text-lg mb-4">Performance Overview</h3>
            <div class="h-64 bg-base-200 rounded-box flex items-center justify-center text-base-content/30">
              [Chart Component Placeholder]
            </div>
          </McpWeb.Core.CoreComponents.card>
        </div>
        
    <!-- Sidebar / Quick Actions -->
        <div class="space-y-6">
          <McpWeb.Core.CoreComponents.card>
            <h3 class="font-bold text-lg mb-4">Quick Actions</h3>
            <ul class="menu bg-base-200 w-full rounded-box">
              <li><a><McpWeb.Core.CoreComponents.icon name="hero-cog-6-tooth" /> Settings</a></li>
              <li><a><McpWeb.Core.CoreComponents.icon name="hero-users" /> Manage Users</a></li>
              <li>
                <a><McpWeb.Core.CoreComponents.icon name="hero-document-text" /> View Reports</a>
              </li>
            </ul>
          </McpWeb.Core.CoreComponents.card>

          <McpWeb.Core.CoreComponents.card class="bg-primary text-primary-content">
            <h3 class="font-bold text-lg">System Status</h3>
            <p class="py-2">All systems operational.</p>
            <progress class="progress progress-success w-full" value="100" max="100"></progress>
          </McpWeb.Core.CoreComponents.card>
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
end
