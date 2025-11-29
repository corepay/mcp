defmodule McpWeb.Tenant.Underwriting.Components.CoPilotChat do
  use McpWeb, :live_component

  alias Mcp.Chat.Conversation
  alias Mcp.Chat.Message
  require Ash.Query

  @impl true
  def update(assigns, socket) do
    socket = 
      socket
      |> assign(assigns)
      |> assign_new(:messages, fn -> [] end)
      |> assign_new(:input_value, fn -> "" end)
      |> assign_new(:loading, fn -> false end)
      |> load_conversation()

    {:ok, socket}
  end

  @impl true
  def handle_event("send_message", %{"text" => text}, socket) do
    if String.trim(text) == "" do
      {:noreply, socket}
    else
      # 1. Create User Message
      Mcp.Chat.Message
      |> Ash.Changeset.for_create(:create, %{
        text: text,
        conversation_id: socket.assigns.conversation.id
      })
      |> Ash.Changeset.force_change_attribute(:source, :user)
      |> Ash.create!(actor: socket.assigns.current_user)

      # 2. Trigger Agent Response (Async via Ash Reactor or just let the chain handle it)
      # For now, we rely on the existing Chat logic which should pick this up if configured,
      # or we explicitly trigger the response logic. 
      # Given the previous context, `Mcp.Chat.Message.Changes.Respond` handles this on create.
      
      {:noreply, 
       socket 
       |> assign(:input_value, "") 
       |> assign(:loading, true)
       |> load_messages()}
    end
  end

  @impl true
  def handle_event("toggle", _, socket) do
    send(self(), {:toggle_copilot})
    {:noreply, socket}
  end

  defp load_conversation(socket) do
    # Find or create a conversation linked to this application
    # We use a specific title convention or metadata to link it.
    # For simplicity, we'll just find the latest conversation for this user for now,
    # but ideally we'd store `application_id` in metadata.
    
    user = socket.assigns.current_user
    app_id = socket.assigns.application_id
    
    # Check for existing conversation with this metadata
    # Note: This assumes we can filter by metadata or we just use a naming convention
    title = "Underwriting Co-Pilot - App #{app_id}"
    
    conversation = 
      Conversation
      |> Ash.Query.filter(user_id == ^user.id and title == ^title)
      |> Ash.read_one!()
      
    conversation = 
      if conversation do
        conversation
      else
        Conversation
        |> Ash.Changeset.for_create(:create_for_user, %{
          title: title, 
          user_id: user.id
        })
        |> Ash.create!(actor: user)
      end

    socket
    |> assign(:conversation, conversation)
    |> load_messages()
  end

  defp load_messages(socket) do
    if socket.assigns[:conversation] do
      messages = 
        Message
        |> Ash.Query.filter(conversation_id == ^socket.assigns.conversation.id)
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.read!()
        
      assign(socket, :messages, messages)
    else
      socket
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full bg-base-100 border-l border-base-300 shadow-xl">
      <!-- Header -->
      <div class="p-4 border-b border-base-300 flex justify-between items-center bg-base-200/50">
        <div class="flex items-center gap-2">
          <div class="w-2 h-2 rounded-full bg-success animate-pulse"></div>
          <h3 class="font-bold text-base-content">Atlas Co-Pilot</h3>
        </div>
        <button phx-click="toggle" phx-target={@myself} class="btn btn-ghost btn-sm btn-square">
          <.icon name="hero-x-mark" class="w-5 h-5" />
        </button>
      </div>

      <!-- Messages Area -->
      <div class="flex-1 overflow-y-auto p-4 space-y-4" id="copilot-messages" phx-hook="ScrollToBottom">
        <%= if Enum.empty?(@messages) do %>
          <div class="text-center text-zinc-500 mt-10">
            <.icon name="hero-sparkles" class="w-12 h-12 mx-auto mb-2 opacity-50" />
            <p class="text-sm">I'm ready to help you analyze this application.</p>
            <p class="text-xs mt-2">Try "Analyze the bank statements"</p>
          </div>
        <% else %>
          <%= for msg <- @messages do %>
            <div class={"flex #{if msg.source == :user, do: "justify-end", else: "justify-start"}"}>
              <div class={"max-w-[85%] rounded-2xl px-4 py-2 text-sm #{
                if msg.source == :user, 
                  do: "bg-primary text-primary-content rounded-br-none", 
                  else: "bg-base-200 text-base-content rounded-bl-none"
              }"}>
                <%= if msg.source == :agent do %>
                <div class="prose prose-sm dark:prose-invert max-w-none">
                  <%= raw(MDEx.to_html!(msg.text || "")) %>
                </div>
                  <%= if msg.tool_calls && !Enum.empty?(msg.tool_calls) do %>
                    <div class="mt-2 text-xs opacity-70 flex items-center gap-1">
                      <.icon name="hero-cog-6-tooth" class="w-3 h-3" />
                      <span>Using tools...</span>
                    </div>
                  <% end %>
                <% else %>
                  <%= msg.text %>
                <% end %>
              </div>
            </div>
          <% end %>
        <% end %>
        
        <%= if @loading do %>
          <div class="flex justify-start">
            <div class="bg-base-200 rounded-2xl rounded-bl-none px-4 py-3">
              <span class="loading loading-dots loading-sm"></span>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Input Area -->
      <div class="p-4 border-t border-base-300 bg-base-200/30">
        <form phx-submit="send_message" phx-target={@myself}>
          <div class="flex gap-2">
            <input 
              type="text" 
              name="text" 
              value={@input_value} 
              placeholder="Ask Atlas..." 
              class="input input-bordered w-full input-sm focus:outline-none focus:border-primary" 
              autocomplete="off"
            />
            <button type="submit" class="btn btn-primary btn-sm btn-square">
              <.icon name="hero-paper-airplane" class="w-4 h-4" />
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
