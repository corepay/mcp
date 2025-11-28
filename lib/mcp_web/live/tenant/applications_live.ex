defmodule McpWeb.Tenant.ApplicationsLive do
  use McpWeb, :live_view

  alias Mcp.Underwriting.Application, as: UnderwritingApplication

  def mount(_params, session, socket) do
    case session["tenant_id"] do
      nil ->
        {:ok, 
         socket
         |> put_flash(:error, "No tenant context found. Please access via a tenant subdomain.")
         |> push_navigate(to: ~p"/")}

      tenant_id ->
        # Check feature flag
        tenant = Mcp.Platform.Tenant.get_by_id!(tenant_id)
        features = tenant.features || %{}
        
        if !features["underwriting"] do
          {:ok, 
           socket 
           |> put_flash(:error, "Underwriting module is not enabled for your plan.")
           |> push_navigate(to: ~p"/tenant/dashboard")}
        else
          # Mock data for now
          applications = %{
            draft: [
              %{id: "1", business_name: "Joe's Coffee", risk_score: nil, inserted_at: DateTime.utc_now()},
              %{id: "2", business_name: "Tech Start Inc", risk_score: nil, inserted_at: DateTime.utc_now()}
            ],
            submitted: [
              %{id: "3", business_name: "Burger King Franchise #22", risk_score: 15, inserted_at: DateTime.utc_now()}
            ],
            underwriting: [
              %{id: "4", business_name: "Mega Corp", risk_score: 45, inserted_at: DateTime.utc_now()}
            ],
            approved: [
              %{id: "5", business_name: "Safe Shop", risk_score: 5, inserted_at: DateTime.utc_now()}
            ],
            rejected: []
          }

          {:ok, 
           socket
           |> assign(:page_title, "Underwriting Pipeline")
           |> assign(:applications, applications)}
        end
    end
  end

  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <McpWeb.Core.CoreComponents.header>
        Underwriting Pipeline
        <:subtitle>Manage merchant applications across stages.</:subtitle>
        <:actions>
          <McpWeb.Core.CoreComponents.button variant="primary" size="sm">
            <.icon name="hero-plus" class="w-4 h-4 mr-2" />
            New Application
          </McpWeb.Core.CoreComponents.button>
        </:actions>
      </McpWeb.Core.CoreComponents.header>

      <div class="flex-1 overflow-x-auto overflow-y-hidden mt-6">
        <div class="flex h-full gap-6 min-w-max pb-4">
          <!-- Leads / Draft -->
          <.kanban_column title="Draft" count={length(@applications.draft)} status="draft">
            <%= for app <- @applications.draft do %>
              <.application_card application={app} />
            <% end %>
          </.kanban_column>

          <!-- Submitted -->
          <.kanban_column title="Submitted" count={length(@applications.submitted)} status="submitted">
            <%= for app <- @applications.submitted do %>
              <.application_card application={app} />
            <% end %>
          </.kanban_column>

          <!-- Underwriting -->
          <.kanban_column title="Underwriting" count={length(@applications.underwriting)} status="underwriting">
            <%= for app <- @applications.underwriting do %>
              <.application_card application={app} />
            <% end %>
          </.kanban_column>

          <!-- Approved -->
          <.kanban_column title="Approved" count={length(@applications.approved)} status="approved">
            <%= for app <- @applications.approved do %>
              <.application_card application={app} />
            <% end %>
          </.kanban_column>

          <!-- Rejected -->
          <.kanban_column title="Rejected" count={length(@applications.rejected)} status="rejected">
            <%= for app <- @applications.rejected do %>
              <.application_card application={app} />
            <% end %>
          </.kanban_column>
        </div>
      </div>
    </div>
    """
  end

  # Helper Components

  attr :title, :string, required: true
  attr :count, :integer, default: 0
  attr :status, :string, required: true
  slot :inner_block, required: true
  
  def kanban_column(assigns) do
    ~H"""
    <div class="w-80 flex flex-col bg-base-200/50 rounded-xl border border-base-200 h-full">
      <div class="p-4 flex items-center justify-between border-b border-base-200 bg-base-100/50 rounded-t-xl backdrop-blur">
        <div class="flex items-center gap-2">
          <div class={"w-2 h-2 rounded-full #{status_color(@status)}"}></div>
          <h3 class="font-bold text-sm uppercase tracking-wider text-base-content/70"><%= @title %></h3>
        </div>
        <span class="badge badge-sm"><%= @count %></span>
      </div>
      <div class="p-3 flex-1 overflow-y-auto space-y-3 scrollbar-thin">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  attr :application, :map, required: true
  
  def application_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow cursor-pointer border border-base-200 group" phx-click={JS.navigate(~p"/tenant/applications/#{@application.id}")}>
      <div class="card-body p-4 gap-2">
        <div class="flex justify-between items-start">
          <h4 class="font-bold text-sm line-clamp-1 group-hover:text-primary transition-colors"><%= @application.business_name %></h4>
          <%= if @application[:risk_score] do %>
            <div class={"badge badge-xs font-mono #{risk_color(@application.risk_score)}"}>
              <%= @application.risk_score %>
            </div>
          <% end %>
        </div>
        <div class="text-xs text-base-content/60 flex items-center gap-1">
          <.icon name="hero-clock" class="w-3 h-3" />
          <%= Calendar.strftime(@application.inserted_at, "%b %d") %>
        </div>
      </div>
    </div>
    """
  end

  defp status_color("draft"), do: "bg-base-content/30"
  defp status_color("submitted"), do: "bg-info"
  defp status_color("underwriting"), do: "bg-warning"
  defp status_color("approved"), do: "bg-success"
  defp status_color("rejected"), do: "bg-error"

  defp risk_color(score) when score < 20, do: "badge-success"
  defp risk_color(score) when score < 50, do: "badge-warning"
  defp risk_color(_), do: "badge-error"
end
