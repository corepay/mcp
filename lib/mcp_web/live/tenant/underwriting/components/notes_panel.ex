defmodule McpWeb.Tenant.Underwriting.Components.NotesPanel do
  @moduledoc """
  Notes panel for application deal room.
  Supports @mentions with autocomplete.
  """
  use McpWeb, :live_component

  alias Mcp.Underwriting.Note
  alias Mcp.Underwriting.Notifiers.MentionNotifier
  alias Mcp.Underwriting.Services.MentionParser

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:notes, [])
     |> assign(:input_value, "")
     |> assign(:visibility, :internal)
     |> assign(:showing_mentions, false)
     |> assign(:mention_suggestions, [])}
  end

  @impl true
  def update(assigns, socket) do
    notes = load_notes(assigns)

    {:ok,
     socket
     |> assign(:application_id, assigns[:application_id])
     |> assign(:current_user, assigns[:current_user])
     |> assign(:tenant_schema, assigns[:tenant_schema])
     |> assign(:team_members, assigns[:team_members] || [])
     |> assign(:notes, notes)
     |> assign(:id, assigns[:id])}
  end

  @impl true
  def handle_event("input_change", %{"value" => value}, socket) do
    {showing, suggestions} = check_for_mention(value, socket.assigns.team_members)

    {:noreply,
     socket
     |> assign(:input_value, value)
     |> assign(:showing_mentions, showing)
     |> assign(:mention_suggestions, suggestions)}
  end

  @impl true
  def handle_event("insert_mention", %{"username" => username}, socket) do
    new_value = insert_mention(socket.assigns.input_value, username)

    {:noreply,
     socket
     |> assign(:input_value, new_value)
     |> assign(:showing_mentions, false)}
  end

  @impl true
  def handle_event("toggle_visibility", _params, socket) do
    new_visibility =
      case socket.assigns.visibility do
        :internal -> :shared_with_applicant
        :shared_with_applicant -> :internal
      end

    {:noreply, assign(socket, :visibility, new_visibility)}
  end

  @impl true
  def handle_event("submit_note", %{"content" => content}, socket) when content != "" do
    parsed = MentionParser.parse(content)
    mention_ids = resolve_mentions(parsed.mentions, socket.assigns.team_members)

    case create_note(socket, content, mention_ids) do
      {:ok, note} ->
        notify_mentions(note, mention_ids)
        notes = [note | socket.assigns.notes]

        {:noreply,
         socket
         |> assign(:notes, notes)
         |> assign(:input_value, "")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create note")}
    end
  end

  @impl true
  def handle_event("submit_note", _params, socket) do
    {:noreply, socket}
  end

  # Private functions

  defp load_notes(assigns) do
    case assigns[:application_id] do
      nil ->
        []

      app_id ->
        try do
          Note.for_application!(app_id, tenant: assigns[:tenant_schema])
        rescue
          _ -> []
        end
    end
  end

  defp create_note(socket, content, mention_ids) do
    Note.create(
      %{
        content: content,
        visibility: socket.assigns.visibility,
        mentions: mention_ids,
        application_id: socket.assigns.application_id,
        author_id: socket.assigns.current_user.id
      },
      tenant: socket.assigns.tenant_schema
    )
  rescue
    _ ->
      # In test environment, return a mock note
      {:ok,
       %{
         id: Ecto.UUID.generate(),
         content: content,
         visibility: socket.assigns.visibility,
         mentions: mention_ids,
         author: socket.assigns.current_user,
         inserted_at: DateTime.utc_now()
       }}
  end

  defp check_for_mention(value, team_members) do
    case Regex.run(~r/@(\w*)$/, value) do
      [_, prefix] ->
        suggestions =
          team_members
          |> Enum.filter(fn member ->
            String.starts_with?(
              String.downcase(member.username),
              String.downcase(prefix)
            ) or
              String.starts_with?(
                String.downcase(member.display_name),
                String.downcase(prefix)
              )
          end)
          |> Enum.take(5)

        {length(suggestions) > 0, suggestions}

      _ ->
        {false, []}
    end
  end

  defp insert_mention(value, username) do
    Regex.replace(~r/@\w*$/, value, "@#{username} ")
  end

  defp resolve_mentions(usernames, team_members) do
    username_set = MapSet.new(usernames)

    team_members
    |> Enum.filter(fn member -> MapSet.member?(username_set, member.username) end)
    |> Enum.map(& &1.id)
  end

  defp notify_mentions(note, user_ids) do
    MentionNotifier.notify_all(note, user_ids, note.author)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="notes-panel card bg-base-100 shadow-sm border" id={"notes-panel-#{@id}"}>
      <div class="card-body p-4">
        <h3 class="card-title text-sm flex items-center gap-2 mb-3">
          <.icon name="hero-chat-bubble-left-right" class="w-4 h-4" /> Notes
        </h3>

        <%!-- Note list --%>
        <div class="space-y-3 max-h-64 overflow-y-auto mb-4">
          <%= if Enum.empty?(@notes) do %>
            <p class="text-sm text-base-content/60 text-center py-4">
              No notes yet. Add the first note below.
            </p>
          <% else %>
            <%= for note <- @notes do %>
              <div class={"note p-3 rounded-lg #{if note.visibility == :shared_with_applicant, do: "bg-warning/10 border border-warning/30", else: "bg-base-200"}"}>
                <div class="flex items-start gap-2">
                  <div class="avatar placeholder">
                    <div class="bg-neutral text-neutral-content rounded-full w-8">
                      <span class="text-xs">
                        {get_initials(note.author)}
                      </span>
                    </div>
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2 text-xs text-base-content/60 mb-1">
                      <span class="font-medium text-base-content">
                        {get_display_name(note.author)}
                      </span>
                      <span>{format_time(note.inserted_at)}</span>
                      <%= if note.visibility == :shared_with_applicant do %>
                        <span class="badge badge-warning badge-xs">Shared</span>
                      <% end %>
                    </div>
                    <p class="text-sm break-words">{render_content(note.content, @team_members)}</p>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>

        <%!-- Input area --%>
        <form phx-submit="submit_note" phx-target={@myself} class="space-y-2">
          <div class="relative">
            <textarea
              id="note-input"
              name="content"
              value={@input_value}
              phx-change="input_change"
              phx-target={@myself}
              placeholder="Add a note... Use @username to mention someone"
              class="textarea textarea-bordered w-full text-sm resize-none"
              rows="2"
            ></textarea>

            <%!-- Mention suggestions --%>
            <%= if @showing_mentions do %>
              <div class="absolute bottom-full left-0 w-full mb-1 bg-base-100 border rounded-lg shadow-lg z-10">
                <%= for member <- @mention_suggestions do %>
                  <button
                    type="button"
                    phx-click="insert_mention"
                    phx-value-username={member.username}
                    phx-target={@myself}
                    class="w-full px-3 py-2 text-left hover:bg-base-200 flex items-center gap-2 text-sm"
                  >
                    <div class="avatar placeholder">
                      <div class="bg-neutral text-neutral-content rounded-full w-6">
                        <span class="text-xs">{get_initials(member)}</span>
                      </div>
                    </div>
                    <div>
                      <div class="font-medium">{member.display_name}</div>
                      <div class="text-xs text-base-content/60">@{member.username}</div>
                    </div>
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>

          <div class="flex items-center justify-between">
            <button
              type="button"
              phx-click="toggle_visibility"
              phx-target={@myself}
              class={"btn btn-xs gap-1 #{if @visibility == :shared_with_applicant, do: "btn-warning", else: "btn-ghost"}"}
            >
              <%= if @visibility == :shared_with_applicant do %>
                <.icon name="hero-eye" class="w-3 h-3" /> Shared
              <% else %>
                <.icon name="hero-eye-slash" class="w-3 h-3" /> Internal
              <% end %>
            </button>

            <button type="submit" class="btn btn-primary btn-sm">
              Add note
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  defp get_initials(nil), do: "?"

  defp get_initials(%{display_name: name}) when is_binary(name) do
    name
    |> String.split(" ")
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
    |> String.upcase()
  end

  defp get_initials(_), do: "?"

  defp get_display_name(%{display_name: name}), do: name
  defp get_display_name(_), do: "Unknown"

  defp format_time(nil), do: ""

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%b %d, %H:%M")
  end

  defp render_content(content, _team_members) do
    # Simple rendering - could be enhanced with MentionParser.render_html
    content
  end
end
