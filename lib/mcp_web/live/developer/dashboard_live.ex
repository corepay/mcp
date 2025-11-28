defmodule McpWeb.Developer.DashboardLive do
  use McpWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <McpWeb.Core.CoreComponents.header>
        Developer Portal
        <:subtitle>Manage your apps and integrations.</:subtitle>
      </McpWeb.Core.CoreComponents.header>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
        <McpWeb.Core.CoreComponents.card>
          <h3 class="font-bold text-lg">My Apps</h3>
          <p class="py-4">Manage your registered applications.</p>
          <div class="card-actions justify-end">
            <McpWeb.Core.CoreComponents.button variant="primary" size="sm">
              View Apps
            </McpWeb.Core.CoreComponents.button>
          </div>
        </McpWeb.Core.CoreComponents.card>

        <McpWeb.Core.CoreComponents.card>
          <h3 class="font-bold text-lg">API Keys</h3>
          <p class="py-4">Manage your API credentials.</p>
          <div class="card-actions justify-end">
            <McpWeb.Core.CoreComponents.button variant="secondary" size="sm">
              Manage Keys
            </McpWeb.Core.CoreComponents.button>
          </div>
        </McpWeb.Core.CoreComponents.card>
      </div>
    </div>
    """
  end
end
