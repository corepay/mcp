defmodule McpWeb.Components.AtlasConciergeComponent do
  @moduledoc """
  Floating AI Concierge component for the OLA flow.
  Provides contextual help and chat interface.
  """
  use McpWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed bottom-6 right-6 z-50 flex flex-col items-end gap-2">
      <!-- Proactive Hint Bubble -->
      <%= if @hint && !@expanded do %>
        <div class="animate-bounce-in bg-white dark:bg-gray-800 shadow-xl rounded-2xl p-4 max-w-xs mb-2 border border-blue-100 dark:border-blue-900 relative">
          <button
            phx-click="dismiss_hint"
            phx-target={@myself}
            class="absolute top-2 right-2 text-gray-400 hover:text-gray-600"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>
          <div class="flex gap-3">
            <div class="shrink-0">
              <div class="w-10 h-10 rounded-full bg-blue-100 dark:bg-blue-900 flex items-center justify-center">
                <.icon name="hero-sparkles" class="w-6 h-6 text-blue-600 dark:text-blue-400" />
              </div>
            </div>
            <div>
              <p class="text-sm text-gray-700 dark:text-gray-200">{@hint}</p>
              <button
                phx-click="toggle"
                phx-target={@myself}
                class="text-xs font-semibold text-blue-600 hover:underline mt-1"
              >
                Chat with Atlas
              </button>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Main Chat Window -->
      <%= if @expanded do %>
        <div class="bg-white dark:bg-gray-800 shadow-2xl rounded-2xl w-80 sm:w-96 flex flex-col max-h-[600px] border border-gray-200 dark:border-gray-700 overflow-hidden transform transition-all duration-200 ease-out origin-bottom-right">
          <!-- Header -->
          <div class="bg-gradient-to-r from-blue-600 to-indigo-600 p-4 flex justify-between items-center text-white">
            <div class="flex items-center gap-2">
              <.icon name="hero-sparkles" class="w-5 h-5" />
              <span class="font-semibold">Atlas Concierge</span>
            </div>
            <button phx-click="toggle" phx-target={@myself} class="hover:bg-white/20 rounded-full p-1">
              <.icon name="hero-minus" class="w-5 h-5" />
            </button>
          </div>
          
    <!-- Messages Area -->
          <div
            id="atlas-messages"
            class="flex-1 overflow-y-auto p-4 space-y-4 min-h-[300px] max-h-[400px]"
            phx-hook="ScrollBottom"
          >
            <%= for msg <- @messages do %>
              <div class={"flex #{if msg.role == :user, do: "justify-end", else: "justify-start"}"}>
                <div class={"max-w-[85%] rounded-2xl px-4 py-2 text-sm #{
                  if msg.role == :user,
                    do: "bg-blue-600 text-white rounded-br-none",
                    else: "bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-200 rounded-bl-none"
                }"}>
                  <p>{msg.content}</p>
                </div>
              </div>
            <% end %>

            <%= if @loading do %>
              <div class="flex justify-start">
                <div class="bg-gray-100 dark:bg-gray-700 rounded-2xl rounded-bl-none px-4 py-2 flex gap-1 items-center">
                  <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
                  <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce delay-100"></div>
                  <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce delay-200"></div>
                </div>
              </div>
            <% end %>
          </div>
          
    <!-- Input Area -->
          <form
            phx-submit="send"
            phx-target={@myself}
            class="p-3 border-t border-gray-100 dark:border-gray-700 bg-gray-50 dark:bg-gray-900"
          >
            <div class="relative">
              <input
                type="text"
                name="msg"
                value={@input_value}
                placeholder="Ask me anything..."
                class="w-full rounded-full border-gray-300 dark:border-gray-600 pl-4 pr-10 py-2 text-sm focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-800 dark:text-white"
                autocomplete="off"
              />
              <button
                type="submit"
                class="absolute right-2 top-1/2 -translate-y-1/2 p-1 text-blue-600 hover:text-blue-700 disabled:opacity-50"
                disabled={@loading}
              >
                <.icon name="hero-paper-airplane" class="w-5 h-5" />
              </button>
            </div>
          </form>
        </div>
      <% else %>
        <!-- Minimized Floating Button -->
        <button
          phx-click="toggle"
          phx-target={@myself}
          class="bg-blue-600 hover:bg-blue-700 text-white rounded-full p-4 shadow-lg transition-transform hover:scale-110 group"
        >
          <.icon
            name="hero-chat-bubble-left-right"
            class="w-7 h-7 group-hover:scale-110 transition-transform"
          />
          
    <!-- Unread indicator -->
          <%= if @unread_count > 0 do %>
            <span class="absolute -top-1 -right-1 bg-red-500 text-white text-xs font-bold w-5 h-5 rounded-full flex items-center justify-center border-2 border-white dark:border-gray-900">
              {@unread_count}
            </span>
          <% end %>
        </button>
      <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:expanded, fn -> false end)
      |> assign_new(:messages, fn ->
        [
          %{
            role: :assistant,
            content: "Hi! I'm Atlas. I can help you complete this application. Ask me anything!"
          }
        ]
      end)
      |> assign_new(:input_value, fn -> "" end)
      |> assign_new(:loading, fn -> false end)
      |> assign_new(:hint, fn -> nil end)
      # Initial greeting is unread
      |> assign_new(:unread_count, fn -> 1 end)

    # If new step guidance is provided via parent assign update, generate proactive help
    # This logic handles external triggers

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle", _, socket) do
    new_state = !socket.assigns.expanded
    {:noreply, assign(socket, expanded: new_state, unread_count: 0, hint: nil)}
  end

  @impl true
  def handle_event("dismiss_hint", _, socket) do
    {:noreply, assign(socket, hint: nil)}
  end

  @impl true
  def handle_event("send", %{"msg" => msg}, socket) do
    if String.trim(msg) == "" do
      {:noreply, socket}
    else
      # Optimistic update
      user_msg = %{role: :user, content: msg}
      messages = socket.assigns.messages ++ [user_msg]

      # Start async task
      send(self(), {:generate_atlas_response, msg})

      {:noreply, assign(socket, messages: messages, input_value: "", loading: true)}
    end
  end
end
