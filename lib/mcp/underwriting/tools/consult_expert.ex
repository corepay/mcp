defmodule Mcp.Underwriting.Tools.ConsultExpert do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: :embedded

  code_interface do
    define :consult, args: [:query, :context]
  end

  actions do
    read :consult do
      description "Consults an Expert AI (Frontier Model) for complex reasoning or financial analysis."
      argument :query, :string, allow_nil?: false, description: "The specific question or analysis request."
      argument :context, :string, allow_nil?: true, description: "Additional context, such as the markdown content of a document."

      manual fn query, _data_layer_query, _context ->
        user_query = query.arguments.query
        context = query.arguments.context || ""

        messages = [
          %{role: "system", content: "You are an Expert Financial Analyst. Your goal is to analyze financial data and provide accurate, insightful answers. You are being consulted by a junior agent."},
          %{role: "user", content: "Context:\n#{context}\n\nQuestion: #{user_query}"}
        ]

        # Use a high-quality model for expert analysis
        case Mcp.Ai.OpenRouter.chat_completion(messages, "anthropic/claude-3.5-sonnet") do
          {:ok, response} ->
            {:ok, [struct(Mcp.Underwriting.Tools.ConsultExpert, result: response)]}
          
          {:error, reason} ->
            {:error, "Failed to consult expert: #{inspect(reason)}"}
        end
      end
    end
  end

  attributes do
    attribute :result, :string do
      public? true
    end
  end
end
