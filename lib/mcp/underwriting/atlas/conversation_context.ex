defmodule Mcp.Underwriting.Atlas.ConversationContext do
  @moduledoc """
  Builds rich context about the current application state for Atlas AI.
  This context enables Atlas to provide relevant, proactive guidance.
  """

  defstruct [
    :current_step,
    :completed_fields,
    :missing_required,
    :form_data,
    :user_state,
    :validation_errors
  ]

  @type t :: %__MODULE__{
          current_step: atom(),
          completed_fields: [String.t()],
          missing_required: [String.t()],
          form_data: map(),
          user_state: map(),
          validation_errors: [any()]
        }

  @step_required_fields %{
    business_info: ["business_name", "ein", "business_type", "business_address"],
    owners: ["owner_name", "owner_ssn", "ownership_percentage"],
    documents: ["government_id"],
    banking: ["account_number", "routing_number"],
    review: []
  }

  @doc """
  Builds a context struct for the given application step.

  ## Parameters
  - `step` - The current application step (atom)
  - `form_data` - Map of field names to values
  - `session_state` - Map containing:
    - `:idle_seconds` - How long the user has been idle
    - `:field_focus` - The currently focused field
    - `:focus_duration` - How long the field has been focused
    - `:errors` - Any validation errors

  ## Returns
  A `%ConversationContext{}` struct with rich context for AI assistance.
  """
  def build_context(step, form_data, session_state) do
    required = required_fields_for(step)
    completed = get_completed_fields(form_data, required)
    missing = required -- completed

    %__MODULE__{
      current_step: step,
      completed_fields: completed,
      missing_required: missing,
      form_data: sanitize_form_data(form_data),
      user_state: build_user_state(session_state),
      validation_errors: Map.get(session_state, :errors, [])
    }
  end

  @doc """
  Returns the list of required fields for a given step.

  ## Parameters
  - `step` - The application step (atom)

  ## Returns
  A list of required field names (strings).
  """
  def required_fields_for(step) do
    Map.get(@step_required_fields, step, [])
  end

  defp get_completed_fields(form_data, required_fields) do
    Enum.filter(required_fields, fn field ->
      value = Map.get(form_data, field, "")
      is_binary(value) && String.trim(value) != ""
    end)
  end

  defp build_user_state(session_state) do
    idle_seconds = Map.get(session_state, :idle_seconds, 0)

    %{
      idle_seconds: idle_seconds,
      appears_stuck?: idle_seconds > 30,
      current_field: Map.get(session_state, :field_focus),
      field_focus_duration: Map.get(session_state, :focus_duration, 0)
    }
  end

  # Remove sensitive data like SSN, EIN from context sent to AI
  defp sanitize_form_data(form_data) do
    sensitive_fields = ["ssn", "owner_ssn", "ein", "account_number", "routing_number"]

    Enum.reduce(sensitive_fields, form_data, fn field, acc ->
      if Map.has_key?(acc, field) do
        Map.put(acc, field, "[REDACTED]")
      else
        acc
      end
    end)
  end
end
