defmodule McpWeb.Tenant.ReviewLive do
  use McpWeb, :live_view

  alias Mcp.Underwriting.Application
  alias Mcp.Underwriting.RiskAssessment
  alias McpWeb.Tenant.Underwriting.Components.TimelineComponent
  alias McpWeb.Tenant.Underwriting.Components.RequestInfoModal
  alias McpWeb.Tenant.Underwriting.Components.CoPilotChat
  require Ash.Query

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant_id = socket.assigns.current_user.tenant_id
    tenant = Mcp.Platform.Tenant.get_by_id!(tenant_id)

    # Load activities sorted by inserted_at desc
    query = 
      Application 
      |> Ash.Query.load([:merchant, :documents])
      |> Ash.Query.load(activities: Ash.Query.sort(Mcp.Underwriting.Activity, inserted_at: :desc))

    application = Application.get_by_id!(id, query: query, tenant: tenant.company_schema)
    
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
     |> assign(:risk_assessment, risk_assessment)
     |> assign(:show_request_info_modal, false)
     |> assign(:show_copilot, false)
     |> allow_upload(:documents, accept: ~w(.pdf .jpg .jpeg .png), max_entries: 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto">
      <!-- Header / Actions -->
      <div class="flex justify-between items-start mb-8">
        <div>
          <.link navigate={~p"/tenant/underwriting"} class="text-sm hover:underline mb-2 block text-zinc-500">
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
            <%= if @application.sla_due_at do %>
              <div class="ml-4">
                <.live_component module={McpWeb.Tenant.Underwriting.Components.SlaTimer} id="sla-timer" due_at={@application.sla_due_at} />
              </div>
            <% end %>
          </div>
        </div>
        
        <div class="flex gap-2">
          <button phx-click="toggle_copilot" class={"btn #{if @show_copilot, do: "btn-primary", else: "btn-ghost border-zinc-300"}"}>
            <.icon name="hero-sparkles" class="w-5 h-5" />
            Co-Pilot
          </button>
          <button phx-click="approve" class="btn btn-success text-white">Approve Application</button>
          <button phx-click="request_info" class="btn btn-warning">Request More Info</button>
          <button phx-click="reject" class="btn btn-error text-white">Reject</button>
        </div>
      </div>

      <div class="flex gap-6 relative">
        <!-- Main Content Area -->
        <div class={"transition-all duration-300 ease-in-out #{if @show_copilot, do: "w-2/3", else: "w-full"}"}>
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Main Content -->
        <div class="lg:col-span-2 space-y-6">
          <!-- Application Data -->
          <div class="card bg-base-100 shadow-lg border border-base-200">
            <div class="card-body">
              <h2 class="card-title text-lg mb-4">Application Details</h2>
              
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="label text-xs text-zinc-500 uppercase font-bold">Business Type</label>
                  <p><%= @application.application_data["business_type"] %></p>
                </div>
                <div>
                  <label class="label text-xs text-zinc-500 uppercase font-bold">Annual Volume</label>
                  <p><%= @application.application_data["annual_volume"] %></p>
                </div>
                <div>
                  <label class="label text-xs text-zinc-500 uppercase font-bold">Website</label>
                  <p class="text-primary truncate"><%= @application.application_data["website"] %></p>
                </div>
                <div>
                  <label class="label text-xs text-zinc-500 uppercase font-bold">Contact Email</label>
                  <p><%= @application.application_data["contact_email"] %></p>
                </div>
              </div>
            </div>
          </div>

          <!-- Documents -->
          <div class="card bg-base-100 shadow-lg border border-base-200">
            <div class="card-body">
              <h2 class="card-title text-lg mb-4">Documents</h2>
              
              <%= if Enum.empty?(@application.documents) do %>
                <p class="text-zinc-500 italic">No documents uploaded.</p>
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
                          <p class="text-xs text-zinc-500 capitalize">
                            <%= doc.document_type %> &bull; 
                            <span class={doc_status_color(doc.status)}><%= doc.status %></span>
                          </p>
                        </div>
                      </div>
                      <div class="flex items-center gap-2">
                        <button phx-click="verify_document" phx-value-id={doc.id} class="btn btn-xs btn-success btn-outline" disabled={doc.status == :verified} title="Verify Document">
                          <.icon name="hero-check" class="w-3 h-3" />
                        </button>
                        <button phx-click="reject_document" phx-value-id={doc.id} class="btn btn-xs btn-error btn-outline" disabled={doc.status == :rejected} title="Reject Document">
                          <.icon name="hero-x-mark" class="w-3 h-3" />
                        </button>
                        <a href={presigned_url(doc.file_path)} target="_blank" class="btn btn-ghost btn-sm">
                          View
                        </a>
                      </div>
                    </li>
                  <% end %>
                </ul>
              <% end %>
              
              <div class="mt-4 pt-4 border-t border-base-200">
                <form phx-submit="save" phx-change="validate">
                  <div class="form-control w-full max-w-xs">
                    <label class="label">
                      <span class="label-text">Upload Document</span>
                    </label>
                    <.live_file_input upload={@uploads.documents} class="file-input file-input-bordered w-full max-w-xs" />
                  </div>
                  <button type="submit" class="btn btn-primary btn-sm mt-2" disabled={Enum.empty?(@uploads.documents.entries)}>Upload</button>
                </form>
              </div>
            </div>
          </div>
        </div>

        <!-- Sidebar -->
        <div class="space-y-6">
          <!-- Risk Score -->
          <div class="card bg-base-100 shadow-lg border border-base-200">
            <div class="card-body">
              <h2 class="card-title text-lg mb-4">Risk Assessment</h2>
              
              <div class="flex items-center justify-between mb-4">
                <span class="text-zinc-500">Risk Score</span>
                <span class={["text-2xl font-bold", risk_score_text_color(@application.risk_score)]}>
                  <%= @application.risk_score %>/100
                </span>
              </div>
              
              <div class="w-full bg-base-200 rounded-full h-2.5 mb-4">
                <div class={["h-2.5 rounded-full", risk_score_color(@application.risk_score)]} style={"width: #{@application.risk_score}%"}></div>
              </div>
              
              <%= if @risk_assessment do %>
                <div class="text-sm space-y-2">
                  <p class="font-medium">Flags:</p>
                  <ul class="list-disc list-inside text-zinc-600">
                    <%= for flag <- @risk_assessment.flags do %>
                      <li><%= flag %></li>
                    <% end %>
                  </ul>
                </div>
              <% end %>
            </div>
          </div>

          <div class="card bg-base-100 shadow-lg border border-base-200 mb-6">
            <div class="card-body">
              <h2 class="card-title text-lg mb-4">Internal Notes</h2>
              <form phx-submit="add_note">
                <div class="form-control">
                  <textarea name="note" class="textarea textarea-bordered h-24" placeholder="Add an internal note..." required></textarea>
                </div>
                <div class="card-actions justify-end mt-2">
                  <button class="btn btn-sm btn-primary">Add Note</button>
                </div>
              </form>
            </div>
          </div>

          <.live_component 
            module={TimelineComponent} 
            id="timeline" 
            activities={@application.activities} 
          />
        </div>
      </div>
      </div>
      </div>

      <!-- Co-Pilot Sidebar -->
      <div class={"fixed top-0 right-0 h-screen w-1/3 z-50 transform transition-transform duration-300 ease-in-out #{if @show_copilot, do: "translate-x-0", else: "translate-x-full"}"}>
        <%= if @show_copilot do %>
          <.live_component 
            module={CoPilotChat} 
            id="copilot-chat" 
            application_id={@application.id}
            current_user={@current_user}
          />
        <% end %>
      </div>
      
      <%= if @show_request_info_modal do %>
        <.live_component module={RequestInfoModal} id="request-info-modal" />
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("approve", _params, socket) do
    tenant = socket.assigns.tenant.company_schema
    app = socket.assigns.application
    
    # Update Status
    {:ok, _updated_app} = Application.update(app, %{status: :approved}, tenant: tenant)
    
    # Log Activity
    Mcp.Underwriting.Activity
    |> Ash.Changeset.for_create(:create, %{
      type: :status_change,
      application_id: app.id,
      actor_id: socket.assigns.current_user.id,
      metadata: %{
        from: app.status,
        to: :approved,
        reason: "Manual Approval"
      }
    })
    |> Ash.create!(tenant: tenant)
    
    {:noreply, 
     socket 
     |> put_flash(:info, "Application approved successfully.")
     |> push_navigate(to: ~p"/tenant/underwriting")}
  end

  @impl true
  def handle_event("reject", _params, socket) do
    tenant = socket.assigns.tenant.company_schema
    app = socket.assigns.application
    
    # Update Status
    {:ok, _updated_app} = Application.update(app, %{status: :rejected}, tenant: tenant)
    
    # Log Activity
    Mcp.Underwriting.Activity
    |> Ash.Changeset.for_create(:create, %{
      type: :status_change,
      application_id: app.id,
      actor_id: socket.assigns.current_user.id,
      metadata: %{
        from: app.status,
        to: :rejected,
        reason: "Manual Rejection"
      }
    })
    |> Ash.create!(tenant: tenant)
    
    {:noreply, 
     socket 
     |> put_flash(:error, "Application rejected.")
     |> push_navigate(to: ~p"/tenant/underwriting")}
  end
  
  @impl true
  def handle_event("request_info", _params, socket) do
    {:noreply, assign(socket, :show_request_info_modal, true)}
  end
  


  @impl true
  def handle_event("verify_document", %{"id" => doc_id}, socket) do
    tenant = socket.assigns.tenant.company_schema
    
    Mcp.Underwriting.Document
    |> Ash.Query.filter(id == ^doc_id)
    |> Ash.read_one!(tenant: tenant)
    |> Mcp.Underwriting.Document.update_status(%{status: :verified}, tenant: tenant)

    # Refresh application to show updated status
    {:noreply, refresh_application(socket)}
  end

  @impl true
  def handle_event("reject_document", %{"id" => doc_id}, socket) do
    tenant = socket.assigns.tenant.company_schema
    
    Mcp.Underwriting.Document
    |> Ash.Query.filter(id == ^doc_id)
    |> Ash.read_one!(tenant: tenant)
    |> Mcp.Underwriting.Document.update_status(%{status: :rejected}, tenant: tenant)

    # Refresh application
    {:noreply, refresh_application(socket)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :documents, fn %{path: path}, entry ->
        file_name = entry.client_name
        mime_type = entry.client_type
        
        # Upload to S3 (Mock for now or use ExAws)
        bucket = Elixir.Application.get_env(:mcp, :uploads)[:bucket]
        s3_path = "applications/#{socket.assigns.application.id}/#{file_name}"
        
        # Read file content
        file_content = File.read!(path)
        
        ExAws.S3.put_object(bucket, s3_path, file_content)
        |> ExAws.request!()
        
        # Create Document Record
        Mcp.Underwriting.Document
        |> Ash.Changeset.for_create(:create, %{
          file_path: s3_path,
          file_name: file_name,
          mime_type: mime_type,
          document_type: :other,
          application_id: socket.assigns.application.id
        })
        |> Ash.create!(tenant: socket.assigns.tenant.company_schema)
        
        {:ok, s3_path}
      end)

    {:noreply, 
     socket 
     |> put_flash(:info, "Uploaded #{length(uploaded_files)} documents.")
     |> refresh_application()}
  end

  @impl true
  def handle_event("add_note", %{"note" => note}, socket) do
    tenant = socket.assigns.tenant.company_schema
    app = socket.assigns.application
    
    Mcp.Underwriting.Activity
    |> Ash.Changeset.for_create(:create, %{
      type: :internal_note,
      application_id: app.id,
      actor_id: socket.assigns.current_user.id,
      metadata: %{
        note: note
      }
    })
    |> Ash.create!(tenant: tenant)
    
    {:noreply, 
     socket 
     |> put_flash(:info, "Note added.")
     |> refresh_application()}
  end

  @impl true
  def handle_event("toggle_copilot", _, socket) do
    {:noreply, update(socket, :show_copilot, &(!&1))}
  end

  @impl true
  def handle_info(:close_modal, socket) do
    {:noreply, assign(socket, :show_request_info_modal, false)}
  end

  @impl true
  def handle_info({:toggle_copilot}, socket) do
    {:noreply, update(socket, :show_copilot, &(!&1))}
  end

  @impl true
  def handle_info({:confirm_request_info, reason, document_type}, socket) do
    tenant = socket.assigns.tenant.company_schema
    app = socket.assigns.application
    
    # Update Status
    {:ok, _updated_app} = Application.update(app, %{status: :more_info_required}, tenant: tenant)
    
    # Log Activity
    Mcp.Underwriting.Activity
    |> Ash.Changeset.for_create(:create, %{
      type: :status_change,
      application_id: app.id,
      actor_id: socket.assigns.current_user.id,
      metadata: %{
        from: app.status,
        to: :more_info_required,
        reason: reason,
        document_type: document_type
      }
    })
    |> Ash.create!(tenant: tenant)
    
    # Send message to Merchant Portal via Atlas (Chat)
    contact_email = app.application_data["contact_email"]
    
    if contact_email do
      case Mcp.Accounts.User.by_email(contact_email) do
        {:ok, user} ->
          # Find or create conversation
          conversation = 
            Mcp.Chat.Conversation
            |> Ash.Query.filter(user_id == ^user.id)
            |> Ash.Query.sort(updated_at: :desc)
            |> Ash.Query.limit(1)
            |> Ash.read_one!(not_found_error?: false)
            
          conversation = 
            if conversation do
              conversation
            else
              Mcp.Chat.Conversation
              |> Ash.Changeset.for_create(:create_for_user, %{title: "Application Support", user_id: user.id})
              |> Ash.create!()
            end
            
          # Construct Message Text
          message_text = 
            if document_type && document_type != "" do
              doc_label = Phoenix.Naming.humanize(document_type)
              "SYSTEM NOTIFICATION: Please upload your **#{doc_label}**. Reason: #{reason}"
            else
              "SYSTEM NOTIFICATION: Action Required - #{reason}"
            end
            
          # Create message
          Mcp.Chat.Message
          |> Ash.Changeset.for_create(:create, %{
            text: message_text,
            conversation_id: conversation.id
          })
          |> Ash.Changeset.force_change_attribute(:source, :agent)
          |> Ash.create!()
          
        _ ->
          # Fallback if user not found (shouldn't happen in Reg-First flow)
          nil
      end
    end

    {:noreply, 
     socket 
     |> assign(:show_request_info_modal, false)
     |> put_flash(:info, "Requested more information from merchant.")
     |> push_navigate(to: ~p"/tenant/underwriting")}
  end

  defp refresh_application(socket) do
    tenant = socket.assigns.tenant
    id = socket.assigns.application.id
    
    query = 
      Application 
      |> Ash.Query.load([:merchant, :documents])
      |> Ash.Query.load(activities: Ash.Query.sort(Mcp.Underwriting.Activity, inserted_at: :desc))

    application = Application.get_by_id!(id, query: query, tenant: tenant.company_schema)
    
    assign(socket, :application, application)
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

  defp risk_score_color(score) when is_nil(score), do: "bg-base-300"
  defp risk_score_color(score) when score >= 90, do: "bg-success"
  defp risk_score_color(score) when score >= 70, do: "bg-info"
  defp risk_score_color(score) when score >= 50, do: "bg-warning"
  defp risk_score_color(_), do: "bg-error"

  defp doc_status_color(:verified), do: "text-success font-bold"
  defp doc_status_color(:rejected), do: "text-error font-bold"
  defp doc_status_color(_), do: "text-zinc-500"

  defp presigned_url(path) do
    bucket = Elixir.Application.get_env(:mcp, :uploads)[:bucket]
    # Generate a presigned URL valid for 1 hour
    {:ok, url} = 
      ExAws.Config.new(:s3)
      |> ExAws.S3.presigned_url(:get, bucket, path, expires_in: 3600)
    
    url
  end
end
