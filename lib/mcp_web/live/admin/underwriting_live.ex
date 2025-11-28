defmodule McpWeb.Admin.UnderwritingLive do
  use McpWeb, :live_view

  alias Mcp.Underwriting.Application

  @impl true
  def mount(_params, _session, socket) do
    # In a real app, we would filter by status (e.g., submitted, manual_review)
    # For now, we list all for visibility
    # We need to load the merchant relationship to display names
    
    # NOTE: Admin view needs to see ALL tenants' applications.
    # Ash multitenancy usually requires a specific tenant.
    # For a "Super Admin" view, we might need to iterate tenants or use a specific "admin" context.
    # For this iteration, we will assume the admin is viewing within a specific tenant context 
    # OR we need to bypass tenant checks (which is dangerous/complex in Ash).
    
    # SIMPLIFICATION: We will fetch applications for the "current tenant" of the admin.
    # In a real multi-tenant platform, the "Platform Admin" is a special case.
    
    # Assuming the admin is logged in and has a tenant_id in their session/user
    tenant_id = socket.assigns.current_user.tenant_id
    tenant = Mcp.Platform.Tenant.get_by_id!(tenant_id)

    applications = 
      Application.read!(load: [:merchant], tenant: tenant.company_schema)
      |> Enum.sort_by(&(&1.inserted_at), {:desc, Date})

    {:ok, 
     socket
     |> assign(:page_title, "Underwriting Dashboard")
     |> assign(:tenant, tenant)
     |> assign(:applications, applications)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <header class="flex justify-between items-center mb-6">
        <div>
          <h1 class="text-2xl font-bold text-zinc-900 dark:text-zinc-100">Underwriting Queue</h1>
          <p class="text-sm text-zinc-500 dark:text-zinc-400">Review and manage merchant applications.</p>
        </div>
        <div class="flex gap-2">
          <button class="btn btn-outline btn-sm">Filter</button>
          <button class="btn btn-primary btn-sm">Export</button>
        </div>
      </header>

      <div class="bg-white dark:bg-zinc-900 rounded-lg shadow overflow-hidden">
        <table class="table w-full">
          <thead class="bg-zinc-50 dark:bg-zinc-800 text-zinc-500 dark:text-zinc-400">
            <tr>
              <th>Merchant</th>
              <th>Submitted</th>
              <th>Risk Score</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-zinc-200 dark:divide-zinc-700">
            <%= for app <- @applications do %>
              <tr class="hover:bg-zinc-50 dark:hover:bg-zinc-800/50 transition-colors">
                <td>
                  <div class="flex items-center gap-3">
                    <div class="avatar placeholder">
                      <div class="bg-neutral-focus text-neutral-content rounded-full w-10">
                        <span class="text-xs"><%= String.at(app.application_data["business_name"] || "?", 0) %></span>
                      </div>
                    </div>
                    <div>
                      <div class="font-bold"><%= app.application_data["business_name"] %></div>
                      <div class="text-xs opacity-50"><%= app.merchant_id %></div>
                    </div>
                  </div>
                </td>
                <td><%= Calendar.strftime(app.inserted_at, "%b %d, %H:%M") %></td>
                <td>
                  <%= if app.risk_score do %>
                    <div class={"badge #{risk_score_color(app.risk_score)} gap-2"}>
                      <%= app.risk_score %>
                    </div>
                  <% else %>
                    <span class="text-zinc-400">-</span>
                  <% end %>
                </td>
                <td>
                  <div class={"badge #{status_badge_color(app.status)}"}>
                    <%= Phoenix.Naming.humanize(app.status) %>
                  </div>
                </td>
                <td>
                  <.link navigate={~p"/admin/underwriting/#{app.id}"} class="btn btn-ghost btn-xs">
                    Review
                  </.link>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp risk_score_color(score) when is_nil(score), do: "badge-ghost"
  defp risk_score_color(score) when score >= 90, do: "badge-success"
  defp risk_score_color(score) when score >= 70, do: "badge-info"
  defp risk_score_color(score) when score >= 50, do: "badge-warning"
  defp risk_score_color(_), do: "badge-error"

  defp status_badge_color(:approved), do: "badge-success"
  defp status_badge_color(:rejected), do: "badge-error"
  defp status_badge_color(:manual_review), do: "badge-warning"
  defp status_badge_color(:under_review), do: "badge-warning"
  defp status_badge_color(:submitted), do: "badge-info"
  defp status_badge_color(_), do: "badge-ghost"
end
