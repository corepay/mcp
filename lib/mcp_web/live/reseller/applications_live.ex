defmodule McpWeb.Reseller.ApplicationsLive do
  use McpWeb, :live_view

  def mount(_params, session, socket) do
    tenant_id = session["tenant_id"]
    # In a real app, we might handle the case where tenant_id is nil (e.g. super admin or error)
    # For now, we assume it's present as per the router pipeline
    tenant = Mcp.Platform.Tenant.get_by_id!(tenant_id)
    
    applications = Mcp.Underwriting.Application.read!(tenant: tenant.company_schema)

    {:ok,
     socket
     |> assign(:page_title, "My Portfolio")
     |> assign(:applications, applications)}
  end

  def handle_event("nudge", %{"id" => _id}, socket) do
    # Logic to send email/notification would go here
    
    {:noreply,
     socket
     |> put_flash(:info, "Nudge sent to applicant!")}
  end

  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <McpWeb.Core.CoreComponents.header>
        My Portfolio
        <:subtitle>Track and manage your referred merchant applications.</:subtitle>
      </McpWeb.Core.CoreComponents.header>

      <div class="mt-8 bg-base-100 border border-base-200 rounded-lg overflow-hidden">
        <table class="table w-full">
          <thead class="bg-base-200/50">
            <tr>
              <th>Business Name</th>
              <th>Status</th>
              <th>Last Activity</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
              <%= for app <- @applications do %>
              <tr class="hover">
                <td class="font-medium"><%= app.application_data["business_name"] || app.application_data["legal_name"] || "Unknown" %></td>
                <td>
                  <div class={"badge #{status_badge_color(app.status)}"}>
                    <%= app.status |> to_string() |> String.capitalize() %>
                  </div>
                </td>
                <td class="text-base-content/60">
                  <%= Calendar.strftime(app.updated_at, "%b %d, %I:%M %p") %>
                </td>
                <td>
                  <div class="flex gap-2">
                    <%= if app.status == :draft do %>
                      <button class="btn btn-xs btn-ghost text-primary" phx-click="nudge" phx-value-id={app.id}>
                        <.icon name="hero-bell-alert" class="w-4 h-4 mr-1" />
                        Nudge
                      </button>
                    <% end %>
                    <.link navigate={~p"/partners/applications/#{app.id}"} class="btn btn-xs btn-ghost">
                      View
                    </.link>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp status_badge_color(:draft), do: "badge-ghost"
  defp status_badge_color(:submitted), do: "badge-info"
  defp status_badge_color(:under_review), do: "badge-warning"
  defp status_badge_color(:more_info_required), do: "badge-warning"
  defp status_badge_color(:approved), do: "badge-success"
  defp status_badge_color(:rejected), do: "badge-error"
  defp status_badge_color(_), do: "badge-ghost"
end
