defmodule Mcp.Ai.Chat do
  @moduledoc """
  Chat domain for AI interactions.
  """
  use Ash.Resource,
    domain: Mcp.Ai,
    extensions: [AshAi]

  import AshAi.Actions

  actions do
    action :chat, :string do
      description "Chat with the AI."

      argument :message, :string do
        allow_nil? false
      end

      run prompt(
            fn _input, _context ->
              config = Application.get_env(:mcp, :llm)
              base_url = config[:openrouter_base_url]
              api_key = config[:openrouter_api_key]

              LangChain.ChatModels.ChatOpenAI.new!(%{
                # Using most recent pro exp as placeholder for "2.5 pro"
                model: "google/gemini-2.0-pro-exp-02-05:free",
                api_key: api_key,
                endpoint: "#{base_url}/chat/completions",
                receive_timeout: 120_000
              })
            end,
            prompt: "You are a helpful assistant. User says: <%= @input.arguments.message %>",
            adapter: AshAi.Actions.Prompt.Adapter.StructuredOutput
          )
    end
  end
end
