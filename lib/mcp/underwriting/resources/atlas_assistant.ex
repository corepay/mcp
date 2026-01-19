defmodule Mcp.Underwriting.AtlasAssistant do
  @moduledoc """
  Atlas Assistant for Tenant Executives and Portfolio Managers.
  Provides insights on merchant performance, risk clusters, and operational efficiency.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    extensions: [AshAi]

  code_interface do
    define :ask, args: [:query, :context]
  end

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

      run fn input, _context ->
        system_prompt = """
        You are Atlas, the MCP Executive Assistant and professional financial analyst for payment acquirers.
        Your role is to help the user understand their portfolio performance, merchant risk, and operational health.

        ## Instructions
        - Provide concise, data-driven answers.
        - Use a professional, executive tone.
        - If asked about statistics, refer to the context provided.
        - If the context doesn't have the answer, state that you'll need more data.
        - Suggest one actionable takeaway if relevant.

        Return ONLY the response message.
        """

        user_message = """
        ## Current Portfolio Context
        #{input.arguments.context}

        ## User Query
        #{input.arguments.query}
        """

        case Mcp.Ai.Orchestrator.ask(system_prompt, user_message) do
          {:ok, response} -> {:ok, response}
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end
end
