defmodule Mcp.Underwriting.Atlas.ConversationContextTest do
  use ExUnit.Case, async: true

  alias Mcp.Underwriting.Atlas.ConversationContext

  describe "build_context/3" do
    test "includes current step information" do
      form_data = %{"business_name" => "Acme Corp"}
      context = ConversationContext.build_context(:business_info, form_data, %{})

      assert context.current_step == :business_info
      assert context.completed_fields == ["business_name"]
    end

    test "identifies missing required fields" do
      form_data = %{"business_name" => ""}
      context = ConversationContext.build_context(:business_info, form_data, %{})

      assert "business_name" in context.missing_required
    end

    test "includes idle duration" do
      context = ConversationContext.build_context(:owners, %{}, %{idle_seconds: 45})

      assert context.user_state.idle_seconds == 45
      assert context.user_state.appears_stuck? == true
    end

    test "tracks field focus history" do
      context =
        ConversationContext.build_context(:banking, %{}, %{
          field_focus: "routing_number",
          focus_duration: 30
        })

      assert context.user_state.current_field == "routing_number"
      assert context.user_state.field_focus_duration == 30
    end
  end

  describe "required_fields_for/1" do
    test "returns required fields for business_info step" do
      fields = ConversationContext.required_fields_for(:business_info)

      assert "business_name" in fields
      assert "ein" in fields
      assert "business_type" in fields
    end
  end
end
