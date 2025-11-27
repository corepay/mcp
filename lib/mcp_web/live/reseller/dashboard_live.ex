defmodule McpWeb.Reseller.DashboardLive do
  use McpWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <McpWeb.CoreComponents.header>
        Reseller Portal
        <:subtitle>Manage your merchant portfolio.</:subtitle>
      </McpWeb.CoreComponents.header>
      
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
        <McpWeb.CoreComponents.card>
          <h3 class="font-bold text-lg">Portfolio</h3>
          <p class="py-4">View your managed merchants.</p>
          <div class="card-actions justify-end">
            <McpWeb.CoreComponents.button variant="primary" size="sm">View Portfolio</McpWeb.CoreComponents.button>
          </div>
        </McpWeb.CoreComponents.card>
        
        <McpWeb.CoreComponents.card>
          <h3 class="font-bold text-lg">Commissions</h3>
          <p class="py-4">Track your earnings and payouts.</p>
          <div class="card-actions justify-end">
            <McpWeb.CoreComponents.button variant="secondary" size="sm">View Reports</McpWeb.CoreComponents.button>
          </div>
        </McpWeb.CoreComponents.card>
      </div>
    </div>
    """
  end
end
