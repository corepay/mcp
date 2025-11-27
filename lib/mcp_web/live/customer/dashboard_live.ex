defmodule McpWeb.Customer.DashboardLive do
  use McpWeb, :live_view
  
  # Explicitly using fully qualified names to debug import issue
  
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <McpWeb.CoreComponents.header>
        My Account
        <:subtitle>Manage your orders and profile.</:subtitle>
      </McpWeb.CoreComponents.header>
      
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
        <McpWeb.CoreComponents.card>
          <h3 class="font-bold text-lg">My Orders</h3>
          <p class="py-4">Track and view your order history.</p>
          <div class="card-actions justify-end">
            <McpWeb.CoreComponents.button variant="primary" size="sm">View Orders</McpWeb.CoreComponents.button>
          </div>
        </McpWeb.CoreComponents.card>
        
        <McpWeb.CoreComponents.card>
          <h3 class="font-bold text-lg">Profile</h3>
          <p class="py-4">Update your personal information.</p>
          <div class="card-actions justify-end">
            <McpWeb.CoreComponents.button variant="secondary" size="sm">Edit Profile</McpWeb.CoreComponents.button>
          </div>
        </McpWeb.CoreComponents.card>
      </div>
    </div>
    """
  end
end
