defmodule McpWeb.Tenant.DashboardLive do
  use McpWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <McpWeb.Core.CoreComponents.header>
        Tenant Dashboard
        <:subtitle>Manage your organization and merchants.</:subtitle>
      </McpWeb.Core.CoreComponents.header>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
        <McpWeb.Core.CoreComponents.card>
          <h3 class="font-bold text-lg">Merchants</h3>
          <p class="py-4">Onboard and manage your merchants.</p>
          <div class="card-actions justify-end">
            <McpWeb.Core.CoreComponents.button variant="primary" size="sm">
              View Merchants
            </McpWeb.Core.CoreComponents.button>
          </div>
        </McpWeb.Core.CoreComponents.card>

        <McpWeb.Core.CoreComponents.card>
          <h3 class="font-bold text-lg">Settings</h3>
          <p class="py-4">Configure your tenant settings and branding.</p>
          <div class="card-actions justify-end">
            <McpWeb.Core.CoreComponents.button variant="secondary" size="sm">
              Settings
            </McpWeb.Core.CoreComponents.button>
          </div>
        </McpWeb.Core.CoreComponents.card>
      </div>
    </div>
    """
  end
end
