defmodule Mcp.Ai.Chat do
  use Ash.Resource,
    domain: Mcp.Ai,
    extensions: [AshAi]

  actions do
    action :chat, :string do
      description "Chat with the AI."
      argument :message, :string do
        allow_nil? false
      end

      run {AshAi.Actions.Prompt,
        prompt: "You are a helpful assistant. User says: <%= message %>",
        model: LangChain.ChatModels.ChatOllamaAI.new!(%{
          model: "llama3",
          base_url: Application.get_env(:mcp, :ollama)[:base_url]
        })
      }
    end
  end
end
