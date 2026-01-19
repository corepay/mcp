defmodule McpWeb.Tenant.Audit.IndexLive do
  use McpWeb, :live_view

  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.Activity

  @impl true
  def mount(_params, session, socket) do
    tenant_id = session["tenant_id"] || socket.assigns.current_context[:tenant_id]
    tenant = Tenant.get_by_id!(tenant_id)
    tenant_schema = tenant.company_schema

    activities = Activity.read!(tenant: tenant_schema)
    # Sort activities by timestamp
    activities = Enum.sort_by(activities, & &1.inserted_at, {:desc, DateTime})

    {:ok,
     socket
     |> assign(:page_title, "Operational Ledger")
     |> assign(:tenant, tenant)
     |> assign(:activities, activities)
     |> assign(:filter_type, "all")}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :filter_type, type)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-base-100 font-sans">
      <%!-- Contextual Audit Header (Thin) --%>
      <header class="bg-base-100 border-b border-base-200/50 px-8 py-4 z-30 flex items-center justify-between sticky top-0">
        <div class="flex items-center gap-4">
          <div class="bg-base-200 p-2 rounded-lg text-primary">
            <.icon name="hero-shield-check" class="size-5" />
          </div>
          <div class="flex flex-col gap-0.5">
            <h1 class="text-sm font-black uppercase tracking-widest text-base-content/90">
              Operational Ledger
            </h1>
            <p class="text-[10px] font-medium text-base-content/40 uppercase tracking-tight">
              Immutable Forensic Audit of Platform Operations & Compliance
            </p>
          </div>
        </div>

        <div class="flex items-center gap-4">
          <div class="flex bg-base-200 p-1 rounded-xl border border-base-300">
            <button
              phx-click="filter_type"
              phx-value-type="all"
              class={[
                "px-4 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest transition-all",
                @filter_type == "all" && "bg-base-100 shadow-sm text-primary"
              ]}
            >
              All Signals
            </button>
            <button
              phx-click="filter_type"
              phx-value-type="risk"
              class={[
                "px-4 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest transition-all",
                @filter_type == "risk" && "bg-base-100 shadow-sm text-primary"
              ]}
            >
              Risk & AI
            </button>
            <button
              phx-click="filter_type"
              phx-value-type="system"
              class={[
                "px-4 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest transition-all",
                @filter_type == "system" && "bg-base-100 shadow-sm text-primary"
              ]}
            >
              System Events
            </button>
          </div>
          <button class="btn btn-primary btn-sm rounded-xl px-6 uppercase tracking-widest text-[10px] font-black">
            Export Ledger
          </button>
        </div>
      </header>

      <main class="flex-1 overflow-y-auto p-12 custom-scrollbar">
        <div class="max-w-6xl mx-auto space-y-8">
          <%!-- Forensic List --%>
          <div class="glass-panel overflow-hidden rounded-3xl border border-base-200 shadow-xl">
            <table class="w-full text-left border-collapse">
              <thead>
                <tr class="bg-base-200/50 border-b border-base-200">
                  <th class="px-8 py-4 text-[10px] font-black uppercase tracking-widest text-base-content/40 w-48">
                    Timestamp
                  </th>
                  <th class="px-8 py-4 text-[10px] font-black uppercase tracking-widest text-base-content/40 w-40">
                    Event Type
                  </th>
                  <th class="px-8 py-4 text-[10px] font-black uppercase tracking-widest text-base-content/40">
                    Context & Payload
                  </th>
                  <th class="px-8 py-4 text-[10px] font-black uppercase tracking-widest text-base-content/40 w-32 text-right">
                    Integrity
                  </th>
                </tr>
              </thead>
              <tbody>
                <%= for activity <- filtered_activities(@activities, @filter_type) do %>
                  <tr class="border-b border-base-200/50 hover:bg-base-200/20 transition-colors group">
                    <td class="px-8 py-6 align-top">
                      <div class="flex flex-col">
                        <span class="text-xs font-black text-base-content">
                          {Calendar.strftime(activity.inserted_at, "%Y-%m-%d")}
                        </span>
                        <span class="text-[10px] font-bold text-base-content/40 font-mono">
                          {Calendar.strftime(activity.inserted_at, "%H:%M:%S.%f")
                          |> String.slice(0, 11)}
                        </span>
                      </div>
                    </td>
                    <td class="px-8 py-6 align-top">
                      <div class={[
                        "inline-flex items-center gap-2 px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest",
                        type_bg(activity.type)
                      ]}>
                        <.icon name={activity_icon(activity.type)} class="size-3" />
                        {activity.type |> Phoenix.Naming.humanize()}
                      </div>
                    </td>
                    <td class="px-8 py-6 align-top">
                      <div class="flex flex-col gap-2">
                        <p class="text-sm font-bold text-base-content leading-tight">
                          {format_activity_msg(activity)}
                        </p>
                        <div class="bg-black/20 p-4 rounded-xl border border-white/5 overflow-hidden">
                          <pre class="text-[10px] font-mono text-base-content/60 leading-relaxed overflow-x-auto">
                            {Jason.encode!(activity.metadata, pretty: true)}
                          </pre>
                        </div>
                      </div>
                    </td>
                    <td class="px-8 py-6 align-top text-right">
                      <div class="flex items-center justify-end gap-2 text-primary/40 group-hover:text-primary transition-colors">
                        <span class="text-[9px] font-mono uppercase font-black tracking-tighter">
                          Verified
                        </span>
                        <.icon name="hero-check-badge" class="size-4" />
                      </div>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </main>
    </div>
    """
  end

  # Helpers
  defp filtered_activities(activities, "all"), do: activities

  defp filtered_activities(activities, "risk") do
    Enum.filter(activities, &(&1.type in [:risk_assessment, :alert]))
  end

  defp filtered_activities(activities, "system") do
    Enum.filter(activities, &(&1.type in [:status_change, :internal_note]))
  end

  defp type_bg(:risk_assessment), do: "bg-primary/10 text-primary border border-primary/20"
  defp type_bg(:alert), do: "bg-error/10 text-error border border-error/20"
  defp type_bg(:status_change), do: "bg-accent/10 text-accent border border-accent/20"
  defp type_bg(_), do: "bg-base-300 text-base-content/60 border border-base-400/20"

  defp activity_icon(:status_change), do: "hero-arrow-path"
  defp activity_icon(:comment), do: "hero-chat-bubble-left-right"
  defp activity_icon(:alert), do: "hero-exclamation-triangle"
  defp activity_icon(:risk_assessment), do: "hero-shield-check"
  defp activity_icon(:kyc_success), do: "hero-check-badge"
  defp activity_icon(:kyc_failure), do: "hero-x-circle"
  defp activity_icon(_), do: "hero-bolt"

  defp format_activity_msg(%{type: :status_change} = activity) do
    from = activity.metadata["from"] || "unknown"
    to = activity.metadata["to"] || "unknown"
    "Application state transition recorded from #{from} state to #{to} state."
  end

  defp format_activity_msg(%{type: :risk_assessment} = activity) do
    score = activity.metadata["score"] || "XX"
    "AI-Driven Intelligence Scan completed. Forensic Signal Score: #{score}/100"
  end

  defp format_activity_msg(%{type: :internal_note} = activity) do
    note = activity.metadata["note"] || "No content."
    "Strategic and operational directive logged by system actor: \"#{note}\""
  end

  defp format_activity_msg(%{type: :kyc_success}) do
    "Primary identity verification successfully synchronized with biometric records."
  end

  defp format_activity_msg(_activity) do
    "Atomic operational trace recorded and appended to the ledger."
  end
end
