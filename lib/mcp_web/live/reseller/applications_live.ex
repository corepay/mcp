defmodule McpWeb.Reseller.ApplicationsLive do
  use McpWeb, :live_view

  def mount(_params, _session, socket) do
    # Mock data
    applications = [
      %{id: "1", business_name: "Joe's Coffee", status: :draft, last_activity: DateTime.utc_now() |> DateTime.add(-86400, :second)},
      %{id: "3", business_name: "Burger King Franchise #22", status: :submitted, last_activity: DateTime.utc_now() |> DateTime.add(-3600, :second)},
      %{id: "5", business_name: "Safe Shop", status: :approved, last_activity: DateTime.utc_now() |> DateTime.add(-10000, :second)}
    ]

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
                <td class="font-medium"><%= app.business_name %></td>
                <td>
                  <div class={"badge #{status_badge_color(app.status)}"}>
                    <%= app.status |> to_string() |> String.capitalize() %>
                  </div>
                </td>
                <td class="text-base-content/60">
                  <%= Calendar.strftime(app.last_activity, "%b %d, %I:%M %p") %>
                </td>
                <td>
                  <%= if app.status == :draft do %>
                    <button class="btn btn-xs btn-ghost text-primary" phx-click="nudge" phx-value-id={app.id}>
                      <.icon name="hero-bell-alert" class="w-4 h-4 mr-1" />
                      Nudge
                    </button>
                  <% end %>
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
  defp status_badge_color(:underwriting), do: "badge-warning"
  defp status_badge_color(:approved), do: "badge-success"
  defp status_badge_color(:rejected), do: "badge-error"
end
