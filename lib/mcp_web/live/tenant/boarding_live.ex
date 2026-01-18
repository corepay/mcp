defmodule McpWeb.Tenant.BoardingLive do
  use McpWeb, :live_view

  alias Mcp.Platform.Tenant
  alias Mcp.Underwriting.Boarding
  alias Mcp.Underwriting.Services.BoardingService

  @impl true
  def mount(_params, session, socket) do
    tenant_id = session["tenant_id"] || socket.assigns.current_user.tenant_id
    tenant = Tenant.get_by_id!(tenant_id)

    if connected?(socket) do
      # Subscribe to updates if needed
    end

    {:ok,
     socket
     |> assign(:page_title, "Boarding Lifecycle")
     |> assign(:tenant, tenant)
     |> assign(:selected_boarding_id, nil)
     |> fetch_boardings()}
  end

  defp fetch_boardings(socket) do
    boardings =
      Boarding.read!(
        load: [:application, :processor, :bank_profile],
        tenant: socket.assigns.tenant.company_schema
      )
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

    assign(socket, :boardings, boardings)
  end

  @impl true
  def handle_event("select_boarding", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_boarding_id, id)}
  end

  @impl true
  def handle_event("close_drawer", _, socket) do
    {:noreply, assign(socket, :selected_boarding_id, nil)}
  end

  @impl true
  def handle_event("sync_boarding", %{"id" => id}, socket) do
    boarding = Enum.find(socket.assigns.boardings, &(&1.id == id))

    case BoardingService.sync_status(boarding, tenant: socket.assigns.tenant.company_schema) do
      :ok ->
        put_flash(socket, :info, "Status synchronized successfully.")
        {:noreply, fetch_boardings(socket)}

      {:error, reason} ->
        put_flash(socket, :error, "Sync failed: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex overflow-hidden bg-zinc-50 dark:bg-black font-sans">
      <!-- Main Content -->
      <main class="flex-1 flex flex-col min-w-0 overflow-y-auto p-8 lg:p-12 relative">
        <header class="flex justify-between items-start mb-12">
          <div>
            <h1 class="text-4xl font-black text-zinc-900 dark:text-white tracking-tighter mb-2">
              Boarding Lifecycle
            </h1>
            <p class="text-zinc-500 dark:text-zinc-500 max-w-md leading-relaxed">
              Global gateway orchestration and decision lineage. View the rationale behind every merchant-bank assignment.
            </p>
          </div>
          <div class="flex items-center gap-6">
            <div class="flex flex-col items-end">
              <span class="text-[10px] uppercase tracking-widest font-black text-zinc-400 dark:text-zinc-600 mb-1">
                Health
              </span>
              <div class="flex items-center gap-2">
                <div class="h-2 w-2 rounded-full bg-emerald-500 animate-pulse"></div>
                <span class="text-xs font-mono font-bold text-zinc-900 dark:text-zinc-300">
                  SYSTEM_NOMINAL
                </span>
              </div>
            </div>
            <div class="h-10 w-[1px] bg-zinc-200 dark:bg-zinc-800"></div>
            <div class="flex gap-4">
              <div class="stats bg-transparent border-none p-0 flex space-x-8">
                <div class="stat p-0 min-w-[80px]">
                  <div class="stat-title text-[9px] uppercase font-black text-zinc-400 dark:text-zinc-600 tracking-widest">
                    Active
                  </div>
                  <div class="stat-value text-3xl font-black text-emerald-500">
                    {active_count(@boardings)}
                  </div>
                </div>
                <div class="stat p-0 min-w-[80px]">
                  <div class="stat-title text-[9px] uppercase font-black text-zinc-400 dark:text-zinc-600 tracking-widest">
                    Pending
                  </div>
                  <div class="stat-value text-3xl font-black text-amber-500">
                    {pending_count(@boardings)}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </header>

        <div class="bg-white dark:bg-zinc-900 rounded-3xl shadow-[0_32px_64px_-16px_rgba(0,0,0,0.1)] border border-zinc-200 dark:border-zinc-800 overflow-hidden">
          <table class="table w-full border-collapse">
            <thead>
              <tr class="border-b border-zinc-100 dark:border-zinc-800">
                <th class="py-6 px-8 text-[10px] uppercase font-black text-zinc-400 dark:text-zinc-500 tracking-widest text-left">
                  Merchant Entity
                </th>
                <th class="py-6 px-8 text-[10px] uppercase font-black text-zinc-400 dark:text-zinc-500 tracking-widest text-left">
                  Processor Stack
                </th>
                <th class="py-6 px-8 text-[10px] uppercase font-black text-zinc-400 dark:text-zinc-500 tracking-widest text-left">
                  Identifiers
                </th>
                <th class="py-6 px-8 text-[10px] uppercase font-black text-zinc-400 dark:text-zinc-500 tracking-widest text-left">
                  State
                </th>
                <th class="py-6 px-8 text-[10px] uppercase font-black text-zinc-400 dark:text-zinc-500 tracking-widest text-right">
                  Timestamp
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-zinc-100 dark:divide-zinc-800">
              <%= if Enum.empty?(@boardings) do %>
                <tr>
                  <td colspan="5" class="py-32 text-center text-zinc-400 italic font-medium">
                    <div class="flex flex-col items-center opacity-40">
                      <.icon name="hero-archive-box" class="h-12 w-12 mb-4" />
                      <span>Zero boarding activities recorded.</span>
                    </div>
                  </td>
                </tr>
              <% else %>
                <%= for boarding <- @boardings do %>
                  <tr
                    phx-click="select_boarding"
                    phx-value-id={boarding.id}
                    class={"group cursor-pointer hover:bg-zinc-50 dark:hover:bg-zinc-800/50 transition-all duration-300 #{if @selected_boarding_id == boarding.id, do: "bg-zinc-50 dark:bg-zinc-800/50", else: ""}"}
                  >
                    <td class="py-6 px-8">
                      <div class="flex flex-col">
                        <span class="text-sm font-bold text-zinc-900 dark:text-white group-hover:underline decoration-zinc-300 decoration-2 underline-offset-4">
                          {boarding.application.application_data["business_name"] || "Generic Entity"}
                        </span>
                        <div class="flex items-center gap-2 mt-1">
                          <span class="text-[9px] font-mono p-0.5 px-1 bg-zinc-100 dark:bg-zinc-800 rounded text-zinc-500 uppercase tracking-tighter">
                            APP_{boarding.application.id |> String.slice(0, 6)}
                          </span>
                          <span class="text-[9px] text-zinc-400 uppercase font-black tracking-widest opacity-0 group-hover:opacity-100 transition-opacity">
                            View Audit
                          </span>
                        </div>
                      </div>
                    </td>
                    <td class="py-6 px-8">
                      <div class="flex flex-col gap-1">
                        <span class="text-[10px] font-black text-zinc-400 dark:text-zinc-600 uppercase tracking-widest leading-none">
                          {boarding.processor.name}
                        </span>
                        <span class="text-xs font-bold text-zinc-700 dark:text-zinc-300">
                          {boarding.bank_profile.name}
                        </span>
                      </div>
                    </td>
                    <td class="py-6 px-8">
                      <div class="flex flex-col font-mono text-[10px] space-y-1">
                        <div class="flex justify-between gap-4">
                          <span class="text-zinc-400 font-bold tracking-tighter">MID</span>
                          <span class="text-zinc-900 dark:text-zinc-100 font-black">
                            {boarding.mid || "N/A"}
                          </span>
                        </div>
                        <div class="flex justify-between gap-4">
                          <span class="text-zinc-400 font-bold tracking-tighter">TID</span>
                          <span class="text-zinc-900 dark:text-zinc-300">
                            {boarding.tid || "N/A"}
                          </span>
                        </div>
                      </div>
                    </td>
                    <td class="py-6 px-8">
                      <div class="flex items-center gap-3">
                        <div class={"h-1.5 w-1.5 rounded-full #{status_dot_color(boarding.status)}"}>
                        </div>
                        <span class={"text-[10px] font-black uppercase tracking-widest #{status_text_color(boarding.status)}"}>
                          {boarding.status}
                        </span>
                        <%= if boarding.status == :pending do %>
                          <button
                            phx-click="sync_boarding"
                            phx-value-id={boarding.id}
                            class="p-1 hover:bg-zinc-100 dark:hover:bg-zinc-700 rounded transition-colors text-zinc-400"
                            title="Manual Sync"
                          >
                            <.icon name="hero-arrow-path" class="h-3 w-3" />
                          </button>
                        <% end %>
                      </div>
                    </td>
                    <td class="py-6 px-8 text-right">
                      <span class="text-[10px] font-mono text-zinc-400 dark:text-zinc-600 font-bold">
                        {Calendar.strftime(boarding.inserted_at, "%Y-%m-%d %H:%M:%S UTC")}
                      </span>
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      </main>
      
    <!-- Audit Drawer -->
      <%= if @selected_boarding_id do %>
        <% selected = Enum.find(@boardings, &(&1.id == @selected_boarding_id)) %>
        <aside class="w-[480px] border-l border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-950 flex flex-col shadow-2xl z-20 animate-in slide-in-from-right duration-500">
          <header class="p-8 border-b border-zinc-100 dark:border-zinc-800 flex justify-between items-center bg-zinc-50/50 dark:bg-zinc-900/50">
            <div>
              <span class="text-[10px] font-black text-zinc-400 dark:text-zinc-600 uppercase tracking-widest block mb-1">
                Audit Record
              </span>
              <h2 class="text-xl font-black text-zinc-900 dark:text-white tracking-tighter">
                Decision Lineage
              </h2>
            </div>
            <button
              phx-click="close_drawer"
              class="h-10 w-10 flex items-center justify-center rounded-full border border-zinc-200 dark:border-zinc-800 text-zinc-400 hover:bg-zinc-100 dark:hover:bg-zinc-800 transition-all"
            >
              <.icon name="hero-x-mark" class="h-5 w-5" />
            </button>
          </header>

          <div class="flex-1 overflow-y-auto p-8 space-y-10">
            <!-- Summary Card -->
            <section>
              <div class="grid grid-cols-2 gap-4">
                <div class="p-4 rounded-2xl bg-zinc-50 dark:bg-zinc-900 border border-zinc-100 dark:border-zinc-800">
                  <span class="text-[9px] font-black text-zinc-400 uppercase tracking-widest block mb-2 text-center">
                    Outcome
                  </span>
                  <div class={"text-center font-black uppercase tracking-tighter text-lg #{status_text_color(selected.status)}"}>
                    {selected.status}
                  </div>
                </div>
                <div class="p-4 rounded-2xl bg-zinc-50 dark:bg-zinc-900 border border-zinc-100 dark:border-zinc-800">
                  <span class="text-[9px] font-black text-zinc-400 uppercase tracking-widest block mb-2 text-center">
                    Schema
                  </span>
                  <div class="text-center font-mono font-bold text-sm text-zinc-900 dark:text-white truncate">
                    {selected.__metadata__.tenant}
                  </div>
                </div>
              </div>
            </section>
            
    <!-- Rationale Section (The "Why") -->
            <section>
              <h3 class="flex items-center gap-2 text-[10px] font-black text-zinc-400 dark:text-zinc-600 uppercase tracking-widest mb-4">
                <.icon name="hero-cpu-chip" class="h-3 w-3" /> Decision Rationale
              </h3>
              <div class="p-6 rounded-2xl bg-zinc-900 border border-zinc-800 shadow-inner relative overflow-hidden group">
                <div class="absolute top-0 right-0 p-2 opacity-5">
                  <.icon name="hero-command-line" class="h-12 w-12 text-white" />
                </div>
                <p class="text-sm text-zinc-300 dark:text-zinc-300 leading-relaxed font-medium">
                  {selected.rationale || "No automated rationale logged for this record."}
                </p>
              </div>
            </section>
            
    <!-- Error Trapping -->
            <%= if selected.status == :failed or !Enum.empty?(selected.error_metadata) do %>
              <section>
                <h3 class="flex items-center gap-2 text-[10px] font-black text-error dark:text-red-400 uppercase tracking-widest mb-4">
                  <.icon name="hero-exclamation-triangle" class="h-3 w-3" /> Error Traces
                </h3>
                <div class="space-y-3">
                  <%= for {key, val} <- selected.error_metadata do %>
                    <div class="p-4 rounded-xl bg-red-50/50 dark:bg-red-950/20 border border-red-100 dark:border-red-900/50">
                      <span class="text-[9px] font-black text-red-400 dark:text-red-500 uppercase tracking-widest block mb-1">
                        {key}
                      </span>
                      <p class="text-[11px] font-mono text-red-800 dark:text-red-300 whitespace-pre-wrap break-all leading-tight">
                        {val}
                      </p>
                    </div>
                  <% end %>
                </div>
              </section>
            <% end %>
            
    <!-- Metadata Audit -->
            <section>
              <h3 class="flex items-center gap-2 text-[10px] font-black text-zinc-400 dark:text-zinc-600 uppercase tracking-widest mb-4">
                <.icon name="hero-list-bullet" class="h-3 w-3" /> Adapter Metadata
              </h3>
              <div class="bg-zinc-50 dark:bg-zinc-900/50 rounded-2xl border border-zinc-100 dark:border-zinc-800 divide-y divide-zinc-100 dark:divide-zinc-800">
                <%= for {key, val} <- selected.metadata do %>
                  <div class="p-4 flex justify-between items-center">
                    <span class="text-[10px] font-bold text-zinc-400 uppercase tracking-tight">
                      {key}
                    </span>
                    <span class="text-xs font-mono font-bold text-zinc-900 dark:text-zinc-300">
                      {inspect(val)}
                    </span>
                  </div>
                <% end %>
              </div>
            </section>
          </div>

          <footer class="p-8 border-t border-zinc-100 dark:border-zinc-800 bg-zinc-50/50 dark:bg-zinc-900/50">
            <button
              phx-click="close_drawer"
              class="w-full py-4 bg-zinc-900 dark:bg-white text-white dark:text-black font-black text-xs uppercase tracking-widest rounded-2xl hover:scale-[1.02] active:scale-[0.98] transition-all"
            >
              Close Ledger
            </button>
          </footer>
        </aside>
      <% end %>
    </div>
    """
  end

  defp status_text_color(:active), do: "text-emerald-500"
  defp status_text_color(:pending), do: "text-amber-500"
  defp status_text_color(:failed), do: "text-red-500"
  defp status_text_color(_), do: "text-zinc-400"

  defp status_dot_color(:active), do: "bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.5)]"
  defp status_dot_color(:pending), do: "bg-amber-500 shadow-[0_0_8px_rgba(245,158,11,0.5)]"
  defp status_dot_color(:failed), do: "bg-red-500 shadow-[0_0_8px_rgba(239,68,68,0.5)]"
  defp status_dot_color(_), do: "bg-zinc-400"

  defp active_count(boardings), do: Enum.count(boardings, &(&1.status == :active))
  defp pending_count(boardings), do: Enum.count(boardings, &(&1.status == :pending))
end
