defmodule McpWeb.Ola.Components.AtlasChatTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  # Module not yet implemented
  @moduletag :pending_atlas_chat

  alias McpWeb.Ola.Components.AtlasChat

  describe "mount/1" do
    test "initializes with empty messages" do
      {:ok, socket} = AtlasChat.mount(%Phoenix.LiveView.Socket{})

      assert socket.assigns.messages == []
      assert socket.assigns.input_value == ""
    end
  end

  describe "handle_event send_message" do
    test "adds user message and generates response" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          messages: [],
          input_value: "",
          current_step: :business_info,
          form_data: %{},
          session_state: %{},
          last_activity: System.monotonic_time(:second),
          proactive_shown: false,
          __changed__: %{}
        }
      }

      {:noreply, updated} =
        AtlasChat.handle_event(
          "send_message",
          %{"message" => "Where do I find my EIN?"},
          socket
        )

      assert length(updated.assigns.messages) >= 1
      user_msg = List.first(updated.assigns.messages)
      assert user_msg.role == :user
      assert user_msg.content == "Where do I find my EIN?"
    end
  end

  describe "handle_info :check_idle" do
    test "triggers proactive help after 30 seconds idle" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          messages: [],
          input_value: "",
          current_step: :owners,
          form_data: %{},
          session_state: %{idle_seconds: 35, field_focus: "owner_ssn"},
          last_activity: System.monotonic_time(:second) - 35,
          proactive_shown: false,
          __changed__: %{}
        }
      }

      {:noreply, updated} = AtlasChat.handle_info(:check_idle, socket)

      # Should have added a proactive message
      assert length(updated.assigns.messages) == 1
      msg = List.first(updated.assigns.messages)
      assert msg.role == :assistant
    end
  end
end
