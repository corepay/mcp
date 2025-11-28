defmodule McpWeb.Admin.Underwriting.KanbanLive do
  use McpWeb, :live_view

  alias Mcp.Underwriting.Application
  alias McpWeb.Admin.Underwriting.Components.KanbanColumn
  require Ash.Query

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to application updates for real-time board
      # Mcp.Underwriting.subscribe("applications") 
      # (Assuming pubsub is set up, skipping for now to keep it simple)
      :ok
    end

    socket = 
      if is_nil(socket.assigns[:current_tenant]) do
        tenant_id = socket.assigns.current_user.tenant_id
        tenant = Mcp.Platform.Tenant.get_by_id!(tenant_id)
        assign(socket, :current_tenant, tenant.company_schema)
      else
        socket
      end

    {:ok, load_board(socket)}
  end

  def handle_event("update_status", %{"id" => id, "new_status" => new_status}, socket) do
    # Convert status string to atom
    status_atom = String.to_existing_atom(new_status)
    
    case Application.get_by_id(id, tenant: socket.assigns.current_tenant) do
      {:ok, application} ->
        # Update status
        Application.update!(application, %{status: status_atom}, tenant: socket.assigns.current_tenant)
        
        {:noreply, 
         socket 
         |> put_flash(:info, "Application moved to #{new_status}")
         |> load_board()}
         
      _ ->
        {:noreply, put_flash(socket, :error, "Application not found")}
    end
  end

  defp load_board(socket) do
    # Fetch all active applications
    applications = 
      Application
      |> Ash.Query.filter(status != :rejected) # Maybe keep rejected in a separate view?
      |> Ash.read!(tenant: socket.assigns.current_tenant)
    
    # Group by status
    grouped = Enum.group_by(applications, & &1.status)
    
    assign(socket, :columns, [
      %{id: :draft, title: "Leads (Draft)", status: :draft, applications: Map.get(grouped, :draft, [])},
      %{id: :submitted, title: "Submitted", status: :submitted, applications: Map.get(grouped, :submitted, [])},
      %{id: :under_review, title: "Under Review", status: :under_review, applications: Map.get(grouped, :under_review, [])},
      %{id: :manual_review, title: "Manual Review", status: :manual_review, applications: Map.get(grouped, :manual_review, [])},
      %{id: :approved, title: "Approved", status: :approved, applications: Map.get(grouped, :approved, [])}
    ])
  end

  def render(assigns) do
    ~H"""
    <div class="h-[calc(100vh-4rem)] flex flex-col">
      <div class="px-6 py-4 border-b border-slate-800 flex justify-between items-center">
        <h1 class="text-2xl font-bold text-slate-100">Pipeline</h1>
        <div class="flex space-x-2">
          <.link navigate={~p"/admin/underwriting"} class="px-3 py-2 text-sm font-medium text-slate-400 hover:text-white">
            List View
          </.link>
          <button class="px-3 py-2 text-sm font-medium bg-slate-800 text-white rounded-md border border-slate-700">
            Board View
          </button>
        </div>
      </div>
      
      <div class="flex-1 overflow-x-auto overflow-y-hidden p-6">
        <div class="flex h-full space-x-4">
          <%= for column <- @columns do %>
            <.live_component 
              module={KanbanColumn} 
              id={"col-#{column.id}"} 
              title={column.title} 
              status={column.status} 
              applications={column.applications} 
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
