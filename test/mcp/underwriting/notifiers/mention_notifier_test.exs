defmodule Mcp.Underwriting.Notifiers.MentionNotifierTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Notifiers.MentionNotifier

  describe "build_notification/2" do
    test "creates notification struct for mentioned user" do
      note = %{
        id: "note-123",
        content: "Hey @john check this out",
        author_id: "author-456",
        application_id: "app-789"
      }

      user = %{
        id: "user-001",
        email: "john@example.com",
        display_name: "John Doe"
      }

      notification = MentionNotifier.build_notification(note, user)

      assert notification.type == :mention
      assert notification.user_id == "user-001"
      assert notification.note_id == "note-123"
      assert notification.application_id == "app-789"
      assert is_binary(notification.message)
    end
  end

  describe "broadcast_mention/2" do
    test "broadcasts to user's notification channel" do
      # Subscribe to the channel
      Phoenix.PubSub.subscribe(Mcp.PubSub, "user:user-123:notifications")

      note = %{
        id: "note-456",
        content: "Check this @someone",
        author_id: "author-789",
        application_id: "app-001"
      }

      MentionNotifier.broadcast_mention(note, "user-123")

      assert_receive {:mention_notification, received_note}
      assert received_note.id == "note-456"
    end
  end

  describe "format_email_body/2" do
    test "generates HTML email with note content" do
      note = %{
        content: "Please review @john this document",
        application_id: "app-123"
      }

      author = %{display_name: "Alice Smith"}

      body = MentionNotifier.format_email_body(note, author)

      assert body =~ "mentioned you"
      assert body =~ "Alice Smith"
      assert body =~ "Please review"
    end
  end
end
