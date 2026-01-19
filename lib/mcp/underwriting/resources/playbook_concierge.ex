defmodule Mcp.Underwriting.PlaybookConcierge do
  @moduledoc """
  AI Assistant for designing and refining Underwriting Playbooks.
  Provides specialized prompts for risk architecture and industry intelligence.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    extensions: [AshAi]

  alias Mcp.Ai.Orchestrator

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

      run fn input, _context ->
        system_prompt = "You are an expert Underwriting Architect."

        user_message = """
        Generate a comprehensive set of underwriting rules in Markdown format for the #{input.arguments.industry} industry.
        The risk appetite for this tenant is #{input.arguments.appetite}.

        Include specific sections for:
        - KYB/KYC Requirements
        - Financial Thresholds (DTI, Revenue, etc.)
        - Industry-specific Red Flags
        - Acceptable Business Models

        Return ONLY the Markdown content.
        """

        Orchestrator.ask(system_prompt, user_message)
      end
    end

    action :analyze_policy, :map do
      description "Analyzes a playbook's markdown rules for gaps or inconsistencies."

      argument :rules_markdown, :string do
        allow_nil? false
      end

      run fn input, _context ->
        system_prompt = "You are an expert Underwriting Architect."

        user_message = """
        Analyze the following underwriting rules for gaps, logic errors, or missing edge cases:

        #{input.arguments.rules_markdown}

        Return a JSON map with "gaps", "strengths", and "recommendations".
        """

        case Orchestrator.ask(system_prompt, user_message) do
          {:ok, content} ->
            # Since this expects a :map, we need to parse it
            case Jason.decode(content) do
              {:ok, map} ->
                {:ok, map}

              {:error, _} ->
                # Fallback: if not valid JSON, return as a map with error
                {:ok, %{"error" => "Failed to parse analysis", "raw" => content}}
            end

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end
end
