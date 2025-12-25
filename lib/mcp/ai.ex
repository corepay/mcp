defmodule Mcp.Ai do
  @moduledoc """
  AI Domain definition.
  """
  use Ash.Domain,
    otp_app: :mcp

  resources do
    resource Mcp.Ai.Chat
    resource Mcp.Ai.Document
    resource Mcp.Ai.LlmUsage
    resource Mcp.Ai.KnowledgeBase
  end
end
