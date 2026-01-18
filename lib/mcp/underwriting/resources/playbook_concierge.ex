defmodule Mcp.Underwriting.PlaybookConcierge do
  @moduledoc """
  AI Assistant for designing and refining Underwriting Playbooks.
  Provides specialized prompts for risk architecture and industry intelligence.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    extensions: [AshAi]

  alias LangChain.ChatModels.ChatOpenAI

  import AshAi.Actions

  code_interface do
    define :suggest_rules, args: [:industry]
    define :analyze_policy, args: [:rules_markdown]
  end

  actions do
    action :suggest_rules, :string do
      description "Generates underwriting rules based on industry and risk appetite."

      argument :industry, :string do
        allow_nil? false
      end

      argument :appetite, :string do
        description "Risk appetite: conservative, moderate, aggressive."
        default "moderate"
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
            You are an expert Underwriting Architect.
            Generate a comprehensive set of underwriting rules in Markdown format for the <%= @input.arguments.industry %> industry.
            The risk appetite for this tenant is <%= @input.arguments.appetite %>.

            Include specific sections for:
            - KYB/KYC Requirements
            - Financial Thresholds (DTI, Revenue, etc.)
            - Industry-specific Red Flags
            - Acceptable Business Models

            Return ONLY the Markdown content.
            """,
            adapter: AshAi.Actions.Prompt.Adapter.RequestJson
          )
    end

    action :analyze_policy, :map do
      description "Analyzes a playbook's markdown rules for gaps or inconsistencies."

      argument :rules_markdown, :string do
        allow_nil? false
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
            Analyze the following underwriting rules for gaps, logic errors, or missing edge cases:

            <%= @input.arguments.rules_markdown %>

            Return a JSON map with "gaps", "strengths", and "recommendations".
            """,
            adapter: AshAi.Actions.Prompt.Adapter.RequestJson
          )
    end
  end
end
