defmodule Mcp.Underwriting.ExecutiveAssistant do
  @moduledoc """
  AI Assistant for Tenant Executives and Portfolio Managers.
  Provides insights on merchant performance, risk clusters, and operational efficiency.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    extensions: [AshAi]

  import AshAi.Actions

  code_interface do
    define :ask, args: [:query, :context]
  end

  alias LangChain.ChatModels.ChatOpenAI

  actions do
    action :ask, :string do
      description "Answers executive queries about their portfolio and account."

      argument :query, :string do
        allow_nil? false
      end

      argument :context, :string do
        description "Condensed portfolio and account statistics/metrics."
        default ""
      end

      run prompt(
            fn _input, _context ->
              config = Application.get_env(:mcp, :llm)
              api_key = config[:openrouter_api_key]
              base_url = config[:openrouter_base_url]
              model = config[:analytics_model] || "google/gemini-2.0-flash-exp:free"

              ChatOpenAI.new!(%{
                model: model,
                api_key: api_key,
                endpoint: "#{base_url}/chat/completions",
                receive_timeout: 120_000
              })
            end,
            prompt: """
            You are Atlas, the MCP Executive Assistant and professional financial analyst for payment acquirers.
            Your role is to help the user understand their portfolio performance, merchant risk, and operational health.

            ## Current Portfolio Context
            <%= @input.arguments.context %>

            ## User Query
            <%= @input.arguments.query %>

            ## Instructions
            - Provide concise, data-driven answers.
            - Use a professional, executive tone.
            - If asked about statistics, refer to the context provided.
            - If the context doesn't have the answer, state that you'll need more data.
            - Suggest one actionable takeaway if relevant.

            Return ONLY the response message.
            """,
            adapter: AshAi.Actions.Prompt.Adapter.RequestJson
          )
    end
  end
end
