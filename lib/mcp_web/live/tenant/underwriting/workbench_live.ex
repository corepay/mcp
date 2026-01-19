defmodule McpWeb.Tenant.Underwriting.WorkbenchLive do
  use McpWeb, :live_view

  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.Activity
  alias Mcp.Underwriting.Application, as: UWApplication
  alias Mcp.Underwriting.Engine.AnalyzeApplication
  alias Mcp.Underwriting.RiskAssessment

  require Ash.Query

  @impl true
  def mount(params, session, socket) do
    tenant_id = session["tenant_id"] || (socket.assigns[:current_context] || %{})[:tenant_id]

    case validate_tenant(tenant_id, socket) do
      {:error, socket} ->
        {:ok, socket}

      {:ok, tenant} ->
        initialize_workbench(params, tenant, socket)
    end
  end

  defp validate_tenant(nil, socket) do
    {:error,
     socket
     |> put_flash(:error, "No active tenant context. Please sign in via your tenant subdomain.")
     |> redirect(to: "/")}
  end

  defp validate_tenant(tenant_id, _socket), do: {:ok, Tenant.get_by_id!(tenant_id)}

  defp initialize_workbench(params, tenant, socket) do
    tenant_schema = tenant.company_schema

    # Load Queue
    applications = load_applications(tenant_schema)

    # Selected Application
    application_id = params["id"] || (List.first(applications) && List.first(applications).id)
    application = load_application(application_id, tenant_schema)

    if params["id"] && is_nil(application) do
      {:ok,
       socket
       |> put_flash(:info, "The requested application no longer exists.")
       |> redirect(to: ~p"/tenant/underwriting")}
    else
      risk_assessment = load_risk_assessment(application, tenant_schema)

      {:ok,
       socket
       |> assign(:page_title, "Underwriting Workbench")
       |> assign(:tenant, tenant)
       |> assign(:applications, applications)
       |> assign(:application, application)
       |> assign(:risk_assessment, risk_assessment)
       |> assign(:active_tab, "APPLICATION")
       |> assign(:show_queue, true)
       |> assign(:show_brief, true)
       |> assign(:scanning, false)}
    end
  end

  defp load_applications(tenant_schema) do
    UWApplication
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(tenant: tenant_schema)
  end

  defp load_application(nil, _), do: nil

  defp load_application(id, tenant_schema) do
    case UWApplication.get_by_id(id, load: [:documents, :activities], tenant: tenant_schema) do
      {:ok, app} -> app
      _ -> nil
    end
  end

  defp load_risk_assessment(nil, _), do: nil

  defp load_risk_assessment(application, tenant_schema) do
    RiskAssessment
    |> Ash.Query.filter(application_id == ^application.id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(tenant: tenant_schema)
  end

  @impl true
  def handle_params(params, _url, socket) do
    id = params["id"]

    if id && id != (socket.assigns.application && socket.assigns.application.id) do
      tenant_schema = socket.assigns.tenant.company_schema

      case UWApplication.get_by_id(id,
             load: [:documents, :activities],
             tenant: tenant_schema
           ) do
        {:ok, application} ->
          risk_assessment =
            RiskAssessment
            |> Ash.Query.filter(application_id == ^application.id)
            |> Ash.Query.sort(inserted_at: :desc)
            |> Ash.Query.limit(1)
            |> Ash.read_one!(tenant: tenant_schema)

          {:noreply,
           socket
           |> assign(:application, application)
           |> assign(:risk_assessment, risk_assessment)}

        _ ->
          {:noreply,
           socket
           |> put_flash(:error, "Application not found.")
           |> push_patch(to: ~p"/tenant/underwriting")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="sovereign-workbench"
      phx-hook="Lucide"
      data-theme="noir"
      class="layout-panopticon font-body text-base-content flex-1 h-full overflow-hidden"
    >
      <!-- LEFT: THE QUEUE -->
      <aside class={[
        "panopticon-wing-left border-r border-base-300 bg-base-200 flex flex-col z-20",
        !@show_queue && "wing-hidden"
      ]}>
        <div class="p-5 border-b border-base-300 flex justify-between items-center bg-base-200 sticky top-0 z-10">
          <div>
            <div class="text-xs font-bold text-base-content/40 uppercase tracking-widest mb-1">
              Underwriting Queue
            </div>
            <div class="text-sm font-bold text-base-content flex items-center gap-2">
              <span class="w-2 h-2 bg-primary rounded-full animate-pulse shadow-[0_0_8px_rgba(16,185,129,0.5)]">
              </span>
              Live Feed ({length(@applications)})
            </div>
          </div>
          <button phx-click="toggle_queue" class="btn btn-ghost btn-xs btn-circle">
            <i data-lucide="chevron-left" class="w-3 h-3"></i>
          </button>
        </div>
        <div class="flex-1 overflow-y-auto scroll-hide custom-scrollbar">
          <%= for app <- @applications do %>
            <div
              phx-click={JS.patch(~p"/tenant/underwriting/#{app.id}")}
              class={[
                "queue-item p-4 border-b border-base-300 cursor-pointer hover:bg-base-300 group",
                @application && @application.id == app.id && active_class(app.risk_score)
              ]}
            >
              <div class="flex justify-between mb-1.5">
                <span class="font-bold text-sm text-base-content group-hover:text-primary">
                  {app.application_data["business_name"] || "Unnamed Merchant"}
                </span>
                <span class="text-xs font-mono text-base-content/40">
                  {Calendar.strftime(app.inserted_at, "%M:%S")}
                </span>
              </div>
              <div class="text-xs text-base-content/60 mb-3">
                {app.application_data["business_type"] || "General Merchant"}
              </div>
              <div class="flex gap-2 items-center">
                <div class={[
                  "badge badge-outline badge-xs font-mono",
                  score_color(app.risk_score) |> String.replace("text-", "border-")
                ]}>
                  {app.risk_score || "--"}/100
                </div>
                <span class={[
                  "text-xs font-bold flex items-center gap-1",
                  score_color(app.risk_score)
                ]}>
                  <i data-lucide={status_icon(app.status)} class="w-3 h-3"></i>
                  {Phoenix.Naming.humanize(app.status)}
                </span>
              </div>
            </div>
          <% end %>
        </div>
      </aside>
      
    <!-- CENTER: EVIDENCE CANVAS -->
      <main class="panopticon-canvas bg-base-100 flex flex-col h-full overflow-hidden">
        <%!-- Contextual Workbench Header (Thin) --%>
        <header class="bg-base-100 border-b border-base-200/50 px-8 py-4 z-30">
          <div class="flex items-center gap-4">
            <div class="bg-base-200 p-2 rounded-lg text-primary">
              <.icon name="hero-rectangle-stack" class="size-5" />
            </div>
            <div class="flex flex-col gap-0.5">
              <h1 class="text-sm font-black uppercase tracking-widest text-base-content/90">
                Underwriting Workbench
              </h1>
              <p class="text-[10px] font-medium text-base-content/40 uppercase tracking-tight">
                Expert triage of forensic risk and new applications.
              </p>
            </div>
          </div>
        </header>

        <%!-- Forensic Canvas Area --%>
        <div class="flex-1 relative overflow-hidden flex flex-col">
          <div class="absolute top-6 left-6 flex items-center gap-2 z-40">
            <button
              :if={!@show_queue}
              phx-click="toggle_queue"
              class="btn btn-primary btn-xs gap-2 rounded-full shadow-lg"
            >
              <i data-lucide="chevron-right" class="w-3 h-3"></i> Queue
            </button>
          </div>
          <div class="absolute top-6 right-6 flex items-center gap-2 z-40">
            <button
              :if={!@show_brief}
              phx-click="toggle_brief"
              class="btn btn-primary btn-xs gap-2 rounded-full shadow-lg"
            >
              Sovereign Brief <i data-lucide="chevron-left" class="w-3 h-3"></i>
            </button>
          </div>
          <div class="absolute top-6 left-1/2 -translate-x-1/2 glass-panel px-1 py-1 rounded-full z-40 flex text-xs font-bold text-base-content/60 shadow-2xl">
            <%= for tab <- ["APPLICATION", "EVIDENCE", "KYB DATA", "FINANCIALS"] do %>
              <button
                phx-click="set_tab"
                phx-value-tab={tab}
                class={[
                  "tab-btn px-4 py-1.5 rounded-full transition-all",
                  @active_tab == tab && "text-base-content bg-base-300 shadow-lg",
                  @active_tab != tab && "hover:text-base-content"
                ]}
              >
                {tab}
              </button>
            <% end %>
          </div>

          <div
            id="canvas-content"
            class="flex-1 overflow-y-auto p-12 pt-24 space-y-8 pb-32 fade-in-content custom-scrollbar relative z-10 w-full max-w-5xl mx-auto"
          >
            <%= if @application do %>
              <%= case @active_tab do %>
                <% "APPLICATION" -> %>
                  <.application_tab application={@application} />
                <% "EVIDENCE" -> %>
                  <.evidence_tab application={@application} />
                <% "KYB DATA" -> %>
                  <.kyb_tab application={@application} risk_assessment={@risk_assessment} />
                <% "FINANCIALS" -> %>
                  <.financials_tab application={@application} />
              <% end %>
            <% else %>
              <div class="flex-1 flex flex-col items-center justify-center text-center p-20 opacity-30 h-full">
                <i data-lucide="shield-check" class="w-24 h-24 mb-6"></i>
                <h3 class="text-xl font-black uppercase tracking-[0.2em]">Select an Application</h3>
                <p class="max-w-xs mt-2 text-sm text-[#e5e5e5]">
                  Select an entry from the queue to initiate a Sovereign Intelligence session.
                </p>
              </div>
            <% end %>
          </div>
          <div class="absolute bottom-0 left-0 w-full h-40 bg-gradient-to-t from-base-100 via-base-100/80 to-transparent pointer-events-none z-20">
          </div>
        </div>
      </main>
      
    <!-- RIGHT: SOVEREIGN BRIEF -->
      <aside class={[
        "panopticon-wing-right bg-base-200 border-l border-base-300 flex flex-col shadow-2xl z-30 relative justify-between",
        !@show_brief && "wing-hidden"
      ]}>
        <%= if @application do %>
          <div class="p-6 border-b border-base-300 bg-base-200 sticky top-0 z-10 flex justify-between items-center">
            <button phx-click="toggle_brief" class="btn btn-ghost btn-xs btn-circle">
              <i data-lucide="chevron-right" class="w-3 h-3"></i>
            </button>
            <div class="text-xs uppercase tracking-widest text-base-content/60 font-bold">
              Analysis Results
            </div>
          </div>
          <div class="p-6 border-b border-base-300 bg-base-200">
            <div class="flex justify-between items-center mb-4">
              <div class="text-xs uppercase tracking-widest text-base-content/60 font-bold">
                Sovereign Score
              </div>
              <div
                class="text-xs text-base-content/60 font-mono flex items-center gap-2 tooltip"
                data-tip="Active Instruction Set (Hash Verified)"
              >
                <span class="opacity-50">PLAYBOOK:</span>
                <span id="playbook-label" class="text-base-content/80 border-b border-base-300 pb-0.5">
                  {(@risk_assessment && @risk_assessment.policy_hash) || "STD_V1"}
                </span>
              </div>
            </div>
            <div class="flex items-center gap-6">
              <div class="relative w-24 h-24 flex items-center justify-center">
                <svg class="w-full h-full -rotate-90 transform" viewBox="0 0 100 100">
                  <circle
                    cx="50"
                    cy="50"
                    r="44"
                    stroke="currentColor"
                    class="text-base-300"
                    stroke-width="8"
                    fill="transparent"
                  />
                  <circle
                    cx="50"
                    cy="50"
                    r="44"
                    stroke="currentColor"
                    stroke-width="8"
                    fill="transparent"
                    stroke-dasharray="276"
                    stroke-dashoffset={276 - 276 * (@application.risk_score || 0) / 100}
                    class={[
                      score_color(@application.risk_score),
                      "transition-all duration-1000 ease-out"
                    ]}
                  />
                </svg>
                <div class="absolute inset-0 flex items-center justify-center text-3xl font-black text-base-content tracking-tighter">
                  {@application.risk_score || "--"}
                </div>
              </div>
              <div class="flex-1">
                <div class={[
                  "px-3 py-1 rounded text-[10px] font-bold uppercase tracking-wide inline-block mb-1",
                  status_badge_style(@application.status)
                ]}>
                  {Phoenix.Naming.humanize(@application.status)}
                </div>
                <p id="atlas-status-msg" class="text-xs text-base-content/60 leading-tight">
                  {status_message(@application)}
                </p>
              </div>
            </div>
          </div>

          <div class="flex-1 overflow-hidden flex flex-col relative bg-base-100">
            <div class="p-2 bg-base-300/50 border-b border-base-300 flex justify-between items-center px-4">
              <span class="text-xs font-bold text-base-content/60 uppercase tracking-widest flex items-center gap-2">
                <i data-lucide="bot" class="w-3 h-3"></i> Atlas Copilot
              </span>
            </div>
            <div id="copilot-stream" class="flex-1 overflow-y-auto custom-scrollbar p-4 space-y-4">
              <div>
                <div class="text-xs uppercase font-bold text-base-content/40 mb-2 pl-1">
                  Identified Signals
                </div>
                <div id="signals-list" class="space-y-2">
                  <%= if @risk_assessment do %>
                    <%= for signal <- get_signals(@risk_assessment) do %>
                      <div class="flex gap-4 group/sign">
                        <div class="mt-1">
                          <i data-lucide="alert-circle" class="w-3 text-emerald/60"></i>
                        </div>
                        <p class="text-xs text-zinc-400 group-hover/sign:text-zinc-200 transition-colors">
                          {signal |> Phoenix.Naming.humanize()}
                        </p>
                      </div>
                    <% end %>
                  <% else %>
                    <p class="text-xs text-base-content/20 italic">No forensic signals captured.</p>
                  <% end %>
                </div>
              </div>
              <div class="p-3 rounded border border-base-300 bg-base-100/40">
                <div class="flex justify-between items-center mb-2">
                  <span class="text-xs uppercase font-bold text-base-content/40">
                    Placement Strategy
                  </span>
                  <span class="text-primary text-xs font-bold">+2.4% Yield</span>
                </div>
                <div class="flex items-center gap-2">
                  <div class="badge badge-xs bg-base-300 text-base-content/60 border-none">
                    QorPay
                  </div>
                  <div class="flex-1 bg-base-300 h-1 rounded-full">
                    <div class="bg-primary h-1 rounded-full w-[94%]"></div>
                  </div>
                </div>
              </div>
              <div class="divider text-xs text-base-content/20 font-mono my-2 uppercase">
                Decision Lineage
              </div>
              <div id="chat-history" class="space-y-4">
                <%= for activity <- Enum.take(@application.activities, 5) do %>
                  <div class="flex gap-3 text-xs">
                    <div class="w-0.5 bg-base-300 relative">
                      <div class="absolute top-1 -left-[3px] w-1.5 h-1.5 rounded-full bg-base-300">
                      </div>
                    </div>
                    <div>
                      <p class="text-base-content/60 font-bold">
                        {activity.type |> Phoenix.Naming.humanize()}
                      </p>
                      <p class="text-base-content/40 font-mono">
                        {Calendar.strftime(activity.inserted_at, "%H:%M")}
                      </p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
            <div class="p-4 border-t border-base-300 bg-base-200">
              <div class="relative">
                <input
                  type="text"
                  class="input input-sm w-full bg-base-300 border-base-300 focus:border-primary/50 rounded text-xs text-base-content/80 pr-10"
                  placeholder="Ask Atlas Copilot..."
                />
                <button class="absolute right-2 top-1.5 text-base-content/40 hover:text-base-content">
                  <i data-lucide="send-horizontal" class="w-4 h-4"></i>
                </button>
              </div>
            </div>
          </div>

          <div class="p-6 border-t border-base-300 bg-base-200">
            <button
              phx-click="run_analysis"
              phx-click-loading
              class="btn btn-block bg-accent hover:bg-accent/80 text-white font-bold border-none h-10 mb-3 rounded text-xs tracking-wide"
            >
              <i data-lucide="sparkles" class="w-4 h-4 mr-2"></i> RUN INTELLIGENCE SCAN
            </button>
            <div class="grid grid-cols-2 gap-3 mb-3">
              <button
                class="btn btn-sm bg-base-300 border-base-300 text-base-content/60 hover:bg-base-300/80 hover:text-base-content rounded h-10 font-normal border"
                phx-click="request_info"
              >
                Request Info
              </button>
              <button
                id="reject-btn"
                class="btn btn-sm bg-base-100 border-base-300 text-base-content/60 hover:bg-error hover:text-white hover:border-error rounded h-10 font-normal border transition-all"
                phx-click="reject"
              >
                Reject
              </button>
            </div>
            <button
              id="approve-btn"
              phx-click="approve"
              class="btn btn-block bg-primary hover:bg-primary/80 text-black font-bold border-none h-12 shadow-[0_0_20px_rgba(16,185,129,0.2)] rounded text-[13px] tracking-wide"
            >
              <i data-lucide="check" class="w-5 h-5 mr-2"></i> APPROVE MERCHANT
            </button>
          </div>
        <% else %>
          <div class="flex-1 flex flex-col items-center justify-center text-center opacity-20">
            <i data-lucide="bot" class="w-16 h-16 mb-4"></i>
            <p class="text-xs uppercase tracking-widest">Awaiting Context</p>
          </div>
        <% end %>
      </aside>
    </div>

    <!-- Modals (Simplified, logic handled in ReviewLive usually but unified here) -->
    <script>
      window.addEventListener("phx:page-loading-stop", _info => {
        if (typeof lucide !== 'undefined') {
          lucide.createIcons();
        }
      });
      // Handle lucide icons on dynamic updates
      window.addEventListener("phx:update", _info => {
         if (typeof lucide !== 'undefined') {
          lucide.createIcons();
        }
      });
    </script>
    """
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("toggle_queue", _, socket) do
    {:noreply, assign(socket, :show_queue, !socket.assigns.show_queue)}
  end

  @impl true
  def handle_event("toggle_brief", _, socket) do
    {:noreply, assign(socket, :show_brief, !socket.assigns.show_brief)}
  end

  @impl true
  def handle_event("run_analysis", _params, socket) do
    tenant_schema = socket.assigns.tenant.company_schema
    application = socket.assigns.application

    # Set scanning state
    socket = assign(socket, :scanning, true)

    # Run the Reactor
    case Reactor.run(AnalyzeApplication, %{application_id: application.id, tenant: tenant_schema}) do
      {:ok, _result} ->
        # Refresh data
        refreshed_app =
          UWApplication.get_by_id!(application.id,
            load: [:documents, :activities],
            tenant: tenant_schema
          )

        risk_assessment =
          RiskAssessment
          |> Ash.Query.filter(application_id == ^application.id)
          |> Ash.Query.sort(inserted_at: :desc)
          |> Ash.Query.limit(1)
          |> Ash.read_one!(tenant: tenant_schema)

        {:noreply,
         socket
         |> assign(:application, refreshed_app)
         |> assign(:risk_assessment, risk_assessment)
         |> assign(:scanning, false)
         |> put_flash(:info, "Sovereign Intelligence scan complete.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:scanning, false)
         |> put_flash(:error, "Scan failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("approve", _params, socket) do
    tenant = socket.assigns.tenant.company_schema
    app = socket.assigns.application

    # Simulate Approval Flow
    {:ok, updated_app} = UWApplication.update(app, %{status: :approved}, tenant: tenant)

    # Log Activity
    Activity
    |> Ash.Changeset.for_create(:create, %{
      type: :status_change,
      application_id: app.id,
      actor_id: socket.assigns.current_user.id,
      metadata: %{
        from: app.status,
        to: :approved,
        reason: "Sovereign Intelligence Activation"
      }
    })
    |> Ash.create!(tenant: tenant)

    # Reload with associations for the UI
    updated_app =
      UWApplication.get_by_id!(updated_app.id,
        load: [:documents, :activities],
        tenant: tenant
      )

    # Refresh queue
    applications =
      UWApplication |> Ash.Query.sort(inserted_at: :desc) |> Ash.read!(tenant: tenant)

    {:noreply,
     socket
     |> assign(:application, updated_app)
     |> assign(:applications, applications)
     |> put_flash(:info, "Merchant #{app.application_data["business_name"]} approved.")}
  end

  @impl true
  def handle_event("reject", _params, socket) do
    tenant = socket.assigns.tenant.company_schema
    app = socket.assigns.application

    {:ok, updated_app} = UWApplication.update(app, %{status: :rejected}, tenant: tenant)

    Activity
    |> Ash.Changeset.for_create(:create, %{
      type: :status_change,
      application_id: app.id,
      actor_id: socket.assigns.current_user.id,
      metadata: %{
        from: app.status,
        to: :rejected,
        reason: "Adverse Action Signal High"
      }
    })
    |> Ash.create!(tenant: tenant)

    # Reload with associations for the UI
    updated_app =
      UWApplication.get_by_id!(updated_app.id,
        load: [:documents, :activities],
        tenant: tenant
      )

    # Refresh queue
    applications =
      UWApplication |> Ash.Query.sort(inserted_at: :desc) |> Ash.read!(tenant: tenant)

    {:noreply,
     socket
     |> assign(:application, updated_app)
     |> assign(:applications, applications)
     |> put_flash(:error, "Merchant #{app.application_data["business_name"]} rejected.")}
  end

  @impl true
  def handle_event("request_info", _params, socket) do
    tenant = socket.assigns.tenant.company_schema
    app = socket.assigns.application

    {:ok, updated_app} = UWApplication.update(app, %{status: :more_info_required}, tenant: tenant)

    Activity
    |> Ash.Changeset.for_create(:create, %{
      type: :internal_note,
      application_id: app.id,
      actor_id: socket.assigns.current_user.id,
      metadata: %{
        note: "System request sent: Missing primary documentation."
      }
    })
    |> Ash.create!(tenant: tenant)

    # Reload with associations for the UI
    updated_app =
      UWApplication.get_by_id!(updated_app.id,
        load: [:documents, :activities],
        tenant: tenant
      )

    # Refresh queue
    applications =
      UWApplication |> Ash.Query.sort(inserted_at: :desc) |> Ash.read!(tenant: tenant)

    {:noreply,
     socket
     |> assign(:application, updated_app)
     |> assign(:applications, applications)
     |> put_flash(:info, "Inquiry sent to merchant.")}
  end

  # Components

  defp application_tab(assigns) do
    ~H"""
    <div class="animate-in slide-in-from-bottom-4 space-y-6 max-w-5xl mx-auto">
      <!-- Business Profile & Contact -->
      <div class="grid grid-cols-12 gap-6">
        <!-- Left Col: Main Info -->
        <div class="col-span-8 space-y-6">
          <div class="glass-panel p-6 rounded-xl border-t-2 border-t-base-300">
            <div class="flex justify-between items-center mb-5 border-b border-base-300 pb-2">
              <h3 class="text-xs font-bold text-base-content/60 uppercase tracking-widest flex items-center gap-2">
                <i data-lucide="building-2" class="w-3 text-base-content/40"></i> Business Profile
              </h3>
              <span class="text-xs text-base-content/20 font-mono uppercase">Verified via SOS</span>
            </div>
            <div class="grid grid-cols-2 gap-y-6 gap-x-8">
              <div>
                <div class="text-xs text-base-content/40 mb-1 uppercase font-semibold">
                  Legal Name
                </div>
                <div class="text-sm text-base-content font-medium">
                  {@application.application_data["business_name"]}
                </div>
              </div>
              <div>
                <div class="text-xs text-base-content/40 mb-1 uppercase font-semibold">DBA</div>
                <div class="text-sm text-base-content font-medium">
                  {@application.application_data["dba"] ||
                    @application.application_data["business_name"]}
                </div>
              </div>
              <div class="col-span-2">
                <div class="text-xs text-base-content/40 mb-1 uppercase font-semibold">
                  Detailed Description
                </div>
                <div class="text-sm text-base-content/60 leading-relaxed bg-base-300/20 p-3 rounded border border-base-300">
                  "{@application.application_data["description"] || "No description provided."}"
                </div>
              </div>
              <div>
                <div class="text-xs text-base-content/40 mb-1 uppercase font-semibold">
                  Tax ID / EIN
                </div>
                <div class="text-sm text-base-content font-mono tracking-wide">
                  {@application.application_data["tax_id"] || "XX-XXXXXXX"}
                </div>
              </div>
              <div>
                <div class="text-xs text-base-content/40 mb-1 uppercase font-semibold">
                  Entity Type
                </div>
                <div class="text-sm text-base-content/80">
                  {@application.application_data["entity_type"] || "Unknown"}
                </div>
              </div>
              <div>
                <div class="text-xs text-base-content/40 mb-1 uppercase font-semibold">
                  Business Address
                </div>
                <div class="text-sm text-base-content/80">
                  {@application.application_data["business_address"]}
                </div>
              </div>
              <div>
                <div class="text-xs text-base-content/40 mb-1 uppercase font-semibold">Phone</div>
                <div class="text-sm text-base-content font-mono">
                  {@application.application_data["contact_phone"] || "N/A"}
                </div>
              </div>
              <div>
                <div class="text-xs text-base-content/40 mb-1 uppercase font-semibold">Website</div>
                <div class="text-sm text-primary underline decoration-primary/30">
                  {@application.application_data["website"]}
                </div>
              </div>
              <div>
                <div class="text-xs text-base-content/40 mb-1 uppercase font-semibold">
                  Support Email
                </div>
                <div class="text-sm text-base-content/80">
                  {@application.application_data["contact_email"]}
                </div>
              </div>
            </div>
          </div>

          <div class="glass-panel p-6 rounded-xl border-t-2 border-t-base-300">
            <h3 class="text-xs font-bold text-base-content/60 uppercase tracking-widest mb-4 border-b border-base-300 pb-2 flex items-center gap-2">
              <i data-lucide="credit-card" class="w-3 text-base-content/40"></i> Processing Profile
            </h3>
            <div class="grid grid-cols-3 gap-6">
              <div class="bg-base-300/40 p-3 rounded border border-base-300">
                <div class="text-xs text-base-content/40 mb-1 uppercase">Monthly Volume</div>
                <div class="text-lg font-mono text-base-content">
                  {@application.application_data["annual_volume"] || "$0"}
                </div>
              </div>
              <div class="bg-base-300/40 p-3 rounded border border-base-300">
                <div class="text-xs text-base-content/40 mb-1 uppercase">Avg Ticket</div>
                <div class="text-lg font-mono text-base-content">
                  {@application.application_data["avg_ticket"] || "$0"}
                </div>
              </div>
              <div class="bg-base-300/40 p-3 rounded border border-base-300">
                <div class="text-xs text-base-content/40 mb-1 uppercase">High Ticket</div>
                <div class="text-lg font-mono text-base-content">
                  {@application.application_data["high_ticket"] || "$0"}
                </div>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Right Col: Owners & Bank -->
        <div class="col-span-4 space-y-6">
          <div class="glass-panel p-5 rounded-xl border-t-2 border-t-base-300">
            <h3 class="text-xs font-bold text-base-content/60 uppercase tracking-widest mb-4 flex items-center gap-2">
              <i data-lucide="users" class="w-3 text-base-content/40"></i> Owners
            </h3>
            <div class="flex items-start gap-3 p-3 rounded bg-base-300/20 border border-base-300 mb-3">
              <div class="w-8 h-8 rounded-full bg-primary/20 text-primary flex items-center justify-center font-bold text-xs ring-1 ring-primary/20">
                {String.at(@application.application_data["contact_name"] || "P", 0)}
              </div>
              <div>
                <div class="text-xs font-bold text-base-content">
                  {@application.application_data["contact_name"]}
                </div>
                <div class="text-xs text-base-content/40">
                  {@application.application_data["contact_title"] || "Principal"}
                </div>
                <div class="text-xs text-primary mt-1 flex items-center gap-1">
                  <i data-lucide="shield-check" class="w-3"></i> KYC Passed
                </div>
              </div>
            </div>
          </div>

          <div class="glass-panel p-5 rounded-xl border-t-2 border-t-base-300">
            <h3 class="text-xs font-bold text-base-content/60 uppercase tracking-widest mb-4 flex items-center gap-2">
              <i data-lucide="landmark" class="w-3 text-base-content/40"></i> Banking
            </h3>
            <div class="p-3 rounded bg-base-300/20 border border-base-300 space-y-3">
              <div class="flex items-center gap-2">
                <div class="badge badge-sm badge-neutral rounded bg-base-300 border-none text-base-content/60">
                  {@application.application_data["bank_name"] || "Unknown Bank"}
                </div>
                <span class="text-xs text-base-content/40">
                  •••• {@application.application_data["bank_account_last_4"] || "0000"}
                </span>
              </div>
              <div class="badge badge-xs bg-primary/10 text-primary border-none gap-1 mt-1">
                <i data-lucide="link" class="w-2"></i> Plaid Connected
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp evidence_tab(assigns) do
    ~H"""
    <div class="animate-in slide-in-from-bottom-4 space-y-8">
      <h2 class="text-2xl font-bold text-base-content">Captured Evidence</h2>
      <div class="space-y-4">
        <div class="text-xs text-base-content/40 font-bold uppercase tracking-widest border-b border-base-300 pb-2">
          Forensic Documentation
        </div>
        <div class="grid grid-cols-2 gap-4">
          <%= for doc <- @application.documents do %>
            <div class="glass-panel p-4 rounded-xl flex items-center justify-between group">
              <div class="flex items-center gap-4">
                <div class="w-12 h-12 bg-base-content/5 rounded border border-base-content/10 grid place-items-center">
                  <i data-lucide="file-check" class="text-base-content/40 w-6"></i>
                </div>
                <div>
                  <p class="text-sm font-bold text-base-content">{doc.file_name}</p>
                  <p class="text-xs text-base-content/40 uppercase tracking-widest font-mono">
                    {doc.document_type} &bull; {Phoenix.Naming.humanize(doc.status)}
                  </p>
                </div>
              </div>
              <a
                href={presigned_url(doc.file_path)}
                target="_blank"
                class="btn btn-ghost btn-xs text-base-content/40 hover:text-base-content"
              >
                VIEW
              </a>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp kyb_tab(assigns) do
    ~H"""
    <div class="animate-in slide-in-from-bottom-4 space-y-4">
      <h2 class="text-2xl font-bold text-base-content mb-6">KYB Data Sources</h2>
      <div class="grid grid-cols-12 gap-6">
        <div class="col-span-8 space-y-4">
          <div class="glass-panel p-6 rounded-xl border-t-2 border-t-base-300">
            <div class="flex justify-between items-center mb-6">
              <h3 class="text-sm font-bold text-base-content/60 uppercase tracking-widest flex items-center gap-2">
                <i data-lucide="building" class="w-4 text-base-content/40"></i> Entity Verification
              </h3>
              <div class={"badge #{kyb_badge_color(@application.application_data["kyb_status"])} badge-sm font-bold"}>
                {@application.application_data["kyb_status"] || "PENDING"}
              </div>
            </div>

            <div class="grid grid-cols-2 gap-y-6 gap-x-12">
              <div>
                <div class="text-xs text-base-content/40 mb-1 uppercase font-semibold tracking-wider">
                  Registration Number
                </div>
                <div class="text-sm text-base-content/80 font-mono">
                  {get_in(@application.application_data, ["business_info", "registration_number"]) ||
                    "N/A"}
                </div>
              </div>
              <div>
                <div class="text-xs text-base-content/40 mb-1 uppercase font-semibold tracking-wider">
                  Tax ID (TIN/EIN)
                </div>
                <div class="text-sm text-base-content/80 font-mono">
                  {get_in(@application.application_data, ["business_info", "tax_id"]) || "N/A"}
                </div>
              </div>
              <div>
                <div class="text-xs text-base-content/40 mb-1 uppercase font-semibold tracking-wider">
                  Incorporation Date
                </div>
                <div class="text-sm text-base-content/80">
                  {get_in(@application.application_data, ["business_info", "incorporation_date"]) ||
                    "N/A"}
                </div>
              </div>
              <div>
                <div class="text-xs text-base-content/40 mb-1 uppercase font-semibold tracking-wider">
                  Entity Type
                </div>
                <div class="text-sm text-base-content/80">
                  {get_in(@application.application_data, ["business_info", "type"]) || "N/A"}
                </div>
              </div>
            </div>
          </div>

          <div class="collapse collapse-arrow bg-base-300/50 border border-base-300 rounded-xl overflow-hidden">
            <input type="checkbox" />
            <div class="collapse-title text-xs font-bold text-base-content/40 uppercase tracking-widest flex items-center gap-2">
              <i data-lucide="database" class="w-3"></i> View Raw Registry Payload
            </div>
            <div class="collapse-content bg-base-100 font-mono text-xs border-t border-base-300">
              <pre class="p-4 overflow-x-auto text-accent/70">
                {Jason.encode!(@application.application_data, pretty: true)}
              </pre>
            </div>
          </div>
        </div>

        <div class="col-span-4">
          <div class="glass-panel p-5 rounded-xl border-t-2 border-t-primary/20 bg-primary/5">
            <h3 class="text-xs font-bold text-primary uppercase tracking-widest mb-4 flex items-center gap-2">
              <i data-lucide="bot" class="w-3"></i> Atlas Analysis
            </h3>
            <p class="text-xs text-base-content/60 leading-tight">
              <%= if @application.application_data["kyb_status"] == "Verified" do %>
                Entity verified against state records. All beneficial owners clear of global sanctions.
              <% else %>
                Manual intervention required. Entity records show discrepancies or missing state filings.
              <% end %>
            </p>
            <div class="bg-base-100/40 rounded p-2 border border-primary/10 mt-4">
              <div class="text-xs uppercase font-bold text-base-content/40 mb-1">KYB Status</div>
              <div class="text-xs text-primary font-mono uppercase">
                {@application.application_data["kyb_status"] || "Unknown"}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp financials_tab(assigns) do
    ~H"""
    <div class="animate-in slide-in-from-bottom-4 space-y-6">
      <div class="glass-panel p-6 rounded-xl border-t-2 border-t-base-300">
        <div class="flex items-center justify-between mb-8">
          <h3 class="text-sm font-bold text-base-content/60 uppercase tracking-widest flex items-center gap-2">
            <i data-lucide="wallet" class="w-4 text-base-content/40"></i> Financial Performance (90d)
          </h3>
          <div class="badge badge-success gap-1 bg-primary/10 text-primary border-primary/20 text-xs font-bold">
            <i data-lucide="link" class="w-3"></i> PLAID CONNECTED
          </div>
        </div>

        <div class="grid grid-cols-3 gap-8">
          <div class="bg-base-300/40 p-5 rounded-xl border border-base-300 text-center">
            <div class="text-xs text-base-content/40 uppercase font-bold mb-2">Monthly Volume</div>
            <div class="text-2xl font-mono text-base-content tracking-tighter">
              {@application.application_data["annual_volume"] || "$0"}
            </div>
          </div>
          <div class="bg-base-300/40 p-5 rounded-xl border border-base-300 text-center">
            <div class="text-xs text-base-content/40 uppercase font-bold mb-2">Avg Ticket</div>
            <div class="text-2xl font-mono text-primary tracking-tighter">
              {@application.application_data["avg_ticket"] || "$0"}
            </div>
          </div>
          <div class="bg-base-300/40 p-5 rounded-xl border border-base-300 text-center">
            <div class="text-xs text-base-content/40 uppercase font-bold mb-2">High Ticket</div>
            <div class="text-2xl font-mono text-base-content tracking-tighter">
              {@application.application_data["high_ticket"] || "$0"}
            </div>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-6">
        <div class="glass-panel p-5 rounded-xl border-t-2 border-t-base-300">
          <h3 class="text-xs font-bold text-base-content/40 uppercase tracking-widest mb-4">
            Liquidity Signals
          </h3>
          <div class="space-y-3">
            <div class="flex justify-between items-center text-xs">
              <span class="text-base-content/60">NSF Count (90d)</span>
              <span class="font-mono text-primary">0</span>
            </div>
            <div class="flex justify-between items-center text-xs">
              <span class="text-base-content/60">Chargeback Ratio</span>
              <span class="font-mono text-base-content/80">0.04%</span>
            </div>
            <div class="flex justify-between items-center text-xs">
              <span class="text-base-content/60">Avg Daily Balance</span>
              <span class="font-mono text-base-content/80">$45,210</span>
            </div>
          </div>
        </div>

        <div class="glass-panel p-5 rounded-xl border-t-2 border-t-base-300 bg-base-300/20">
          <h3 class="text-xs font-bold text-base-content/40 uppercase tracking-widest mb-4">
            Risk Exposure
          </h3>
          <div id="risk-chart" class="h-16 flex items-end gap-1 px-2">
            <%= for h <- [20, 35, 25, 45, 60, 40, 30, 50, 70, 45, 35, 25] do %>
              <div
                class="flex-1 bg-base-300 hover:bg-primary/50 transition-colors rounded-t-sm"
                style={"height: #{h}%;"}
              >
              </div>
            <% end %>
          </div>
          <div class="mt-2 text-xs text-base-content/20 font-mono flex justify-between uppercase">
            <span>Oct 2025</span>
            <span>Jan 2026</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helpers

  defp active_class(score) when is_nil(score), do: "active-amber"
  defp active_class(score) when score >= 70, do: "active-emerald"
  defp active_class(score) when score >= 40, do: "active-amber"
  defp active_class(_), do: "active-crimson"

  defp score_color(score) when is_nil(score), do: "text-base-content/20"
  defp score_color(score) when score >= 70, do: "text-primary"
  defp score_color(score) when score >= 40, do: "text-warning"
  defp score_color(_), do: "text-error"

  defp status_badge_style(:approved), do: "bg-primary/10 border border-primary/20 text-primary"
  defp status_badge_style(:rejected), do: "bg-error/10 border border-error/20 text-error"
  defp status_badge_style(_), do: "bg-warning/10 border border-warning/20 text-warning"

  defp kyb_badge_color("Verified"),
    do: "badge-success bg-primary/10 text-primary border-primary/20"

  defp kyb_badge_color("Caution"),
    do: "badge-warning bg-warning/10 text-warning border-warning/20"

  defp kyb_badge_color("Failed"), do: "badge-error bg-error/10 text-error border-error/20"
  defp kyb_badge_color(_), do: "badge-ghost bg-base-300 text-base-content/40 border-base-300"

  defp status_message(app) do
    case app.status do
      :approved -> "All automated and manual checks passed."
      :rejected -> "Adverse action signals exceeding threshold."
      :more_info_required -> "Awaiting documentation from merchant."
      _ -> "Triage in progress. Analyzing forensic signals."
    end
  end

  defp status_icon(:approved), do: "check-circle"
  defp status_icon(:rejected), do: "alert-octagon"
  defp status_icon(:more_info_required), do: "clock"
  defp status_icon(_), do: "activity"

  defp get_signals(nil), do: []
  defp get_signals(ra), do: ra.factors[:signals] || []

  defp presigned_url(nil), do: "#"

  defp presigned_url(path) do
    bucket = Elixir.Application.get_env(:mcp, :uploads)[:bucket]

    case ExAws.S3.presigned_url(ExAws.Config.new(:s3), :get, bucket, path, expires_in: 3600) do
      {:ok, url} -> url
      _ -> "#"
    end
  end
end
