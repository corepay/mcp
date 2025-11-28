defmodule McpWeb.Tenant.ApplicationDetailLive do
  use McpWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    # Mock data
    application = %{
      id: id,
      business_name: "Mega Corp",
      status: :underwriting,
      risk_score: 45,
      inserted_at: DateTime.utc_now(),
      owner: %{name: "John Doe", email: "john@megacorp.com"},
      timeline: [
        %{event: "Application Submitted", time: DateTime.utc_now() |> DateTime.add(-3600, :second)},
        %{event: "Identity Verified", time: DateTime.utc_now() |> DateTime.add(-3000, :second)},
        %{event: "Risk Assessment Started", time: DateTime.utc_now() |> DateTime.add(-100, :second)}
      ],
      atlas_chat: [
        %{sender: :ai, content: "Hello! I'm Atlas. How would you like to complete your application today?"},
        %{sender: :user, content: "Chat with Atlas"},
        %{sender: :ai, content: "Great choice! I'll ask you a few questions to get your business approved. First, what is the legal name of your business?"},
        %{sender: :user, content: "Mega Corp"}
      ]
    }

    {:ok,
     socket
     |> assign(:page_title, "Application: #{application.business_name}")
     |> assign(:application, application)}
  end

  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Header with Actions -->
      <div class="flex items-center justify-between p-6 border-b border-base-200 bg-base-100">
        <div>
          <div class="flex items-center gap-3">
            <h1 class="text-2xl font-bold"><%= @application.business_name %></h1>
            <div class="badge badge-warning">Underwriting</div>
          </div>
          <p class="text-sm text-base-content/60 mt-1">ID: <%= @application.id %> • Submitted <%= Calendar.strftime(@application.inserted_at, "%b %d, %Y") %></p>
        </div>
        <div class="flex gap-2">
          <button class="btn btn-outline btn-error btn-sm">Reject</button>
          <button class="btn btn-outline btn-warning btn-sm">Request Info</button>
          <button class="btn btn-primary btn-sm">Approve</button>
        </div>
      </div>

      <div class="flex-1 overflow-hidden flex">
        <!-- Main Content (Risk Dossier & Details) -->
        <div class="flex-1 overflow-y-auto p-6 space-y-6">
          <!-- Risk Score Card -->
          <div class="card bg-base-100 shadow-sm border border-base-200">
            <div class="card-body">
              <h3 class="card-title text-sm uppercase tracking-wider text-base-content/60">Risk Assessment</h3>
              <div class="flex items-center gap-6 mt-2">
                <div class="radial-progress text-warning" style={"--value:#{@application.risk_score}; --size:4rem;"}>
                  <%= @application.risk_score %>
                </div>
                <div>
                  <div class="font-bold">Moderate Risk</div>
                  <div class="text-sm text-base-content/70">Flagged for manual review due to high transaction volume estimate.</div>
                </div>
              </div>
            </div>
          </div>

          <!-- Application Details -->
          <div class="card bg-base-100 shadow-sm border border-base-200">
            <div class="card-body">
              <h3 class="card-title text-sm uppercase tracking-wider text-base-content/60 mb-4">Business Information</h3>
              <dl class="grid grid-cols-1 sm:grid-cols-2 gap-x-4 gap-y-6">
                <div>
                  <dt class="text-xs text-base-content/60">Legal Name</dt>
                  <dd class="font-medium"><%= @application.business_name %></dd>
                </div>
                <div>
                  <dt class="text-xs text-base-content/60">Owner</dt>
                  <dd class="font-medium"><%= @application.owner.name %> (<%= @application.owner.email %>)</dd>
                </div>
                <!-- More fields would go here -->
              </dl>
            </div>
          </div>
          
          <!-- Timeline -->
          <div class="card bg-base-100 shadow-sm border border-base-200">
            <div class="card-body">
              <h3 class="card-title text-sm uppercase tracking-wider text-base-content/60 mb-4">Timeline</h3>
              <ul class="steps steps-vertical">
                <%= for event <- @application.timeline do %>
                  <li class="step step-primary">
                    <div class="text-left">
                      <div class="font-bold"><%= event.event %></div>
                      <div class="text-xs text-base-content/60"><%= Calendar.strftime(event.time, "%I:%M %p") %></div>
                    </div>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>
        </div>

        <!-- Sidebar (Atlas Chat History) -->
        <div class="w-96 border-l border-base-200 bg-base-50 flex flex-col">
          <div class="p-4 border-b border-base-200 font-bold flex items-center gap-2">
            <.icon name="hero-chat-bubble-left-right" class="w-5 h-5" />
            Communication Log
          </div>
          <div class="flex-1 overflow-y-auto p-4 space-y-4">
            <%= for msg <- @application.atlas_chat do %>
              <div class={"chat #{if msg.sender == :user, do: "chat-end", else: "chat-start"}"}>
                <div class="chat-header opacity-50 text-xs mb-1">
                  <%= if msg.sender == :user, do: "Applicant", else: "Atlas" %>
                </div>
                <div class={"chat-bubble text-sm #{if msg.sender == :user, do: "chat-bubble-neutral", else: "chat-bubble-primary"}"}>
                  <%= msg.content %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
