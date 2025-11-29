defmodule McpWeb.Tenant.Underwriting.Components.KanbanColumn do
  use McpWeb, :live_component
  alias McpWeb.Tenant.Underwriting.Components.KanbanCard

  def render(assigns) do
    ~H"""
    <div class="flex-shrink-0 w-80 flex flex-col bg-slate-900/50 rounded-xl border border-slate-800 h-full max-h-full">
      <div class="p-3 border-b border-slate-800 flex justify-between items-center">
        <h3 class="font-semibold text-slate-200"><%= @title %></h3>
        <span class="bg-slate-800 text-slate-400 text-xs px-2 py-1 rounded-full">
          <%= length(@applications) %>
        </span>
      </div>
      
      <div 
        class="flex-1 p-2 overflow-y-auto space-y-2 min-h-0"
        id={"column-#{@status}"}
        phx-hook="Kanban"
        data-status={@status}
      >
        <%= for application <- @applications do %>
          <.live_component 
            module={KanbanCard} 
            id={"card-#{application.id}"} 
            application={application} 
          />
        <% end %>
        
        <%= if Enum.empty?(@applications) do %>
          <div class="h-24 border-2 border-dashed border-slate-800 rounded-lg flex items-center justify-center text-slate-600 text-sm">
            No applications
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
