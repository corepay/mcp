defmodule McpWeb.Tenant.DashboardLive do
  use McpWeb, :live_view

  def mount(_params, session, socket) do
    case session["tenant_id"] do
      nil ->
        # Fetch all tenants for selection
        tenants = Mcp.Platform.Tenant.read!()
        {:ok, 
         socket
         |> assign(:page_title, "Select Tenant")
         |> assign(:tenants, tenants)
         |> assign(:mode, :select_tenant)}
         
      tenant_id ->
        tenant = Mcp.Platform.Tenant.get_by_id!(tenant_id)
        {:ok, 
         socket
         |> assign(:features, tenant.features || %{})
         |> assign(:mode, :dashboard)}
    end
  end

  def render(assigns) do
    ~H"""
    <%= if @mode == :select_tenant do %>
      <div class="max-w-2xl mx-auto mt-12">
        <McpWeb.Core.CoreComponents.header>
          Select Tenant
          <:subtitle>Choose a tenant workspace to access.</:subtitle>
        </McpWeb.Core.CoreComponents.header>
        
        <div class="grid gap-4 mt-6">
          <%= for tenant <- @tenants do %>
            <div class="card bg-base-100 shadow-sm border border-base-200 hover:border-primary cursor-pointer transition-colors">
              <div class="card-body flex-row items-center justify-between p-4">
                <div>
                  <h3 class="font-bold"><%= tenant.name %></h3>
                  <p class="text-sm text-base-content/60"><%= tenant.slug %></p>
                </div>
                <.form :let={_f} for={%{}} action={~p"/tenant/select"} method="post">
                  <input type="hidden" name="tenant_id" value={tenant.id} />
                  <button type="submit" class="btn btn-sm btn-primary">Select</button>
                </.form>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% else %>
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

          <%= if @features["underwriting"] do %>
            <McpWeb.Core.CoreComponents.card>
              <h3 class="font-bold text-lg">Underwriting</h3>
              <p class="py-4">Manage application pipeline and risk.</p>
              <div class="card-actions justify-end">
                <.link navigate={~p"/tenant/applications"} class="btn btn-primary btn-sm">
                  View Pipeline
                </.link>
              </div>
            </McpWeb.Core.CoreComponents.card>
          <% end %>

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
    <% end %>
    """
  end
end
