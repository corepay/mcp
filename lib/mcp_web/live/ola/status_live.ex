defmodule McpWeb.Ola.StatusLive do
  @moduledoc """
  "Pizza Tracker" style status page for applicants to check their application status.
  """
  use McpWeb, :live_view

  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.Application, as: UWApplication
  alias McpWeb.Ola.Components.StatusTracker

  @impl true
  def mount(%{"id" => app_id}, session, socket) do
    tenant_id = session["tenant_id"]
    tenant = Tenant.get_by_id!(tenant_id)

    case UWApplication.get_by_id(app_id, tenant: tenant.company_schema) do
      {:ok, application} ->
        # Subscribe to updates
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Mcp.PubSub, "application:#{app_id}")
        end

        {:ok,
         socket
         |> assign(:page_title, "Application Status")
         |> assign(:application, application)
         |> assign(:tenant, tenant)}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Application not found")
         |> redirect(to: ~p"/online-application")}
    end
  end

  @impl true
  def handle_info({:application_updated, application}, socket) do
    {:noreply, assign(socket, :application, application)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 py-12 px-4">
      <div class="max-w-3xl mx-auto">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold">Application Status</h1>
          <p class="text-base-content/70 mt-2">
            {get_in(@application.application_data, ["business_name"]) || "Your Application"}
          </p>
        </div>

        <div class="card bg-base-100 shadow-xl p-8">
          <.live_component module={StatusTracker} id="status-tracker" status={@application.status} />
        </div>

        <div class="mt-6 text-center">
          <p class="text-sm text-base-content/50">
            Application ID: {String.slice(@application.id, 0, 8)}...
          </p>
          <p class="text-sm text-base-content/50">
            Submitted: {Calendar.strftime(@application.inserted_at, "%B %d, %Y at %I:%M %p")}
          </p>
        </div>

        <div class="mt-8 text-center">
          <.link navigate={~p"/online-application"} class="btn btn-outline">
            <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back to Application
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
