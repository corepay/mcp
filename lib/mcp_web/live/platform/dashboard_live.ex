defmodule McpWeb.Platform.DashboardLive do
  use McpWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <McpWeb.Core.CoreComponents.header>
        Platform Admin Dashboard
        <:subtitle>Manage the entire platform from here.</:subtitle>
      </McpWeb.Core.CoreComponents.header>
      
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
        <McpWeb.Core.CoreComponents.card>
          <h3 class="font-bold text-lg">Tenants</h3>
          <p class="py-4">Manage all tenants on the platform.</p>
          <div class="card-actions justify-end">
            <McpWeb.Core.CoreComponents.button variant="primary" size="sm">View Tenants</McpWeb.Core.CoreComponents.button>
          </div>
        </McpWeb.Core.CoreComponents.card>
        
        <McpWeb.Core.CoreComponents.card>
          <h3 class="font-bold text-lg">System Health</h3>
          <p class="py-4">Monitor system performance and status.</p>
          <div class="card-actions justify-end">
            <McpWeb.Core.CoreComponents.button variant="secondary" size="sm">View Metrics</McpWeb.Core.CoreComponents.button>
          </div>
        </McpWeb.Core.CoreComponents.card>
      </div>
    </div>
    """
  end
end
