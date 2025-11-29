defmodule McpWeb.Tenant.Underwriting.Components.KanbanCard do
  use McpWeb, :live_component
  alias McpWeb.Tenant.Underwriting.Components.SlaTimer

  def render(assigns) do
    ~H"""
    <div 
      class="bg-slate-800 p-4 rounded-lg shadow-sm border border-slate-700 cursor-move hover:border-blue-500 transition-colors"
      id={@id}
      data-id={@application.id}
      draggable="true"
    >
      <div class="flex justify-between items-start mb-2">
        <h4 class="font-medium text-slate-200 truncate pr-2">
          <%= get_in(@application.application_data, ["business_name"]) || "Unknown Business" %>
        </h4>
        <span class={[
          "px-2 py-0.5 text-xs rounded-full font-medium",
          risk_score_color(@application.risk_score)
        ]}>
          <%= @application.risk_score %>
        </span>
      </div>
      
      <div class="text-xs text-slate-400 mb-3">
        ID: <%= String.slice(@application.id, 0, 8) %>...
      </div>

      <div class="flex justify-between items-center text-xs">
        <div class="flex items-center space-x-1 text-slate-500">
          <.icon name="hero-calendar" class="w-3 h-3" />
          <span><%= Calendar.strftime(@application.inserted_at, "%b %d") %></span>
        </div>
        
        <%= if @application.sla_due_at do %>
          <.live_component module={SlaTimer} id={"sla-#{@application.id}"} due_at={@application.sla_due_at} />
        <% end %>
      </div>
    </div>
    """
  end

  defp risk_score_color(score) do
    cond do
      score >= 80 -> "bg-green-900 text-green-300"
      score >= 50 -> "bg-yellow-900 text-yellow-300"
      true -> "bg-red-900 text-red-300"
    end
  end
end
