defmodule McpWeb.Merchant.DashboardLive do
  use McpWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <McpWeb.CoreComponents.header>
        Merchant Dashboard
        <:subtitle>Manage your store, products, and orders.</:subtitle>
      </McpWeb.CoreComponents.header>
      
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
        <McpWeb.CoreComponents.card>
          <h3 class="font-bold text-lg">Orders</h3>
          <p class="py-4">View and process incoming orders.</p>
          <div class="card-actions justify-end">
            <McpWeb.CoreComponents.button variant="primary" size="sm">View Orders</McpWeb.CoreComponents.button>
          </div>
        </McpWeb.CoreComponents.card>
        
        <McpWeb.CoreComponents.card>
          <h3 class="font-bold text-lg">Products</h3>
          <p class="py-4">Manage your product catalog.</p>
          <div class="card-actions justify-end">
            <McpWeb.CoreComponents.button variant="secondary" size="sm">Manage Products</McpWeb.CoreComponents.button>
          </div>
        </McpWeb.CoreComponents.card>
      </div>
    </div>
    """
  end
end
