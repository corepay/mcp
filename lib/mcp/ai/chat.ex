defmodule Mcp.Ai.Chat do
  @moduledoc """
  Chat domain for AI interactions.
  """
  use Ash.Resource,
    domain: Mcp.Ai,
    extensions: [AshAi]

  alias LangChain.ChatModels.ChatOllamaAI

  actions do
    action :chat, :string do
      description "Chat with the AI."

      argument :message, :string do
        allow_nil? false
      end

      run {AshAi.Actions.Prompt,
           prompt: "You are a helpful assistant. User says: <%= message %>",
           model:
             ChatOllamaAI.new!(%{
               model: "llama3",
               base_url: Application.compile_env(:mcp, :ollama)[:base_url]
             })}
    end
  end
end
