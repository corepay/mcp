defmodule McpWeb.Tenant.ReviewLive do
  use McpWeb, :live_view

  alias Mcp.Accounts.User
  alias Mcp.Chat.{Conversation, Message}
  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.{Activity, Application, Document, DocumentAnalysis, RiskAssessment}
  alias Mcp.Underwriting.Services.{BoardingService, PlacementIntelligence, PrecedentEngine}

  alias McpWeb.Tenant.Underwriting.Components.{
    CoPilotChat,
    NotesPanel,
    RequestInfoModal,
    TimelineComponent
  }

  require Ash.Query

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant_id = socket.assigns.current_user.tenant_id
    tenant = Tenant.get_by_id!(tenant_id)
    tenant_schema = tenant.company_schema

    # Load activities sorted by inserted_at desc
    query =
      Application
      |> Ash.Query.load([:merchant, :documents])
      |> Ash.Query.load(activities: Ash.Query.sort(Activity, inserted_at: :desc))

    application = Application.get_by_id!(id, query: query, tenant: tenant_schema)

    # Fetch risk assessment linked to this application
    risk_assessment =
      RiskAssessment
      |> Ash.Query.filter(application_id == ^id)
      |> Ash.read_one(tenant: tenant_schema)
      |> case do
        {:ok, ra} -> ra
        _ -> nil
      end

    # Load forensics (DocumentAnalysis)
    merchant_id = application.subject_id

    document_analyses =
      DocumentAnalysis
      |> Ash.Query.filter(merchant_id == ^merchant_id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!(tenant: tenant_schema)

    # Harvest precedents (Decision Graph)
    precedents = PrecedentEngine.harvest(merchant_id, tenant_schema)

    # Suggested Placement (Sprint 5)
    placement_result =
      if risk_assessment do
        case PlacementIntelligence.suggest_placement(
               application.id,
               risk_assessment.id,
               tenant_schema
             ) do
          {:ok, result} -> result
          _ -> nil
        end
      else
        nil
      end

    # Load team members for @mention functionality in notes
    team_members = load_team_members(tenant_id)

    {:ok,
     socket
     |> assign(:page_title, "Review Application")
     |> assign(:tenant, tenant)
     |> assign(:application, application)
     |> assign(:risk_assessment, risk_assessment)
     |> assign(:document_analyses, document_analyses)
     |> assign(:precedents, precedents)
     |> assign(:placement_result, placement_result)
     |> assign(:team_members, team_members)
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
          <.link
            navigate={~p"/tenant/underwriting"}
            class="text-sm hover:underline mb-2 block text-zinc-500"
          >
            &larr; Back to Queue
          </.link>
          <h1 class="text-3xl font-bold text-zinc-900 dark:text-zinc-100">
            {@application.application_data["business_name"]}
          </h1>
          <div class="flex items-center gap-2 mt-2">
            <span class={"badge #{status_badge_color(@application.status)} badge-lg"}>
              {Phoenix.Naming.humanize(@application.status)}
            </span>
            <span class="text-zinc-500 text-sm">
              ID: {@application.id}
            </span>
            <%= if @application.sla_due_at do %>
              <div class="ml-4">
                <.live_component
                  module={McpWeb.Tenant.Underwriting.Components.SlaTimer}
                  id="sla-timer"
                  due_at={@application.sla_due_at}
                />
              </div>
            <% end %>
          </div>
        </div>

        <div class="flex gap-2">
          <button
            phx-click="toggle_copilot"
            class={"btn #{if @show_copilot, do: "btn-primary", else: "btn-ghost border-zinc-300"}"}
          >
            <.icon name="hero-sparkles" class="w-5 h-5" /> Co-Pilot
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
                      <label class="label text-xs text-zinc-500 uppercase font-bold">
                        Business Type
                      </label>
                      <p>{@application.application_data["business_type"]}</p>
                    </div>
                    <div>
                      <label class="label text-xs text-zinc-500 uppercase font-bold">
                        Annual Volume
                      </label>
                      <p>{@application.application_data["annual_volume"]}</p>
                    </div>
                    <div>
                      <label class="label text-xs text-zinc-500 uppercase font-bold">Website</label>
                      <p class="text-primary truncate">{@application.application_data["website"]}</p>
                    </div>
                    <div>
                      <label class="label text-xs text-zinc-500 uppercase font-bold">
                        Contact Email
                      </label>
                      <p>{@application.application_data["contact_email"]}</p>
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
                              <p class="text-sm font-medium">{doc.file_name}</p>
                              <p class="text-xs text-zinc-500 capitalize">
                                {doc.document_type} &bull;
                                <span class={doc_status_color(doc.status)}>{doc.status}</span>
                              </p>
                            </div>
                          </div>
                          <div class="flex items-center gap-2">
                            <button
                              phx-click="verify_document"
                              phx-value-id={doc.id}
                              class="btn btn-xs btn-success btn-outline"
                              disabled={doc.status == :verified}
                              title="Verify Document"
                            >
                              <.icon name="hero-check" class="w-3 h-3" />
                            </button>
                            <button
                              phx-click="reject_document"
                              phx-value-id={doc.id}
                              class="btn btn-xs btn-error btn-outline"
                              disabled={doc.status == :rejected}
                              title="Reject Document"
                            >
                              <.icon name="hero-x-mark" class="w-3 h-3" />
                            </button>
                            <a
                              href={presigned_url(doc.file_path)}
                              target="_blank"
                              class="btn btn-ghost btn-sm"
                            >
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
                        <.live_file_input
                          upload={@uploads.documents}
                          class="file-input file-input-bordered w-full max-w-xs"
                        />
                      </div>
                      <button
                        type="submit"
                        class="btn btn-primary btn-sm mt-2"
                        disabled={Enum.empty?(@uploads.documents.entries)}
                      >
                        Upload
                      </button>
                    </form>
                  </div>
                </div>
              </div>
              
    <!-- Forensics & Intelligence -->
              <div class="card bg-base-100 shadow-lg border border-base-200">
                <div class="card-body">
                  <h2 class="card-title text-lg mb-4 flex items-center gap-2">
                    <.icon name="hero-magnifying-glass-circle" class="w-5 h-5 text-primary" />
                    Forensics & Multimodal Intelligence
                  </h2>

                  <%= if Enum.empty?(@document_analyses) do %>
                    <p class="text-zinc-500 italic">No forensic analysis performed yet.</p>
                  <% else %>
                    <div class="space-y-4">
                      <%= for analysis <- @document_analyses do %>
                        <div class="p-4 rounded-lg bg-base-200/50 border border-base-300">
                          <div class="flex justify-between items-start mb-2">
                            <div>
                              <span class="badge badge-sm badge-outline uppercase font-bold text-[10px]">
                                {analysis.analysis_type}
                              </span>
                              <p class="text-xs text-zinc-500 mt-1">
                                {Calendar.strftime(analysis.inserted_at, "%Y-%m-%d %H:%M")}
                              </p>
                            </div>
                            <%= if analysis.forensics_report["manipulation_detected"] do %>
                              <span class="badge badge-error gap-1 text-white">
                                <.icon name="hero-exclamation-triangle" class="w-3 h-3" /> SUSPECT
                              </span>
                            <% else %>
                              <span class="badge badge-success gap-1 text-white">
                                <.icon name="hero-check-badge" class="w-3 h-3" /> AUTHENTIC
                              </span>
                            <% end %>
                          </div>

                          <div class="grid grid-cols-2 gap-4 text-xs">
                            <div>
                              <p class="text-zinc-500 font-bold uppercase">Device</p>
                              <p>{analysis.camera_telemetry["device"] || "N/A"}</p>
                            </div>
                            <div>
                              <p class="text-zinc-500 font-bold uppercase">Liveness Verified</p>
                              <p class={
                                if analysis.camera_telemetry["verified"],
                                  do: "text-success font-bold",
                                  else: "text-error"
                              }>
                                {if analysis.camera_telemetry["verified"], do: "YES", else: "NO"}
                              </p>
                            </div>
                          </div>

                          <%= if analysis.forensics_report["findings"] && Enum.any?(analysis.forensics_report["findings"]) do %>
                            <div class="mt-2 pt-2 border-t border-base-300">
                              <p class="text-[10px] text-zinc-500 font-bold uppercase mb-1">
                                AI Analyst Findings
                              </p>
                              <ul class="text-[11px] list-disc list-inside">
                                <%= for finding <- analysis.forensics_report["findings"] do %>
                                  <li>{finding}</li>
                                <% end %>
                              </ul>
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
              
    <!-- Decision Lineage -->
              <div class="card bg-base-100 shadow-lg border border-base-200">
                <div class="card-body">
                  <h2 class="card-title text-lg mb-4 flex items-center gap-2">
                    <.icon name="hero-fingerprint" class="w-5 h-5 text-indigo-500" />
                    Decision Lineage & Attribution
                  </h2>

                  <%= if @risk_assessment && @risk_assessment.policy_hash do %>
                    <div class="space-y-4">
                      <div>
                        <p class="text-xs text-zinc-500 font-bold uppercase mb-1">
                          Playbook Fingerprint (SHA-256)
                        </p>
                        <code class="text-[10px] break-all bg-base-200 p-1 rounded font-mono">
                          {@risk_assessment.policy_hash}
                        </code>
                      </div>

                      <div>
                        <p class="text-xs text-zinc-500 font-bold uppercase mb-1">Rule Factors</p>
                        <div class="flex flex-wrap gap-2">
                          <%= for {factor, score} <- @risk_assessment.factors do %>
                            <div class="badge badge-ghost badge-sm gap-2">
                              {factor}: <span class="font-bold">{score}</span>
                            </div>
                          <% end %>
                        </div>
                      </div>

                      <div class="p-3 bg-indigo-50 dark:bg-indigo-900/20 border border-indigo-100 dark:border-indigo-800 rounded-lg">
                        <p class="text-xs text-indigo-700 dark:text-indigo-300 italic">
                          "This decision was automatically generated using the active underwriting playbook. The immutable hash ensures auditability and non-repudiation."
                        </p>
                      </div>
                    </div>
                  <% else %>
                    <p class="text-zinc-500 italic">
                      No automated lineage captured for this session.
                    </p>
                  <% end %>
                </div>
              </div>
              <!-- Placement Intelligence (Sprint 5) -->
              <div class="card bg-base-100 shadow-lg border border-base-200">
                <div class="card-body">
                  <h2 class="card-title text-lg mb-4 flex items-center gap-2">
                    <.icon name="hero-building-library" class="w-5 h-5 text-amber-500" />
                    Placement Intelligence
                  </h2>

                  <%= if @placement_result do %>
                    <div class="bg-amber-50 dark:bg-amber-900/10 p-4 rounded-lg border border-amber-100 dark:border-amber-800">
                      <div class="flex justify-between items-center mb-2">
                        <span class="text-xs font-bold uppercase text-amber-900 dark:text-amber-100">
                          Recommended Bank
                        </span>
                        <span class="badge badge-warning">High Compatibility</span>
                      </div>
                      <p class="text-lg font-bold text-zinc-900 dark:text-zinc-100">
                        {@placement_result.profile.name}
                      </p>
                      <p class="text-xs text-zinc-500 mt-1">
                        Processor: {@placement_result.profile.processor.name}
                      </p>

                      <div class="mt-4 pt-4 border-t border-amber-200 dark:border-amber-800">
                        <p class="text-[10px] text-zinc-500 font-bold uppercase mb-2">
                          Appetite Match Highlights
                        </p>
                        <ul class="text-xs space-y-1">
                          <li class="flex items-center gap-2">
                            <.icon name="hero-check" class="w-3 h-3 text-success" /> Industry Accepted
                          </li>
                          <li class="flex items-center gap-2">
                            <.icon name="hero-check" class="w-3 h-3 text-success" />
                            Score within threshold
                          </li>
                          <li class="flex items-center gap-2">
                            <.icon name="hero-check" class="w-3 h-3 text-success" />
                            Volume appetite verified
                          </li>
                        </ul>
                      </div>
                    </div>

                    <button
                      class="btn btn-warning btn-block mt-4 text-white"
                      phx-click="initialize_boarding"
                    >
                      Initialize Boarding
                    </button>
                  <% else %>
                    <div class="p-4 text-center rounded-lg border-2 border-dashed border-base-300">
                      <p class="text-zinc-500 text-sm italic">
                        No optimal bank placement found for this risk profile.
                      </p>
                    </div>
                  <% end %>
                </div>
              </div>
              
    <!-- Context Graph: Precedents -->
              <div class="card bg-base-100 shadow-lg border border-base-200">
                <div class="card-body">
                  <h2 class="card-title text-lg mb-4 flex items-center gap-2">
                    <.icon name="hero-share" class="w-5 h-5 text-emerald-500" />
                    Context Graph: Precedents
                  </h2>

                  <div class="bg-emerald-50 dark:bg-emerald-900/10 p-4 rounded-lg border border-emerald-100 dark:border-emerald-800">
                    <pre class="text-[11px] whitespace-pre-wrap font-mono text-emerald-900 dark:text-emerald-100">{@precedents}</pre>
                  </div>
                  <p class="text-[10px] text-zinc-500 mt-2 italic">
                    AI-harvested context from historical merchant behavior and past underwriting outcomes.
                  </p>
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
                    <span class={[
                      "text-2xl font-bold",
                      risk_score_text_color(@application.risk_score)
                    ]}>
                      {@application.risk_score}/100
                    </span>
                  </div>

                  <div class="w-full bg-base-200 rounded-full h-2.5 mb-4">
                    <div
                      class={["h-2.5 rounded-full", risk_score_color(@application.risk_score)]}
                      style={"width: #{@application.risk_score}%"}
                    >
                    </div>
                  </div>

                  <%= if @risk_assessment do %>
                    <div class="text-sm space-y-2">
                      <p class="font-medium">Flags:</p>
                      <ul class="list-disc list-inside text-zinc-600">
                        <%= for flag <- @risk_assessment.flags do %>
                          <li>{flag}</li>
                        <% end %>
                      </ul>
                    </div>
                  <% end %>
                </div>
              </div>

              <%!-- Notes Panel with @mention support --%>
              <.live_component
                module={NotesPanel}
                id="notes-panel"
                application_id={@application.id}
                current_user={@current_user}
                tenant_schema={@tenant.company_schema}
                team_members={@team_members}
              />

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
  def handle_event("initialize_boarding", _params, socket) do
    tenant_schema = socket.assigns.tenant.company_schema
    app = socket.assigns.application
    placement = socket.assigns.placement_result
    actor = socket.assigns.current_user

    case BoardingService.board(app.id, placement.profile.id, tenant_schema,
           rationale: placement.rationale,
           actor: actor
         ) do
      {:ok, result} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Merchant successfully boarded! MID: #{result.mid || "Pending approval"}"
         )
         |> push_navigate(to: ~p"/tenant/underwriting")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Boarding failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("approve", _params, socket) do
    tenant = socket.assigns.tenant.company_schema
    app = socket.assigns.application

    # Update Status
    {:ok, _updated_app} = Application.update(app, %{status: :approved}, tenant: tenant)

    # Log Activity
    Activity
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
    Activity
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

    Document
    |> Ash.Query.filter(id == ^doc_id)
    |> Ash.read_one!(tenant: tenant)
    |> Document.update_status(%{status: :verified}, tenant: tenant)

    # Refresh application to show updated status
    {:noreply, refresh_application(socket)}
  end

  @impl true
  def handle_event("reject_document", %{"id" => doc_id}, socket) do
    tenant = socket.assigns.tenant.company_schema

    Document
    |> Ash.Query.filter(id == ^doc_id)
    |> Ash.read_one!(tenant: tenant)
    |> Document.update_status(%{status: :rejected}, tenant: tenant)

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
        Document
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

    Activity
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

  # Handle SLA timer tick for real-time countdown updates
  @impl true
  def handle_info({:update_sla_timer, component_id}, socket) do
    send_update(McpWeb.Tenant.Underwriting.Components.SlaTimer, id: component_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:confirm_request_info, reason, document_type}, socket) do
    tenant = socket.assigns.tenant.company_schema
    app = socket.assigns.application

    # Update Status
    {:ok, _updated_app} = Application.update(app, %{status: :more_info_required}, tenant: tenant)

    # Log Activity
    log_status_change(
      app,
      :more_info_required,
      reason,
      document_type,
      socket.assigns.current_user.id,
      tenant
    )

    # Send message to Merchant Portal via Atlas (Chat)
    contact_email = app.application_data["contact_email"]

    if contact_email do
      send_request_info_message(contact_email, reason, document_type)
    end

    {:noreply,
     socket
     |> assign(:show_request_info_modal, false)
     |> put_flash(:info, "Requested more information from merchant.")
     |> push_navigate(to: ~p"/tenant/underwriting")}
  end

  defp log_status_change(app, new_status, reason, document_type, actor_id, tenant) do
    Activity
    |> Ash.Changeset.for_create(:create, %{
      type: :status_change,
      application_id: app.id,
      actor_id: actor_id,
      metadata: %{
        from: app.status,
        to: new_status,
        reason: reason,
        document_type: document_type
      }
    })
    |> Ash.create!(tenant: tenant)
  end

  defp send_request_info_message(contact_email, reason, document_type) do
    case User.by_email(contact_email) do
      {:ok, user} ->
        conversation = find_or_create_conversation(user)
        message_text = build_request_info_message(reason, document_type)

        create_system_message(conversation.id, message_text)

      _ ->
        nil
    end
  end

  defp find_or_create_conversation(user) do
    existing =
      Conversation
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.Query.sort(updated_at: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read_one!(not_found_error?: false)

    existing || create_support_conversation(user)
  end

  defp create_support_conversation(user) do
    Mcp.Chat.Conversation
    |> Ash.Changeset.for_create(:create_for_user, %{
      title: "Application Support",
      user_id: user.id
    })
    |> Ash.create!()
  end

  defp build_request_info_message(reason, document_type) do
    if document_type && document_type != "" do
      doc_label = Phoenix.Naming.humanize(document_type)
      "SYSTEM NOTIFICATION: Please upload your **#{doc_label}**. Reason: #{reason}"
    else
      "SYSTEM NOTIFICATION: Action Required - #{reason}"
    end
  end

  defp create_system_message(conversation_id, text) do
    Message
    |> Ash.Changeset.for_create(:create, %{
      text: text,
      conversation_id: conversation_id
    })
    |> Ash.Changeset.force_change_attribute(:source, :agent)
    |> Ash.create!()
  end

  defp refresh_application(socket) do
    tenant = socket.assigns.tenant
    id = socket.assigns.application.id

    query =
      Application
      |> Ash.Query.load([:merchant, :documents])
      |> Ash.Query.load(activities: Ash.Query.sort(Activity, inserted_at: :desc))

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

  defp load_team_members(tenant_id) do
    case Ash.read(Ash.Query.filter(User, tenant_id == ^tenant_id and status == :active)) do
      {:ok, users} ->
        Enum.map(users, fn user ->
          %{
            id: user.id,
            username: user.email |> String.split("@") |> hd(),
            display_name: build_display_name(user)
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp build_display_name(user) do
    name =
      [user.first_name, user.last_name]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
      |> String.trim()

    if name == "", do: user.email, else: name
  end
end
