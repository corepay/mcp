defmodule Mcp.Underwriting.Atlas.AgentTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Atlas.Agent
  alias Mcp.Underwriting.Atlas.ConversationContext

  describe "generate_response/2" do
    test "returns proactive help when user appears stuck" do
      context = %ConversationContext{
        current_step: :business_info,
        completed_fields: ["business_name"],
        missing_required: ["ein", "business_type"],
        user_state: %{appears_stuck?: true, current_field: "ein", idle_seconds: 45}
      }

      {:ok, response} = Agent.generate_response("", context)

      assert response.type == :proactive_help
      assert response.message =~ "EIN"
    end

    test "answers user question about current field" do
      context = %ConversationContext{
        current_step: :owners,
        user_state: %{current_field: "owner_ssn"}
      }

      {:ok, response} = Agent.generate_response("Why do you need my SSN?", context)

      assert response.type == :answer
      assert response.message =~ "identity" or response.message =~ "verification"
    end

    test "suggests improvements for vague entries" do
      context = %ConversationContext{
        current_step: :business_info,
        form_data: %{"business_description" => "consulting"},
        user_state: %{appears_stuck?: false}
      }

      {:ok, response} = Agent.generate_response("Is my description okay?", context)

      assert response.type == :suggestion
      assert response.message =~ "specific" or response.message =~ "clearer"
    end

    test "handles general questions about application process" do
      context = %ConversationContext{
        current_step: :business_info,
        user_state: %{appears_stuck?: false}
      }

      {:ok, response} = Agent.generate_response("How long does approval take?", context)

      assert response.type == :answer
      assert is_binary(response.message)
    end

    test "returns encouragement when user is making progress" do
      context = %ConversationContext{
        current_step: :banking,
        completed_fields: ["account_number"],
        missing_required: ["routing_number"],
        user_state: %{appears_stuck?: false, current_field: "routing_number"}
      }

      {:ok, response} = Agent.generate_response("", context)

      assert response.type in [:proactive_help, :encouragement]
    end
  end

  describe "build_prompt/2" do
    test "includes step-specific guidance" do
      context = %ConversationContext{current_step: :documents}
      prompt = Agent.build_prompt("What documents?", context)

      assert prompt =~ "document"
      assert prompt =~ "upload"
    end

    test "includes business_info step guidance" do
      context = %ConversationContext{current_step: :business_info}
      prompt = Agent.build_prompt("What is an EIN?", context)

      assert prompt =~ "business"
    end

    test "includes banking step guidance" do
      context = %ConversationContext{current_step: :banking}
      prompt = Agent.build_prompt("Where do I find my routing number?", context)

      assert prompt =~ "bank"
    end

    test "includes owners step guidance" do
      context = %ConversationContext{current_step: :owners}
      prompt = Agent.build_prompt("Why do you need owner information?", context)

      assert prompt =~ "owner"
    end
  end

  describe "field_help/1" do
    test "returns help for EIN field" do
      help = Agent.field_help("ein")
      assert help =~ "Employer Identification Number"
    end

    test "returns help for SSN field" do
      help = Agent.field_help("owner_ssn")
      assert help =~ "Social Security Number"
    end

    test "returns help for routing number field" do
      help = Agent.field_help("routing_number")
      assert help =~ "9-digit"
    end

    test "returns generic help for unknown fields" do
      help = Agent.field_help("unknown_field")
      assert is_binary(help)
    end
  end

  describe "atlas_blueprint/0" do
    test "returns blueprint with required fields" do
      blueprint = Agent.atlas_blueprint()

      assert blueprint.name == "Atlas"
      assert is_binary(blueprint.base_prompt)
      assert blueprint.base_prompt =~ "helpful"
    end
  end
end
