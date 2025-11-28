defmodule McpWeb.Admin.ReviewLive do
  use McpWeb, :live_view

  alias Mcp.Underwriting.Application
  alias Mcp.Underwriting.RiskAssessment

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant_id = socket.assigns.current_user.tenant_id
    tenant = Mcp.Platform.Tenant.get_by_id!(tenant_id)

    application = Application.get_by_id!(id, load: [:merchant, :documents], tenant: tenant.company_schema)
    
    # Try to fetch risk assessment if it exists
    risk_assessment = 
      case RiskAssessment.read(tenant: tenant.company_schema) do
        {:ok, assessments} -> 
          Enum.find(assessments, fn r -> r.application_id == id end)
        _ -> nil
      end

    {:ok,
     socket
     |> assign(:page_title, "Review Application")
     |> assign(:tenant, tenant)
     |> assign(:application, application)
     |> assign(:risk_assessment, risk_assessment)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto">
      <!-- Header / Actions -->
      <div class="flex justify-between items-start mb-8">
        <div>
          <.link navigate={~p"/admin/underwriting"} class="text-sm hover:underline mb-2 block text-zinc-500">
            &larr; Back to Queue
          </.link>
          <h1 class="text-3xl font-bold text-zinc-900 dark:text-zinc-100">
            <%= @application.application_data["business_name"] %>
          </h1>
          <div class="flex items-center gap-2 mt-2">
            <span class={"badge #{status_badge_color(@application.status)} badge-lg"}>
              <%= Phoenix.Naming.humanize(@application.status) %>
            </span>
            <span class="text-zinc-500 text-sm">
              ID: <%= @application.id %>
            </span>
          </div>
        </div>
        
        <div class="flex gap-3">
          <button phx-click="reject" class="btn btn-error btn-outline" disabled={@application.status in [:approved, :rejected]}>
            Reject
          </button>
          <button phx-click="request_info" class="btn btn-warning btn-outline" disabled={@application.status in [:approved, :rejected]}>
            Request Info
          </button>
          <button phx-click="approve" class="btn btn-success" disabled={@application.status in [:approved, :rejected]}>
            Approve Application
          </button>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- Left Column: Application Data -->
        <div class="lg:col-span-2 space-y-6">
          <div class="card bg-base-100 shadow-lg border border-base-200">
            <div class="card-body">
              <h2 class="card-title text-lg mb-4">Business Details</h2>
              <dl class="grid grid-cols-1 sm:grid-cols-2 gap-x-4 gap-y-6">
                <div>
                  <dt class="text-sm font-medium text-zinc-500">Legal Name</dt>
                  <dd class="mt-1 text-sm text-zinc-900 dark:text-zinc-100"><%= @application.application_data["business_name"] %></dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-zinc-500">DBA Name</dt>
                  <dd class="mt-1 text-sm text-zinc-900 dark:text-zinc-100"><%= @application.application_data["dba_name"] || "-" %></dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-zinc-500">Entity Type</dt>
                  <dd class="mt-1 text-sm text-zinc-900 dark:text-zinc-100"><%= @application.application_data["business_type"] %></dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-zinc-500">EIN</dt>
                  <dd class="mt-1 text-sm text-zinc-900 dark:text-zinc-100"><%= @application.application_data["ein"] %></dd>
                </div>
              </dl>
            </div>
          </div>

          <div class="card bg-base-100 shadow-lg border border-base-200">
            <div class="card-body">
              <h2 class="card-title text-lg mb-4">Contact Information</h2>
              <dl class="grid grid-cols-1 sm:grid-cols-2 gap-x-4 gap-y-6">
                <div>
                  <dt class="text-sm font-medium text-zinc-500">Email</dt>
                  <dd class="mt-1 text-sm text-zinc-900 dark:text-zinc-100"><%= @application.application_data["email"] %></dd>
                </div>
                <div>
                  <dt class="text-sm font-medium text-zinc-500">Phone</dt>
                  <dd class="mt-1 text-sm text-zinc-900 dark:text-zinc-100"><%= @application.application_data["phone"] %></dd>
                </div>
                <div class="sm:col-span-2">
                  <dt class="text-sm font-medium text-zinc-500">Address</dt>
                  <dd class="mt-1 text-sm text-zinc-900 dark:text-zinc-100">
                    <%= @application.application_data["address_line1"] %><br/>
                    <%= @application.application_data["city"] %>, <%= @application.application_data["state"] %> <%= @application.application_data["zip"] %>
                  </dd>
                </div>
              </dl>
            </div>
          </div>


          <div class="card bg-base-100 shadow-lg border border-base-200">
            <div class="card-body">
              <h2 class="card-title text-lg mb-4">Documents</h2>
              <%= if Enum.empty?(@application.documents) do %>
                <p class="text-sm text-zinc-500">No documents uploaded.</p>
              <% else %>
                <ul class="divide-y divide-base-200">
                  <%= for doc <- @application.documents do %>
                    <li class="py-3 flex justify-between items-center">
                      <div class="flex items-center gap-3">
                        <div class="w-8 h-8 rounded bg-base-200 flex items-center justify-center">
                          <.icon name="hero-document" class="w-4 h-4 text-zinc-500" />
                        </div>
                        <div>
                          <p class="text-sm font-medium"><%= doc.file_name %></p>
                          <p class="text-xs text-zinc-500 capitalize"><%= doc.document_type %> &bull; <%= doc.status %></p>
                        </div>
                      </div>
                      <a href={presigned_url(doc.file_path)} target="_blank" class="btn btn-ghost btn-sm">
                        View
                      </a>
                    </li>
                  <% end %>
                </ul>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Right Column: Risk Analysis -->
        <div class="space-y-6">
          <div class="card bg-base-100 shadow-lg border border-base-200">
            <div class="card-body">
              <h2 class="card-title text-lg mb-4">Risk Analysis</h2>
              
              <%= if @risk_assessment do %>
                <div class="flex flex-col items-center mb-6">
                  <div class={"radial-progress text-3xl font-bold #{risk_score_text_color(@risk_assessment.score)}"} style={"--value:#{@risk_assessment.score}; --size:8rem;"}>
                    <%= @risk_assessment.score %>
                  </div>
                  <span class="text-sm text-zinc-500 mt-2">Risk Score</span>
                </div>

                <div class="space-y-4">
                  <div>
                    <h3 class="font-medium text-sm mb-2">Risk Factors</h3>
                    <ul class="space-y-2">
                      <%= for {factor, details} <- @risk_assessment.factors do %>
                        <li class="text-sm bg-base-200 p-2 rounded">
                          <span class="font-semibold capitalize"><%= factor %>:</span> 
                          <%= inspect(details) %>
                        </li>
                      <% end %>
                    </ul>
                  </div>

                  <div>
                    <h3 class="font-medium text-sm mb-2">Recommendation</h3>
                    <div class="alert alert-info text-sm py-2">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-current shrink-0 w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                      <span><%= Phoenix.Naming.humanize(@risk_assessment.recommendation) %></span>
                    </div>
                  </div>
                </div>
              <% else %>
                <div class="alert alert-warning">
                  <span>No risk assessment found.</span>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("approve", _params, socket) do
    # In a real app, we would use a Service/Action to handle this
    Application.update!(socket.assigns.application, %{status: :approved}, tenant: socket.assigns.tenant.company_schema)
    
    {:noreply, 
     socket 
     |> put_flash(:info, "Application approved successfully.")
     |> push_navigate(to: ~p"/admin/underwriting")}
  end

  @impl true
  def handle_event("reject", _params, socket) do
    Application.update!(socket.assigns.application, %{status: :rejected}, tenant: socket.assigns.tenant.company_schema)
    
    {:noreply, 
     socket 
     |> put_flash(:error, "Application rejected.")
     |> push_navigate(to: ~p"/admin/underwriting")}
  end
  
  @impl true
  def handle_event("request_info", _params, socket) do
    Application.update!(socket.assigns.application, %{status: :more_info_required}, tenant: socket.assigns.tenant.company_schema)
    
    {:noreply, 
     socket 
     |> put_flash(:info, "Requested more information from merchant.")
     |> push_navigate(to: ~p"/admin/underwriting")}
  end

  defp status_badge_color(:approved), do: "badge-success"
  defp status_badge_color(:rejected), do: "badge-error"
  defp status_badge_color(:manual_review), do: "badge-warning"
  defp status_badge_color(:under_review), do: "badge-warning"
  defp status_badge_color(:submitted), do: "badge-info"
  defp status_badge_color(_), do: "badge-ghost"

  defp risk_score_text_color(score) when is_nil(score), do: "text-base-content"
  defp risk_score_text_color(score) when score >= 90, do: "text-success"
  defp risk_score_text_color(score) when score >= 70, do: "text-info"
  defp risk_score_text_color(score) when score >= 50, do: "text-warning"
  defp risk_score_text_color(_), do: "text-error"

  defp presigned_url(path) do
    bucket = Elixir.Application.get_env(:mcp, :uploads)[:bucket]
    # Generate a presigned URL valid for 1 hour
    {:ok, url} = 
      ExAws.Config.new(:s3)
      |> ExAws.S3.presigned_url(:get, bucket, path, expires_in: 3600)
    
    url
  end
end
