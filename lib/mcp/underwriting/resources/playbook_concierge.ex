defmodule Mcp.Underwriting.PlaybookConcierge do
  @moduledoc """
  AI Assistant for designing and refining Underwriting Playbooks.
  Provides specialized prompts for risk architecture and industry intelligence.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    extensions: [AshAi]

  alias LangChain.ChatModels.ChatOllamaAI

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

      run {AshAi.Actions.Prompt,
           prompt: """
           You are an expert Underwriting Architect.
           Generate a comprehensive set of underwriting rules in Markdown format for the <%= industry %> industry.
           The risk appetite for this tenant is <%= appetite %>.

           Include specific sections for:
           - KYB/KYC Requirements
           - Financial Thresholds (DTI, Revenue, etc.)
           - Industry-specific Red Flags
           - Acceptable Business Models

           Return ONLY the Markdown content.
           """,
           model:
             ChatOllamaAI.new!(%{
               model: "llama3",
               base_url: Application.compile_env(:mcp, :ollama)[:base_url]
             })}
    end

    action :analyze_policy, :map do
      description "Analyzes a playbook's markdown rules for gaps or inconsistencies."

      argument :rules_markdown, :string do
        allow_nil? false
      end

      run {AshAi.Actions.Prompt,
           prompt: """
           Analyze the following underwriting rules for gaps, logic errors, or missing edge cases:

           <%= rules_markdown %>

           Return a JSON map with "gaps", "strengths", and "recommendations".
           """,
           model:
             ChatOllamaAI.new!(%{
               model: "llama3",
               base_url: Application.compile_env(:mcp, :ollama)[:base_url]
             })}
    end
  end
end
