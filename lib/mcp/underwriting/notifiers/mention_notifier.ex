defmodule Mcp.Underwriting.Notifiers.MentionNotifier do
  @moduledoc """
  Sends notifications when users are @mentioned in notes.
  Supports in-app PubSub notifications and email.
  """

  @type notification :: %{
          type: :mention,
          user_id: String.t(),
          note_id: String.t(),
          application_id: String.t(),
          message: String.t(),
          created_at: DateTime.t()
        }

  @doc """
  Builds a notification struct for a mentioned user.
  """
  @spec build_notification(map(), map()) :: notification()
  def build_notification(note, user) do
    %{
      type: :mention,
      user_id: user.id,
      note_id: note.id,
      application_id: note.application_id,
      message: "You were mentioned in a note",
      created_at: DateTime.utc_now()
    }
  end

  @doc """
  Broadcasts a mention notification via PubSub.
  """
  @spec broadcast_mention(map(), String.t()) :: :ok
  def broadcast_mention(note, user_id) do
    Phoenix.PubSub.broadcast(
      Mcp.PubSub,
      "user:#{user_id}:notifications",
      {:mention_notification, note}
    )
  end

  @doc """
  Formats the email body for a mention notification.
  """
  @spec format_email_body(map(), map()) :: String.t()
  def format_email_body(note, author) do
    """
    <html>
      <body>
        <h2>You were mentioned in a note</h2>
        <p><strong>#{author.display_name}</strong> mentioned you in an application note:</p>
        <blockquote style="border-left: 3px solid #ccc; padding-left: 10px; margin: 10px 0;">
          #{note.content}
        </blockquote>
        <p><a href="/applications/#{note.application_id}">View Application</a></p>
      </body>
    </html>
    """
  end

  @doc """
  Notifies multiple users about being mentioned.
  """
  @spec notify_all(map(), list(String.t()), map()) :: :ok
  def notify_all(note, user_ids, _author) do
    Enum.each(user_ids, fn user_id ->
      broadcast_mention(note, user_id)
    end)

    :ok
  end
end
