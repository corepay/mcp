defmodule Mcp.Underwriting.Atlas.Agent do
  @moduledoc """
  Atlas AI Agent for providing proactive guidance during merchant onboarding.

  Atlas uses the ConversationContext to understand where users are in the
  application process and provides contextual help, answers questions,
  and suggests improvements.

  ## Modes

  The agent can run in two modes:
  - **Mock mode**: Uses pattern matching for tests (when `:agent_runner_adapter` is `:mock`)
  - **Live mode**: Integrates with LLM via AgentRunner for actual AI responses

  ## Response Types

  - `:proactive_help` - Unsolicited assistance when user appears stuck
  - `:answer` - Direct response to user questions
  - `:suggestion` - Recommendations for improving form entries
  - `:encouragement` - Positive reinforcement for progress
  """

  alias Mcp.Underwriting.Atlas.ConversationContext

  @type response :: %{
          type: :proactive_help | :answer | :suggestion | :encouragement,
          message: String.t(),
          field: String.t() | nil,
          confidence: float()
        }

  @doc """
  Returns the Atlas agent blueprint definition.

  This blueprint defines the agent's personality, capabilities, and behavior
  for helping users through the merchant onboarding process.
  """
  def atlas_blueprint do
    %{
      name: "Atlas",
      description: "Friendly onboarding assistant for merchant applications",
      base_prompt: """
      You are Atlas, a helpful and friendly assistant guiding merchants through
      the application process. Your role is to:

      1. Provide clear explanations for required information
      2. Help users understand why certain data is needed
      3. Offer proactive assistance when users seem stuck
      4. Suggest improvements to vague or incomplete entries
      5. Maintain a supportive and encouraging tone

      You have deep knowledge of merchant services, business verification,
      and the underwriting process. Always prioritize user privacy and
      never ask for more information than necessary.
      """,
      tools: [:field_help, :validation_check, :progress_summary],
      routing_config: %{mode: :single, primary_provider: :ollama}
    }
  end

  @doc """
  Generates a response based on user input and conversation context.

  ## Parameters

  - `user_message` - The user's message (can be empty for proactive help)
  - `context` - A ConversationContext struct with current application state

  ## Returns

  `{:ok, response}` where response contains:
  - `:type` - The response type (:proactive_help, :answer, :suggestion, :encouragement)
  - `:message` - The response text
  - `:field` - The relevant field (if applicable)
  - `:confidence` - Confidence score (0.0 to 1.0)
  """
  @spec generate_response(String.t(), ConversationContext.t()) :: {:ok, response()}
  def generate_response(user_message, context) do
    if mock_mode?() do
      mock_generate_response(user_message, context)
    else
      live_generate_response(user_message, context)
    end
  end

  @doc """
  Builds the prompt for the LLM based on user message and context.

  The prompt includes:
  - Atlas personality and capabilities
  - Step-specific guidance
  - Current field context
  - Form completion status
  """
  @spec build_prompt(String.t(), ConversationContext.t()) :: String.t()
  def build_prompt(user_message, context) do
    step_guidance = step_guidance_for(context.current_step)
    field_context = build_field_context(context)

    """
    #{atlas_blueprint().base_prompt}

    ## Current Step Context
    #{step_guidance}

    #{field_context}

    ## User Message
    #{user_message}

    Provide a helpful, concise response appropriate to the user's needs.
    """
  end

  @doc """
  Returns help text for a specific field.

  Common fields include:
  - `ein` - Employer Identification Number
  - `owner_ssn` - Owner's Social Security Number
  - `routing_number` - Bank routing number
  - `account_number` - Bank account number
  """
  @spec field_help(String.t()) :: String.t()
  def field_help(field) do
    field_help_text()[field] || generic_field_help(field)
  end

  # Private Functions

  defp mock_mode? do
    Application.get_env(:mcp, :agent_runner_adapter) == :mock
  end

  defp mock_generate_response(user_message, context) do
    response =
      cond do
        # Proactive help when user appears stuck with empty message
        empty_message?(user_message) && stuck?(context) ->
          generate_proactive_help(context)

        # Encouragement for users making progress (empty message, not stuck)
        empty_message?(user_message) ->
          generate_encouragement(context)

        # Handle user questions based on pattern matching
        true ->
          match_user_question(user_message, context)
      end

    {:ok, response}
  end

  defp match_user_question(user_message, context) do
    cond do
      user_message =~ ~r/ssn|social security/i ->
        build_ssn_response()

      user_message =~ ~r/description.*okay|is (my|this) description/i ->
        generate_description_suggestion(context)

      user_message =~ ~r/how long|approval.*take|when.*approved/i ->
        build_approval_time_response()

      user_message =~ ~r/document|upload/i ->
        build_documents_response()

      user_message =~ ~r/ein|employer identification/i ->
        build_field_response("ein")

      user_message =~ ~r/routing/i ->
        build_field_response("routing_number")

      true ->
        build_fallback_response()
    end
  end

  defp build_ssn_response do
    %{
      type: :answer,
      message:
        "We need your Social Security Number for identity verification and regulatory compliance. " <>
          "This helps us verify your identity and prevent fraud. Your SSN is encrypted and stored securely.",
      field: "owner_ssn",
      confidence: 0.95
    }
  end

  defp build_approval_time_response do
    %{
      type: :answer,
      message:
        "Most applications are reviewed within 1-2 business days. " <>
          "Complete applications with all required documents tend to be processed faster.",
      field: nil,
      confidence: 0.9
    }
  end

  defp build_documents_response do
    %{
      type: :answer,
      message:
        "We typically require government-issued ID, proof of business ownership, " <>
          "and recent bank statements. You can upload these on the Documents step.",
      field: nil,
      confidence: 0.85
    }
  end

  defp build_field_response(field) do
    %{
      type: :answer,
      message: field_help(field),
      field: field,
      confidence: 0.95
    }
  end

  defp build_fallback_response do
    %{
      type: :answer,
      message: "I'm here to help! Could you tell me more about what you need assistance with?",
      field: nil,
      confidence: 0.7
    }
  end

  # NOTE: Future LLM Integration
  #
  # When ready to integrate with actual LLM:
  #   prompt = build_prompt(user_message, context)
  #   blueprint = build_ash_blueprint()
  #   instructions = build_instruction_set(context)
  #   AgentRunner.run(blueprint, instructions, %{prompt: prompt})
  #
  # For now, uses mock responses for predictable behavior.
  defp live_generate_response(user_message, context) do
    mock_generate_response(user_message, context)
  end

  defp empty_message?(message) do
    is_nil(message) || String.trim(message || "") == ""
  end

  defp stuck?(context) do
    context.user_state[:appears_stuck?] == true
  end

  defp generate_proactive_help(context) do
    current_field = context.user_state[:current_field]
    missing_fields = context.missing_required || []

    field_to_help =
      cond do
        current_field && current_field in missing_fields -> current_field
        length(missing_fields) > 0 -> List.first(missing_fields)
        true -> nil
      end

    message =
      if field_to_help do
        field_name = humanize_field(field_to_help)
        help_text = field_help(field_to_help)

        "I noticed you might need some help with the #{field_name} field. #{help_text}"
      else
        "I'm here if you need any help completing your application. " <>
          "Just ask me anything about the information we're requesting."
      end

    %{
      type: :proactive_help,
      message: message,
      field: field_to_help,
      confidence: 0.85
    }
  end

  defp generate_description_suggestion(context) do
    description = get_in(context.form_data || %{}, ["business_description"]) || ""

    suggestion =
      if String.length(description) < 20 do
        "Your business description could be more specific. " <>
          "Try including what products or services you offer, your target customers, " <>
          "and what makes your business unique. A clearer description helps us " <>
          "better understand your business."
      else
        "Your description is a good start! Consider adding more details about " <>
          "your specific services and target market for a stronger application."
      end

    %{
      type: :suggestion,
      message: suggestion,
      field: "business_description",
      confidence: 0.8
    }
  end

  defp generate_encouragement(context) do
    completed = length(context.completed_fields || [])
    total = completed + length(context.missing_required || [])

    progress_msg =
      cond do
        total == 0 ->
          "Let's get started with your application!"

        completed == total ->
          "Great job! You've completed all the fields in this section."

        completed > total / 2 ->
          "You're making excellent progress! Just a few more fields to go."

        true ->
          "You're on the right track. Keep going!"
      end

    %{
      type: :encouragement,
      message: progress_msg,
      field: nil,
      confidence: 0.9
    }
  end

  defp step_guidance_for(step) do
    case step do
      :business_info ->
        """
        The user is providing business information. Help them with:
        - EIN (Employer Identification Number) - a 9-digit tax ID
        - Business type selection (LLC, Corporation, Sole Proprietor, etc.)
        - Business address and contact information
        - Business description and industry classification
        """

      :owners ->
        """
        The user is providing owner information. Help them with:
        - Owner personal details and ownership percentages
        - SSN requirements for identity verification
        - Understanding why beneficial owner information is required
        - OFAC and regulatory compliance requirements
        """

      :documents ->
        """
        The user is uploading required documents. Help them with:
        - Government-issued ID requirements
        - Acceptable document formats and quality
        - Business documentation (articles of incorporation, licenses)
        - Troubleshooting upload issues
        """

      :banking ->
        """
        The user is providing bank account information. Help them with:
        - Finding routing and account numbers on checks
        - Understanding ACH verification process
        - Bank statement requirements
        - Security of banking information
        """

      :review ->
        """
        The user is reviewing their application. Help them with:
        - Verifying all information is correct
        - Understanding what happens after submission
        - Explaining the review timeline
        - Addressing any remaining concerns
        """

      _ ->
        "Provide general assistance with the merchant application process."
    end
  end

  defp build_field_context(context) do
    parts = []

    parts =
      if context.completed_fields && length(context.completed_fields) > 0 do
        ["Completed fields: #{Enum.join(context.completed_fields, ", ")}" | parts]
      else
        parts
      end

    parts =
      if context.missing_required && length(context.missing_required) > 0 do
        ["Missing required fields: #{Enum.join(context.missing_required, ", ")}" | parts]
      else
        parts
      end

    parts =
      if context.user_state[:current_field] do
        ["Currently focused on: #{context.user_state.current_field}" | parts]
      else
        parts
      end

    parts =
      if context.user_state[:appears_stuck?] do
        [
          "User appears stuck (idle for #{context.user_state[:idle_seconds] || 0} seconds)"
          | parts
        ]
      else
        parts
      end

    Enum.join(Enum.reverse(parts), "\n")
  end

  defp field_help_text do
    %{
      "ein" =>
        "Your Employer Identification Number (EIN) is a 9-digit number assigned by the IRS. " <>
          "It's like a Social Security Number for your business. " <>
          "You can find it on your IRS confirmation letter or request a new one at irs.gov.",
      "owner_ssn" =>
        "We need your Social Security Number for identity verification as required by federal regulations. " <>
          "This information is encrypted and securely stored. We use it to verify your identity " <>
          "and ensure compliance with anti-money laundering requirements.",
      "routing_number" =>
        "Your routing number is a 9-digit code that identifies your bank. " <>
          "You can find it on the bottom left of your checks, or in your online banking portal. " <>
          "It's different from your account number.",
      "account_number" =>
        "Your account number uniquely identifies your bank account. " <>
          "You can find it on your checks (to the right of the routing number) " <>
          "or in your online banking portal.",
      "business_name" =>
        "Enter your business's legal name as registered with your state. " <>
          "This should match your business documents and tax filings.",
      "business_type" =>
        "Select your business structure: Sole Proprietorship, LLC, Corporation, Partnership, etc. " <>
          "This should match how your business is registered with your state.",
      "business_description" =>
        "Describe what your business does, including the products or services you offer. " <>
          "Be specific to help us understand your business model.",
      "government_id" =>
        "Please upload a valid government-issued photo ID such as a driver's license, " <>
          "state ID, or passport. The document should be clearly visible and not expired."
    }
  end

  defp generic_field_help(field) do
    field_name = humanize_field(field)
    "Please provide your #{field_name}. If you need help finding this information, let me know!"
  end

  defp humanize_field(field) when is_binary(field) do
    field
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp humanize_field(field) when is_atom(field) do
    humanize_field(Atom.to_string(field))
  end

  defp humanize_field(_), do: "field"
end
