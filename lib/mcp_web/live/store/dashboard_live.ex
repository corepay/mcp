defmodule McpWeb.Store.DashboardLive do
  use McpWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Store Dashboard")}
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <McpWeb.Core.CoreComponents.card>
        <McpWeb.Core.CoreComponents.header>
          Virtual Terminal
          <:subtitle>Process payments manually</:subtitle>
        </McpWeb.Core.CoreComponents.header>
        <div class="mt-4">
          <button class="btn btn-primary w-full">Open Terminal</button>
        </div>
      </McpWeb.Core.CoreComponents.card>

      <McpWeb.Core.CoreComponents.card>
        <McpWeb.Core.CoreComponents.header>
          Invoices
          <:subtitle>Manage customer invoices</:subtitle>
        </McpWeb.Core.CoreComponents.header>
        <div class="mt-4">
          <button class="btn btn-outline w-full">View Invoices</button>
        </div>
      </McpWeb.Core.CoreComponents.card>

      <McpWeb.Core.CoreComponents.card>
        <McpWeb.Core.CoreComponents.header>
          Subscriptions
          <:subtitle>Recurring billing management</:subtitle>
        </McpWeb.Core.CoreComponents.header>
        <div class="mt-4">
          <button class="btn btn-outline w-full">Manage Subscriptions</button>
        </div>
      </McpWeb.Core.CoreComponents.card>
    </div>
    """
  end
end
