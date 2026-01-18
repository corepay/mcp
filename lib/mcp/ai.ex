defmodule Mcp.Ai do
  @moduledoc """
  AI Domain definition.
  """
  use Ash.Domain,
    otp_app: :mcp,
    extensions: [AshAi]

  tools do
    tool :search_documents, Mcp.Ai.Document, :search do
      description "Search for relevant documents in the knowledge base using semantic search."
    end

    tool :graph_traversal, Mcp.Graph.Intelligence, :graph_traversal do
      description "Traverse the relationship graph starting from a specific node ID."
    end

    tool :find_connected_risks, Mcp.Graph.Intelligence, :find_connected_risks do
      description "Find other merchants connected via shared resellers or owners that have high risk levels."
    end
  end

  resources do
    resource Mcp.Ai.Chat
    resource Mcp.Ai.Document
    resource Mcp.Ai.LlmUsage
    resource Mcp.Ai.KnowledgeBase
    resource Mcp.Graph.Intelligence
  end
end
