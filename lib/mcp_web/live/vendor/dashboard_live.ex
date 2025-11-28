defmodule McpWeb.Vendor.DashboardLive do
  use McpWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <McpWeb.Core.CoreComponents.header>
        Vendor Portal
        <:subtitle>Manage your supply chain and products.</:subtitle>
      </McpWeb.Core.CoreComponents.header>
      
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
        <McpWeb.Core.CoreComponents.card>
          <h3 class="font-bold text-lg">Products</h3>
          <p class="py-4">Manage products you supply.</p>
          <div class="card-actions justify-end">
            <McpWeb.Core.CoreComponents.button variant="primary" size="sm">Manage Products</McpWeb.Core.CoreComponents.button>
          </div>
        </McpWeb.Core.CoreComponents.card>
        
        <McpWeb.Core.CoreComponents.card>
          <h3 class="font-bold text-lg">Orders</h3>
          <p class="py-4">View purchase orders from merchants.</p>
          <div class="card-actions justify-end">
            <McpWeb.Core.CoreComponents.button variant="secondary" size="sm">View Orders</McpWeb.Core.CoreComponents.button>
          </div>
        </McpWeb.Core.CoreComponents.card>
      </div>
    </div>
    """
  end
end
