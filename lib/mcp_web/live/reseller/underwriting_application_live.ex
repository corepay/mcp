defmodule McpWeb.Reseller.UnderwritingApplicationLive do
  use McpWeb, :live_view

  alias Mcp.Underwriting.Application

  def mount(%{"id" => id}, _session, socket) do
    application = Application.get_by_id!(id, load: [:risk_assessment, :clients])

    {:ok,
     socket
     |> assign(:page_title, "Application Details")
     |> assign(:application, application)}
  end

  def handle_event("approve", _params, socket) do
    # Logic to approve application
    # For now, just update status
    {:ok, updated_app} = 
      socket.assigns.application
      |> Ash.Changeset.for_update(:update, %{status: :approved})
      |> Ash.update()

    {:noreply, assign(socket, :application, updated_app)}
  end

  def handle_event("reject", _params, socket) do
    {:ok, updated_app} = 
      socket.assigns.application
      |> Ash.Changeset.for_update(:update, %{status: :rejected})
      |> Ash.update()

    {:noreply, assign(socket, :application, updated_app)}
  end

  def handle_event("request_info", _params, socket) do
    {:ok, updated_app} = 
      socket.assigns.application
      |> Ash.Changeset.for_update(:update, %{status: :more_info_required})
      |> Ash.update()

    {:noreply, assign(socket, :application, updated_app)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <McpWeb.Core.CoreComponents.header>
        Application Details
        <:subtitle>Review merchant application.</:subtitle>
        <:actions>
          <.link navigate={~p"/partners/applications"} class="btn btn-ghost btn-sm">
            Back
          </.link>
        </:actions>
      </McpWeb.Core.CoreComponents.header>

      <div class="mt-8 grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- Main Content -->
        <div class="lg:col-span-2 space-y-6">
          <McpWeb.Core.CoreComponents.card>
            <h3 class="font-bold text-lg mb-4">Merchant Information</h3>
            <dl class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <dt class="text-sm font-medium text-base-content/60">Legal Name</dt>
                <dd class="mt-1 text-sm"><%= @application.application_data["legal_name"] || "N/A" %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-base-content/60">DBA Name</dt>
                <dd class="mt-1 text-sm"><%= @application.application_data["dba_name"] || "N/A" %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-base-content/60">Tax ID</dt>
                <dd class="mt-1 text-sm"><%= @application.application_data["tax_id"] || "N/A" %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-base-content/60">Entity Type</dt>
                <dd class="mt-1 text-sm"><%= @application.application_data["entity_type"] || "N/A" %></dd>
              </div>
            </dl>
          </McpWeb.Core.CoreComponents.card>

          <McpWeb.Core.CoreComponents.card>
            <h3 class="font-bold text-lg mb-4">Owners</h3>
            <%= if @application.application_data["owners"] do %>
              <div class="space-y-4">
                <%= for owner <- @application.application_data["owners"] do %>
                  <div class="border-b border-base-200 pb-4 last:border-0 last:pb-0">
                    <p class="font-medium"><%= owner["first_name"] %> <%= owner["last_name"] %></p>
                    <p class="text-sm text-base-content/60"><%= owner["email"] %></p>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-sm text-base-content/60">No owners listed.</p>
            <% end %>
          </McpWeb.Core.CoreComponents.card>
        </div>

        <!-- Sidebar -->
        <div class="space-y-6">
          <McpWeb.Core.CoreComponents.card>
            <h3 class="font-bold text-lg mb-4">Status</h3>
            <div class={"badge #{status_badge_color(@application.status)} badge-lg w-full py-4"}>
              <%= @application.status |> to_string() |> String.capitalize() |> String.replace("_", " ") %>
            </div>
            
            <div class="mt-6 space-y-2">
              <button class="btn btn-success btn-block" phx-click="approve" disabled={@application.status == :approved}>
                Approve Application
              </button>
              <button class="btn btn-warning btn-block" phx-click="request_info">
                Request More Info
              </button>
              <button class="btn btn-error btn-block" phx-click="reject" disabled={@application.status == :rejected}>
                Reject Application
              </button>
            </div>
          </McpWeb.Core.CoreComponents.card>

          <%= if @application.risk_assessment do %>
            <McpWeb.Core.CoreComponents.card>
              <h3 class="font-bold text-lg mb-4">Risk Assessment</h3>
              <div class="radial-progress text-primary mx-auto block" style={"--value:#{@application.risk_assessment.score}; --size:8rem;"}>
                <span class="text-2xl font-bold"><%= @application.risk_assessment.score %></span>
              </div>
              <p class="text-center mt-2 text-sm text-base-content/60">Risk Score</p>
              
              <div class="mt-4">
                <p class="font-medium">Recommendation:</p>
                <p class="text-sm"><%= @application.risk_assessment.recommendation |> to_string() |> String.capitalize() %></p>
              </div>
            </McpWeb.Core.CoreComponents.card>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp status_badge_color(:draft), do: "badge-ghost"
  defp status_badge_color(:submitted), do: "badge-info"
  defp status_badge_color(:under_review), do: "badge-warning"
  defp status_badge_color(:approved), do: "badge-success"
  defp status_badge_color(:rejected), do: "badge-error"
  defp status_badge_color(:more_info_required), do: "badge-warning"
  defp status_badge_color(_), do: "badge-ghost"
end
