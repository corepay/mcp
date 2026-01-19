defmodule McpWeb.Tenant.Merchants.IndexLive do
  use McpWeb, :live_view

  alias Mcp.Platform.Merchant
  alias Mcp.Platform.Tenant

  @impl true
  def mount(_params, session, socket) do
    tenant_id = session["tenant_id"] || socket.assigns.current_context[:tenant_id]
    tenant = Tenant.get_by_id!(tenant_id)
    tenant_schema = tenant.company_schema

    if connected?(socket) do
      # Subscribe to updates if needed
    end

    merchants =
      Merchant.read!(tenant: tenant_schema)
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

    {:ok,
     socket
     |> assign(:page_title, "Merchant Portfolio")
     |> assign(:tenant, tenant)
     |> assign(:merchants, merchants)
     |> assign(:selected_merchant_id, nil)}
  end

  @impl true
  def handle_event("select_merchant", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_merchant_id, id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex overflow-hidden bg-base-100 font-sans">
      <!-- Main Content -->
      <main class="flex-1 flex flex-col min-w-0 overflow-hidden relative">
        <%!-- Contextual Portfolio Header (Thin) --%>
        <header class="bg-base-100 border-b border-base-200/50 px-8 py-4 z-30 flex items-center justify-between sticky top-0">
          <div class="flex items-center gap-4">
            <div class="bg-base-200 p-2 rounded-lg text-primary">
              <.icon name="hero-briefcase" class="size-5" />
            </div>
            <div class="flex flex-col gap-0.5">
              <h1 class="text-sm font-black uppercase tracking-widest text-base-content/90">
                Merchant Portfolio
              </h1>
              <p class="text-[10px] font-medium text-base-content/40 uppercase tracking-tight">
                Manage active relationships and account hierarchies.
              </p>
            </div>
          </div>

          <div class="flex items-center gap-6">
            <div class="flex flex-col items-end">
              <span class="text-[10px] uppercase tracking-widest font-black text-base-content/40 mb-1 leading-none">
                Portfolio Status
              </span>
              <div class="flex items-center gap-2">
                <div class="h-1.5 w-1.5 rounded-full bg-primary animate-pulse shadow-[0_0_8px_rgba(16,185,129,0.5)]">
                </div>
                <span class="text-[10px] font-mono font-bold text-base-content/80">
                  HEALTH_NOMINAL
                </span>
              </div>
            </div>
            <div class="h-8 w-[1px] bg-base-300"></div>
            <div class="flex gap-4">
              <div class="stats bg-transparent border-none p-0 flex space-x-6">
                <div class="stat p-0 min-w-fit">
                  <div class="stat-title text-[9px] uppercase font-black text-base-content/40 tracking-widest">
                    Active
                  </div>
                  <div class="stat-value text-lg font-black text-primary leading-none">
                    {active_count(@merchants)}
                  </div>
                </div>
                <div class="stat p-0 min-w-fit">
                  <div class="stat-title text-[9px] uppercase font-black text-base-content/40 tracking-widest">
                    Pending
                  </div>
                  <div class="stat-value text-lg font-black text-warning leading-none">
                    {pending_count(@merchants)}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </header>

        <div class="flex-1 overflow-y-auto p-12 relative custom-scrollbar">
          <%!-- Premium List View --%>
          <div class="grid grid-cols-1 gap-4">
            <%= if Enum.empty?(@merchants) do %>
              <div class="flex flex-col items-center justify-center py-32 opacity-20">
                <.icon name="hero-users" class="size-16 mb-4" />
                <h3 class="text-xl font-black uppercase tracking-[0.2em]">Empty Portfolio</h3>
                <p class="text-sm mt-2">Zero merchant accounts currently under management.</p>
              </div>
            <% else %>
              <%= for merchant <- @merchants do %>
                <div
                  phx-click="select_merchant"
                  phx-value-id={merchant.id}
                  class="glass-panel p-6 rounded-2xl flex items-center justify-between hover:border-primary/50 transition-all cursor-pointer group hover:bg-base-200/30"
                >
                  <div class="flex items-center gap-6">
                    <div class="size-12 rounded-xl bg-base-200 flex items-center justify-center group-hover:bg-primary/10 transition-colors">
                      <.icon
                        name="hero-building-office"
                        class="size-6 text-base-content/40 group-hover:text-primary"
                      />
                    </div>
                    <div class="flex flex-col">
                      <h3 class="text-sm font-black text-base-content group-hover:text-primary transition-colors">
                        {merchant.business_name}
                      </h3>
                      <div class="flex items-center gap-3 mt-1">
                        <span class="text-[10px] font-mono text-base-content/40 bg-base-200 px-1.5 py-0.5 rounded leading-none">
                          {merchant.id |> String.slice(0, 8)}
                        </span>
                        <span class="text-[10px] font-bold text-base-content/30 uppercase tracking-tighter">
                          {merchant.city}, {merchant.state}
                        </span>
                      </div>
                    </div>
                  </div>

                  <div class="flex items-center gap-12">
                    <div class="flex flex-col items-end">
                      <span class="text-[9px] font-black text-base-content/30 uppercase tracking-widest mb-1.5 leading-none">
                        Plan
                      </span>
                      <div class="badge badge-outline border-base-300 text-[10px] font-bold uppercase py-0 h-4">
                        {merchant.plan}
                      </div>
                    </div>

                    <div class="flex flex-col items-end w-24">
                      <span class="text-[9px] font-black text-base-content/30 uppercase tracking-widest mb-1.5 leading-none">
                        Risk Level
                      </span>
                      <div class={[
                        "text-[10px] font-black uppercase tracking-widest flex items-center gap-1.5",
                        risk_color(merchant.risk_level)
                      ]}>
                        <div class={["size-1 rounded-full", risk_bg_color(merchant.risk_level)]}>
                        </div>
                        {merchant.risk_level}
                      </div>
                    </div>

                    <div class="flex flex-col items-end">
                      <span class="text-[9px] font-black text-base-content/30 uppercase tracking-widest mb-1.5 leading-none">
                        Status
                      </span>
                      <div class={[
                        "text-[10px] font-black uppercase tracking-widest flex items-center gap-2",
                        status_color(merchant.status)
                      ]}>
                        <div class={[
                          "size-1.5 rounded-full shadow-[0_0_8px_currentColor]",
                          status_bg_color(merchant.status)
                        ]}>
                        </div>
                        {merchant.status}
                      </div>
                    </div>

                    <div class="h-10 w-[1px] bg-base-200"></div>

                    <button class="btn btn-ghost btn-sm btn-circle text-base-content/20 hover:text-primary">
                      <.icon name="hero-chevron-right" class="size-4" />
                    </button>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </main>
    </div>
    """
  end

  defp active_count(merchants), do: Enum.count(merchants, &(&1.status == :active))
  defp pending_count(merchants), do: Enum.count(merchants, &(&1.status == :pending_verification))

  defp status_color(:active), do: "text-primary"
  defp status_color(:pending_verification), do: "text-warning"
  defp status_color(:suspended), do: "text-error"
  defp status_color(_), do: "text-base-content/40"

  defp status_bg_color(:active), do: "bg-primary"
  defp status_bg_color(:pending_verification), do: "bg-warning"
  defp status_bg_color(:suspended), do: "bg-error"
  defp status_bg_color(_), do: "bg-base-content/40"

  defp risk_color(:low), do: "text-primary"
  defp risk_color(:medium), do: "text-warning"
  defp risk_color(:high), do: "text-error"
  defp risk_color(_), do: "text-base-content/40"

  defp risk_bg_color(:low), do: "bg-primary"
  defp risk_bg_color(:medium), do: "bg-warning"
  defp risk_bg_color(:high), do: "bg-error"
  defp risk_bg_color(_), do: "bg-base-content/40"
end
