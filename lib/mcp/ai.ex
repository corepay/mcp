defmodule Mcp.Ai do
  use Ash.Domain,
    otp_app: :mcp

  resources do
    resource Mcp.Ai.Chat
    resource Mcp.Ai.Document
  end
end
