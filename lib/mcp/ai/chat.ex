defmodule Mcp.Ai.Chat do
  @moduledoc """
  Chat domain for AI interactions.
  """
  use Ash.Resource,
    domain: Mcp.Ai,
    extensions: [AshAi]

  alias Mcp.Ai.Orchestrator

  actions do
    action :chat, :string do
      description "Chat with the AI."

      argument :message, :string do
        allow_nil? false
      end

      run fn input, _context ->
        Orchestrator.ask("You are a helpful assistant.", input.arguments.message)
      end
    end
  end
end
