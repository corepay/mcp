defmodule McpWeb.Ola.StatusLive do
  @moduledoc """
  "Pizza Tracker" style status page for applicants to check their application status.
  """
  use McpWeb, :live_view

  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.Application, as: UWApplication
  alias Mcp.Underwriting.Services.MagicCamera
  alias McpWeb.Ola.Components.StatusTracker

  @impl true
  def mount(%{"id" => app_id}, session, socket) do
    tenant_id = session["tenant_id"]
    tenant = Tenant.get_by_id!(tenant_id)
    tenant_schema = tenant.company_schema

    case UWApplication.get_by_id(app_id, tenant: tenant_schema) do
      {:ok, application} ->
        # Load documents
        application = Ash.load!(application, [:documents], tenant: tenant_schema)

        # Subscribe to application updates and magic camera handoff
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Mcp.PubSub, "application:#{app_id}")
          Phoenix.PubSub.subscribe(Mcp.PubSub, "magic_camera:#{app_id}")
        end

        {:ok,
         socket
         |> assign(:page_title, "Application Status")
         |> assign(:application, application)
         |> assign(:tenant, tenant)
         |> assign(:magic_session, nil)}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Application not found")
         |> redirect(to: ~p"/online-application")}
    end
  end

  @impl true
  def handle_event("generate_camera_link", %{"type" => type}, socket) do
    type = String.to_existing_atom(type)
    {:ok, session} = MagicCamera.generate_session(socket.assigns.application.id, type)
    {:noreply, assign(socket, :magic_session, session)}
  end

  @impl true
  def handle_info({:application_updated, application}, socket) do
    tenant_schema = socket.assigns.tenant.company_schema
    application = Ash.load!(application, [:documents], tenant: tenant_schema)
    {:noreply, assign(socket, :application, application)}
  end

  @impl true
  def handle_info({:document_uploaded, type, _path}, socket) do
    # Simply refresh the application to show the new document
    socket =
      socket
      |> put_flash(:info, "#{Phoenix.Naming.humanize(type)} uploaded via mobile.")
      |> assign(:magic_session, nil)

    {:noreply, refresh_application(socket)}
  end

  defp refresh_application(socket) do
    tenant_schema = socket.assigns.tenant.company_schema
    app_id = socket.assigns.application.id
    {:ok, application} = UWApplication.get_by_id(app_id, tenant: tenant_schema)
    application = Ash.load!(application, [:documents], tenant: tenant_schema)
    assign(socket, :application, application)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 py-12 px-4">
      <div class="max-w-3xl mx-auto">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-zinc-900 dark:text-zinc-100">Application Status</h1>
          <p class="text-base-content/70 mt-2">
            {get_in(@application.application_data, ["business_name"]) || "Your Application"}
          </p>
        </div>

        <div class="card bg-base-100 shadow-xl p-8 mb-8">
          <.live_component module={StatusTracker} id="status-tracker" status={@application.status} />
        </div>

        <%= if @application.status == :more_info_required or Enum.any?(@application.documents, & &1.status == :rejected) do %>
          <div class="alert alert-warning shadow-lg mb-8">
            <.icon name="hero-exclamation-triangle" class="w-6 h-6" />
            <div>
              <h3 class="font-bold">Action Required</h3>
              <div class="text-sm">
                We need some additional information to proceed with your application.
              </div>
            </div>
          </div>
        <% end %>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
          <!-- Documents Section -->
          <div class="space-y-6">
            <div class="card bg-base-100 shadow-md">
              <div class="card-body">
                <h2 class="card-title text-lg flex items-center justify-between">
                  Documents
                  <span class="badge badge-sm badge-ghost">{length(@application.documents)}</span>
                </h2>

                <%= if Enum.empty?(@application.documents) do %>
                  <p class="text-base-content/50 italic text-sm">No documents submitted yet.</p>
                <% else %>
                  <ul class="divide-y divide-base-200">
                    <%= for doc <- @application.documents do %>
                      <li class="py-3 flex justify-between items-center">
                        <div>
                          <p class="text-sm font-medium">{doc.file_name}</p>
                          <p class="text-[10px] uppercase font-bold text-base-content/50">
                            {doc.document_type}
                          </p>
                        </div>
                        <span class={[
                          "badge badge-xs gap-1",
                          case doc.status do
                            :verified -> "badge-success text-white"
                            :rejected -> "badge-error text-white"
                            _ -> "badge-ghost"
                          end
                        ]}>
                          <%= if doc.status == :verified do %>
                            <.icon name="hero-check" class="w-2 h-2" />
                          <% end %>
                          {doc.status}
                        </span>
                      </li>
                    <% end %>
                  </ul>
                <% end %>
              </div>
            </div>
          </div>
          
    <!-- Magic Camera / Instructions Section -->
          <div class="space-y-6">
            <div class="card bg-primary text-primary-content shadow-md">
              <div class="card-body">
                <h2 class="card-title text-lg">
                  <.icon name="hero-camera" class="w-5 h-5" /> Magic Camera
                </h2>
                <p class="text-sm opacity-90">
                  Easily upload documents or photos of your ID using your phone's camera.
                </p>

                <%= if @magic_session do %>
                  <div class="bg-white p-4 rounded-lg mt-4 text-center">
                    <p class="text-zinc-900 text-[10px] font-bold mb-2 uppercase">
                      Scan with your phone
                    </p>
                    <div class="bg-zinc-100 w-32 h-32 mx-auto flex items-center justify-center border-2 border-dashed border-zinc-300">
                      <img
                        src={"https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=#{URI.encode(@magic_session.qr_url)}"}
                        alt="QR Code"
                        class="w-full h-full"
                      />
                    </div>
                    <p class="text-[10px] text-zinc-500 mt-2 truncate">{@magic_session.qr_url}</p>
                  </div>
                <% else %>
                  <div class="card-actions mt-4">
                    <button
                      phx-click="generate_camera_link"
                      phx-value-type="government_id"
                      class="btn btn-secondary btn-sm w-full"
                    >
                      Upload via Phone
                    </button>
                  </div>
                <% end %>
              </div>
            </div>

            <div class="card bg-base-100 shadow-md">
              <div class="card-body">
                <h2 class="card-title text-lg">Need Help?</h2>
                <p class="text-sm text-base-content/70">
                  Our AI Support Assistant is available to help you with your application.
                </p>
                <div class="card-actions mt-4">
                  <.link
                    navigate={~p"/online-application"}
                    class="btn btn-outline btn-sm w-full text-zinc-900 dark:text-zinc-100"
                  >
                    Chat with Atlas
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="mt-12 text-center text-base-content/50 text-xs">
          <p>Application ID: {@application.id}</p>
          <p>Submitted: {Calendar.strftime(@application.inserted_at, "%B %d, %Y")}</p>
        </div>
      </div>
    </div>
    """
  end
end
