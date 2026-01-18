defmodule McpWeb.Tenant.Components.ExecutiveChat do
  use McpWeb, :live_component

  def mount(socket) do
    {:ok,
     socket
     |> assign(:messages, [])
     |> assign(:input_value, "")
     |> assign(:is_open, false)
     |> assign(:loading, false)}
  end

  def update(assigns, socket) do
    socket =
      cond do
        msg = assigns[:ai_response] ->
          new_msg = %{role: :assistant, content: msg, timestamp: DateTime.utc_now()}

          socket
          |> assign(:messages, socket.assigns.messages ++ [new_msg])
          |> assign(:loading, false)

        assigns[:loading] == false ->
          assign(socket, :loading, false)

        true ->
          socket
      end

    {:ok, assign(socket, Map.drop(assigns, [:ai_response]))}
  end

  def handle_event("toggle_chat", _params, socket) do
    {:noreply, assign(socket, :is_open, !socket.assigns.is_open)}
  end

  def handle_event("submit_message", %{"message" => query}, socket) when query != "" do
    # 1. Optimistic update
    user_msg = %{role: :user, content: query, timestamp: DateTime.utc_now()}

    socket =
      socket
      |> assign(:messages, socket.assigns.messages ++ [user_msg])
      |> assign(:input_value, "")
      |> assign(:loading, true)

    # 2. Async call to AI (using send_after to simulate or just call directly for now)
    # In a real app we might use a task or internal message,
    # but for simplicity we'll call the action here.
    send(self(), {:generate_ai_response, query, socket.assigns.context_summary})

    {:noreply, socket}
  end

  def handle_event("submit_message", _, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <div class={[
      "font-sans h-full flex flex-col",
      !assigns[:embedded] && "fixed bottom-8 right-8 z-[100]"
    ]}>
      <%!-- Floating Trigger Button (Hidden in embedded mode) --%>
      <%= if !assigns[:embedded] do %>
        <button
          phx-click="toggle_chat"
          phx-target={@myself}
          class={[
            "size-14 rounded-full flex items-center justify-center shadow-2xl transition-all duration-500 ml-auto",
            if(@is_open,
              do: "bg-base-300 rotate-90 scale-90",
              else: "bg-primary text-primary-content hover:scale-110 active:scale-95"
            )
          ]}
        >
          <%= if @is_open do %>
            <.icon name="hero-x-mark" class="size-6" />
          <% else %>
            <div class="relative">
              <.icon name="hero-bolt" class="size-6" />
              <span class="absolute -top-1 -right-1 size-2.5 bg-accent rounded-full border-2 border-primary animate-ping">
              </span>
            </div>
          <% end %>
        </button>
      <% end %>

      <%!-- Chat Window --%>
      <div class={[
        "flex flex-col h-full overflow-hidden transition-all duration-500",
        if(assigns[:embedded],
          do: "bg-black/10 rounded-2xl border border-white/5 shadow-inner",
          else:
            "absolute bottom-20 right-0 w-[420px] h-[600px] glass-panel rounded-[2rem] shadow-2xl border border-white/10 origin-bottom-right " <>
              if(@is_open,
                do: "scale-100 opacity-100 translate-y-0",
                else: "scale-50 opacity-0 translate-y-10 pointer-events-none"
              )
        )
      ]}>
        <%!-- Header (Simplified in embedded mode) --%>
        <div class="p-4 border-b border-white/5 bg-primary/5 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="size-8 rounded-xl bg-primary/20 flex items-center justify-center text-primary border border-primary/30">
              <.icon name="hero-bolt" class="size-5" />
            </div>
            <div class="flex flex-col">
              <span class="text-[10px] font-black uppercase tracking-[0.2em] text-primary">
                Executive Assistant
              </span>
              <span class="text-[8px] font-bold text-base-content/40 uppercase tracking-widest">
                Active Strategic Link
              </span>
            </div>
          </div>
          <%= if assigns[:embedded] do %>
            <div class="flex gap-1.5">
              <span class="size-1.5 bg-primary rounded-full animate-pulse"></span>
              <span class="size-1.5 bg-primary rounded-full animate-pulse [animation-delay:0.2s]">
              </span>
            </div>
          <% end %>
        </div>

        <%!-- Messages Area --%>
        <div
          id="executive-chat-scroll"
          class="flex-1 overflow-y-auto p-4 space-y-4 custom-scrollbar"
          phx-hook="ScrollToBottom"
        >
          <%= if Enum.empty?(@messages) do %>
            <div class="h-full flex flex-col items-center justify-center text-center space-y-4 px-4 grayscale opacity-40">
              <div class="size-12 rounded-full bg-base-200 flex items-center justify-center">
                <.icon name="hero-chat-bubble-left-right" class="size-6" />
              </div>
              <p class="text-[10px] font-black uppercase tracking-[0.2em] leading-relaxed">
                Awaiting Strategic Query
              </p>
            </div>
          <% else %>
            <%= for msg <- @messages do %>
              <div class={[
                "flex flex-col gap-1 max-w-[85%] w-fit",
                if(msg.role == :user, do: "ml-auto items-end", else: "items-start text-left")
              ]}>
                <%= if msg.role == :assistant do %>
                  <div class="flex items-center gap-1 mb-0.5 opacity-40 ml-0.5">
                    <.icon name="hero-bolt-solid" class="size-2.5 text-primary" />
                    <span class="text-[7px] font-black uppercase tracking-tighter">Atlas</span>
                  </div>
                <% end %>
                <div class={[
                  "p-[2px] rounded-md text-[10.5px] leading-tight transition-all duration-300",
                  if(msg.role == :user,
                    do: "bg-primary/10 text-primary-content border border-primary/20",
                    else: "bg-white/[0.04] text-base-content/90 border border-white/5"
                  )
                ]}>
                  <div class="px-2 py-1">
                    {msg.content}
                  </div>
                </div>
              </div>
            <% end %>

            <%= if @loading do %>
              <div class="flex flex-col items-start gap-1 max-w-[85%] w-fit text-left">
                <div class="flex items-center gap-1 mb-0.5 opacity-40 ml-0.5">
                  <.icon name="hero-bolt-solid" class="size-2.5 text-primary" />
                  <span class="text-[7px] font-black uppercase tracking-tighter text-primary">Atlas is thinking</span>
                </div>
                <div class="bg-white/[0.04] p-2 rounded-md border border-white/5">
                  <div class="flex gap-1">
                    <div class="size-1 bg-primary rounded-full animate-bounce"></div>
                    <div class="size-1 bg-primary rounded-full animate-bounce [animation-delay:0.2s]">
                    </div>
                    <div class="size-1 bg-primary rounded-full animate-bounce [animation-delay:0.4s]">
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>

        <%!-- Input Area --%>
        <div class="p-4 bg-base-100/50 border-t border-white/5">
          <form phx-submit="submit_message" phx-target={@myself} class="relative">
            <input
              type="text"
              name="message"
              placeholder="Query portfolio..."
              class="w-full bg-base-200 border-none rounded-xl py-3 pl-4 pr-12 text-[11px] focus:ring-1 focus:ring-primary/50 transition-all placeholder:text-base-content/20"
              autocomplete="off"
            />
            <button
              type="submit"
              class="absolute right-1 top-1 size-8 rounded-lg bg-primary text-primary-content flex items-center justify-center hover:scale-105 active:scale-95 transition-all"
            >
              <.icon name="hero-arrow-up-right" class="size-4" />
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
