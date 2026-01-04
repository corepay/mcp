defmodule McpWeb.Ola.Components.AtlasChat do
  @moduledoc """
  Atlas AI chat component for OLA application.
  Provides real-time, context-aware assistance.
  """
  use McpWeb, :live_component

  alias Mcp.Underwriting.Atlas.{Agent, ConversationContext}

  # Check every 5 seconds
  @idle_check_interval 5_000
  # Trigger help after 30 seconds
  @idle_threshold 30

  def mount(socket) do
    socket =
      socket
      |> assign(:messages, [])
      |> assign(:input_value, "")
      |> assign(:last_activity, System.monotonic_time(:second))
      |> assign(:proactive_shown, false)

    # Start idle checking timer
    if connected?(socket) do
      Process.send_after(self(), :check_idle, @idle_check_interval)
    end

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(:current_step, assigns[:current_step] || :business_info)
      |> assign(:form_data, assigns[:form_data] || %{})
      |> assign(:session_state, assigns[:session_state] || %{})

    {:ok, socket}
  end

  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    # Add user message
    user_msg = %{id: make_ref(), role: :user, content: message, timestamp: DateTime.utc_now()}
    messages = socket.assigns.messages ++ [user_msg]

    # Build context and generate response
    context =
      ConversationContext.build_context(
        socket.assigns.current_step,
        socket.assigns.form_data,
        socket.assigns.session_state
      )

    socket =
      case Agent.generate_response(message, context) do
        {:ok, response} when not is_nil(response) ->
          ai_msg = %{
            id: make_ref(),
            role: :assistant,
            content: response.message,
            type: response.type,
            timestamp: DateTime.utc_now()
          }

          assign(socket, :messages, messages ++ [ai_msg])

        _ ->
          assign(socket, :messages, messages)
      end

    {:noreply,
     socket
     |> assign(:input_value, "")
     |> assign(:last_activity, System.monotonic_time(:second))
     |> assign(:proactive_shown, false)}
  end

  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("update_input", %{"value" => value}, socket) do
    {:noreply,
     socket
     |> assign(:input_value, value)
     |> assign(:last_activity, System.monotonic_time(:second))}
  end

  def handle_info(:check_idle, socket) do
    # Schedule next check
    Process.send_after(self(), :check_idle, @idle_check_interval)

    idle_seconds = System.monotonic_time(:second) - socket.assigns.last_activity

    socket =
      if idle_seconds > @idle_threshold && not socket.assigns.proactive_shown do
        # Build context with idle info
        session_state = Map.merge(socket.assigns.session_state, %{idle_seconds: idle_seconds})

        context =
          ConversationContext.build_context(
            socket.assigns.current_step,
            socket.assigns.form_data,
            session_state
          )

        case Agent.generate_response("", context) do
          {:ok, response} when not is_nil(response) ->
            ai_msg = %{
              id: make_ref(),
              role: :assistant,
              content: response.message,
              type: :proactive_help,
              timestamp: DateTime.utc_now()
            }

            socket
            |> assign(:messages, socket.assigns.messages ++ [ai_msg])
            |> assign(:proactive_shown, true)

          _ ->
            socket
        end
      else
        socket
      end

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="atlas-chat flex flex-col h-full">
      <!-- Chat header -->
      <div class="flex items-center gap-2 p-3 border-b border-base-300">
        <div class="avatar">
          <div class="w-8 h-8 rounded-full bg-primary text-primary-content flex items-center justify-center">
            <.icon name="hero-sparkles" class="w-5 h-5" />
          </div>
        </div>
        <div>
          <div class="font-semibold text-sm">Atlas</div>
          <div class="text-xs text-base-content/60">Your application assistant</div>
        </div>
      </div>
      
    <!-- Messages area -->
      <div class="flex-1 overflow-y-auto p-3 space-y-3" id={"atlas-messages-#{@myself.cid}"}>
        <%= if Enum.empty?(@messages) do %>
          <div class="text-center text-base-content/60 py-8">
            <.icon name="hero-chat-bubble-left-right" class="w-12 h-12 mx-auto mb-2 opacity-50" />
            <p class="text-sm">Hi! I'm Atlas, your application assistant.</p>
            <p class="text-xs mt-1">Ask me anything about the form!</p>
          </div>
        <% else %>
          <%= for msg <- @messages do %>
            <div class={[
              "chat",
              if(msg.role == :user, do: "chat-end", else: "chat-start")
            ]}>
              <div class={[
                "chat-bubble text-sm",
                if(msg.role == :user, do: "chat-bubble-primary", else: "chat-bubble-secondary")
              ]}>
                {msg.content}
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
      
    <!-- Input area -->
      <form phx-submit="send_message" phx-target={@myself} class="p-3 border-t border-base-300">
        <div class="flex gap-2">
          <input
            type="text"
            name="message"
            value={@input_value}
            phx-change="update_input"
            phx-target={@myself}
            placeholder="Ask Atlas anything..."
            class="input input-bordered input-sm flex-1"
            autocomplete="off"
          />
          <button type="submit" class="btn btn-primary btn-sm">
            <.icon name="hero-paper-airplane" class="w-4 h-4" />
          </button>
        </div>
      </form>
    </div>
    """
  end
end
