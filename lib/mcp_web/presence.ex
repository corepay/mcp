defmodule McpWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.
  """

  use Phoenix.Presence,
    otp_app: :mcp,
    pubsub_server: Mcp.PubSub
end
