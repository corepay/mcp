defmodule McpWeb.Components.Terminal.AiAssistantModal do
  @moduledoc """
  AI Assistant / Command Palette modal for the Virtual Terminal.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1, modal: 1]
  alias Phoenix.LiveView.JS

  attr :show, :boolean, default: false
  attr :processing, :boolean, default: false
  attr :customer, :map, default: nil
  attr :cart_total, :any, default: nil
  attr :on_close, :string, default: "toggle_ai_assistant"
  attr :on_submit, :string, default: "ai_submit"

  def ai_assistant_modal(assigns) do
    ~H"""
    <.modal :if={@show} show id="ai_assistant_modal" on_cancel={JS.push(@on_close)}>
      <div class="ai-assistant-content -m-6 flex flex-col h-[500px]">
        <!-- Header / Input -->
        <div class="p-4 border-b border-base-300 bg-base-100 sticky top-0 z-10">
          <div class="flex items-center gap-3 text-primary mb-2">
            <.icon name="hero-sparkles" class="size-5" />
            <span class="font-semibold text-sm uppercase tracking-wide">Terminal Intelligence</span>
          </div>

          <form phx-submit={@on_submit} class="relative">
            <input
              type="text"
              name="prompt"
              placeholder="Ask about this customer, draft an email, or analyze trends..."
              class="w-full bg-base-200 border-none rounded-lg py-3 pl-4 pr-12 text-lg focus:ring-2 focus:ring-primary/50 placeholder:text-base-content/40"
              autocomplete="off"
              autofocus
            />
            <button
              type="submit"
              class="absolute right-2 top-1/2 -translate-y-1/2 btn btn-ghost btn-sm btn-circle"
            >
              <.icon name="hero-arrow-right" class="size-5" />
            </button>
          </form>
        </div>
        
    <!-- Content Area -->
        <div class="flex-1 overflow-y-auto p-4 space-y-6 bg-base-100">
          <!-- Contextual Suggestions -->
          <div>
            <h4 class="text-xs font-bold text-base-content/50 uppercase mb-3">Suggested Actions</h4>
            <div class="grid grid-cols-1 gap-2">
              <button
                :if={@customer}
                type="button"
                class="flex items-center gap-3 p-3 rounded-lg hover:bg-base-200 border border-base-200 hover:border-base-300 transition-all text-left group"
                phx-click={@on_submit}
                phx-value-prompt={"Draft invoice email for #{@customer.name}"}
              >
                <div class="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-primary group-hover:bg-primary group-hover:text-primary-content transition-colors">
                  <.icon name="hero-envelope" class="size-4" />
                </div>
                <div>
                  <div class="font-medium text-sm">Draft invoice email</div>
                  <div class="text-xs text-base-content/60">For {@customer.email}</div>
                </div>
              </button>

              <button
                type="button"
                class="flex items-center gap-3 p-3 rounded-lg hover:bg-base-200 border border-base-200 hover:border-base-300 transition-all text-left group"
                phx-click={@on_submit}
                phx-value-prompt="Analyze recent sales performance"
              >
                <div class="w-8 h-8 rounded-full bg-secondary/10 flex items-center justify-center text-secondary group-hover:bg-secondary group-hover:text-secondary-content transition-colors">
                  <.icon name="hero-chart-bar" class="size-4" />
                </div>
                <div>
                  <div class="font-medium text-sm">Analyze sales trends</div>
                  <div class="text-xs text-base-content/60">Comparing this week vs last week</div>
                </div>
              </button>

              <button
                :if={@cart_total && Decimal.gt?(@cart_total, 0)}
                type="button"
                class="flex items-center gap-3 p-3 rounded-lg hover:bg-base-200 border border-base-200 hover:border-base-300 transition-all text-left group"
                phx-click={@on_submit}
                phx-value-prompt="Check for potential fraud"
              >
                <div class="w-8 h-8 rounded-full bg-warning/10 flex items-center justify-center text-warning group-hover:bg-warning group-hover:text-warning-content transition-colors">
                  <.icon name="hero-shield-check" class="size-4" />
                </div>
                <div>
                  <div class="font-medium text-sm">Risk Assessment</div>
                  <div class="text-xs text-base-content/60">Analyze current cart contents</div>
                </div>
              </button>
            </div>
          </div>
          
    <!-- Capabilities -->
          <div>
            <h4 class="text-xs font-bold text-base-content/50 uppercase mb-3">Capabilities</h4>
            <div class="flex flex-wrap gap-2">
              <span class="badge badge-lg badge-ghost gap-1 pl-1.5">
                <.icon name="hero-user" class="size-3.5 opacity-60" /> Customer Insights
              </span>
              <span class="badge badge-lg badge-ghost gap-1 pl-1.5">
                <.icon name="hero-document-text" class="size-3.5 opacity-60" /> Content Generation
              </span>
              <span class="badge badge-lg badge-ghost gap-1 pl-1.5">
                <.icon name="hero-calculator" class="size-3.5 opacity-60" /> Smart Pricing
              </span>
            </div>
          </div>
        </div>
      </div>
    </.modal>
    """
  end
end
