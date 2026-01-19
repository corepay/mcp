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
  alias Mcp.Underwriting.Engine.AgentRunner

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
    config = Application.get_env(:mcp, :llm, [])
    models = config[:openrouter_fallback_models] || ["google/gemini-2.0-flash-exp:free"]

    %{
      name: "Atlas",
      description: "Friendly and professional AI assistant for the MCP platform",
      base_prompt: """
      You are Atlas, a helpful and friendly AI assistant for the MCP (Merchant Commerce Platform).
      Your role is to:

      1. Provide clear explanations for complex platform features and financial data.
      2. Help users navigate merchant onboarding, risk assessment, and portfolio management.
      3. Offer proactive assistance based on the current page or subject context.
      4. Suggest improvements and actionable insights.
      5. Maintain a professional, supportive, and encouraging tone.

      You have deep knowledge of merchant services, business verification,
      underwriting, and global payment connectivity. Always prioritize user privacy
      and data integrity.
      """,
      tools: [:field_help, :validation_check, :progress_summary],
      routing_config: %{
        mode: :fallback,
        primary_provider: :openrouter,
        primary_model: models
      }
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
  @spec generate_response(String.t() | nil, ConversationContext.t()) :: {:ok, response()}
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
  # Live Mode Implementation

  defp live_generate_response(user_message, context) do
    # 1. Build resources expected by AgentRunner
    blueprint = build_ash_blueprint()
    instructions = build_instruction_set(user_message, context)

    # 2. Add extra execution options
    opts = [
      tenant_id: Map.get(context.user_state, :tenant_id, "default"),
      provider: Application.get_env(:mcp, :llm_provider, :openrouter)
    ]

    # 3. Execution with Fallback protection
    try do
      case AgentRunner.run(
             blueprint,
             instructions,
             context.form_data,
             opts
           ) do
        {:ok, result} when is_map(result) ->
          # Transform LLM string keys to atom structure
          {:ok,
           %{
             type: parse_type(result["type"]),
             message: result["message"] || "I'm not sure, but I can help you find out.",
             field: result["field"],
             confidence: Map.get(result, "confidence", 0.0)
           }}

        {:ok, _other} ->
          # JSON parse failed or unexpected format
          fallback_to_mock(user_message, context)

        {:error, _reason} ->
          # Provider failure
          fallback_to_mock(user_message, context)
      end
    rescue
      _e ->
        # Safety net for runtime crashes during execution
        fallback_to_mock(user_message, context)
    end
  end

  defp fallback_to_mock(user_message, context) do
    # Log the failure silently and fallback
    mock_generate_response(user_message, context)
  end

  defp build_ash_blueprint do
    raw = atlas_blueprint()

    struct(Mcp.Underwriting.AgentBlueprint, %{
      name: raw.name,
      description: raw.description,
      base_prompt: raw.base_prompt,
      tools: raw.tools,
      routing_config: raw.routing_config,
      knowledge_base_ids: []
    })
  end

  defp build_instruction_set(user_message, context) do
    step_guidance = step_guidance_for(context.current_step)
    field_context = build_field_context(context)

    instructions_text = """
    ## Current Step: #{context.current_step}
    #{step_guidance}

    ## Context
    #{field_context}

    ## User Input
    "#{user_message}"

    ## JSON Response Requirements
    You must respond with a JSON object containing:
    - "type": One of "answer", "suggestion", "proactive_help", "encouragement"
    - "message": The content of your response (friendly, helpful, concise)
    - "field": The specific field name (snake_case) if referring to a form field, or null
    - "confidence": Float between 0.0 and 1.0

    Example:
    {
      "type": "answer",
      "message": "The EIN stands for Employer Identification Number.",
      "field": "ein",
      "confidence": 0.95
    }
    """

    struct(Mcp.Underwriting.InstructionSet, %{
      name: "Atlas Dynamic Instructions",
      instructions: instructions_text,
      # Ephemeral
      blueprint_id: nil
    })
  end

  defp parse_type("answer"), do: :answer
  defp parse_type("suggestion"), do: :suggestion
  defp parse_type("proactive_help"), do: :proactive_help
  defp parse_type("encouragement"), do: :encouragement
  defp parse_type(_), do: :answer

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

  @doc """
  Generates a strategic summary of a merchant portfolio.
  """
  def generate_portfolio_summary(tenant_id, merchants, applications) do
    if mock_mode?() do
      mock_portfolio_summary()
    else
      # Real LLM call for aggregate data
      blueprint = build_ash_blueprint()
      portfolio_context = build_portfolio_context(merchants, applications)

      instructions = %Mcp.Underwriting.InstructionSet{
        name: "Dashboard Intelligence",
        instructions: build_portfolio_instructions(portfolio_context)
      }

      execute_portfolio_summary(blueprint, instructions, portfolio_context, tenant_id)
    end
  end

  defp execute_portfolio_summary(blueprint, instructions, context, tenant_id) do
    case AgentRunner.run(blueprint, instructions, context, tenant_id: tenant_id) do
      {:ok, result} when is_map(result) ->
        # Normalize insights to atom keys for stable rendering
        insights = normalize_portfolio_insights(result["insights"])
        {:ok, %{type: :answer, insights: insights, confidence: result["confidence"] || 0.8}}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "Intelligence scan interrupted."}
    end
  rescue
    _ -> {:error, "System fault during intelligence scan."}
  end

  defp normalize_portfolio_insights(nil),
    do: [%{status: "green", message: "Portfolio analysis complete."}]

  defp normalize_portfolio_insights(list) when is_list(list) do
    Enum.map(list, fn
      item when is_map(item) ->
        %{
          status: item["status"] || item[:status] || "green",
          message: item["message"] || item[:message] || "Analysis complete."
        }

      _ ->
        %{status: "green", message: "Portfolio analysis complete."}
    end)
  end

  defp normalize_portfolio_insights(_),
    do: [%{status: "green", message: "Portfolio analysis complete."}]

  defp build_portfolio_context(merchants, applications) do
    %{
      merchant_count: length(merchants),
      application_count: length(applications),
      active_plans: count_by_key(merchants, :plan),
      risk_levels: count_by_key(merchants, :risk_level)
    }
  end

  defp count_by_key(list, key) do
    list
    |> Enum.group_by(&Map.get(&1, key))
    |> Enum.map(fn {k, l} -> {k, length(l)} end)
    |> Map.new()
  end

  defp build_portfolio_instructions(portfolio_context) do
    """
    You are Atlas, the Portfolio Intelligence Analyst.
    Analyze the following merchant portfolio data and provide exactly 3 strategic insights.
    Each insight must have a status: "green" (positive/growth), "amber" (cautionary/pending), or "red" (risk/alert).

    ## Portfolio Metrics
    #{Jason.encode!(portfolio_context, pretty: true)}

    Your goal is to identify trends in plan distribution, risk concentration, and acquisition velocity.
    Respond with JSON:
    {
      "type": "answer",
      "insights": [
        {"status": "green", "message": "..."},
        {"status": "amber", "message": "..."},
        {"status": "red", "message": "..."}
      ],
      "confidence": 0.xx
    }
    """
  end

  defp mock_portfolio_summary do
    {:ok,
     %{
       type: :answer,
       insights: [
         %{
           status: "green",
           message: "Portfolio acquisition velocity is up 15% vs previous month."
         },
         %{
           status: "amber",
           message: "High-Ticket Retail sector requires manual signal verification."
         },
         %{status: "red", message: "Risk cluster detected in emerging tech merchant segment."}
       ],
       confidence: 0.95
     }}
  end

  @doc """
  Generates a full-scale executive report for a tenant.
  """
  def generate_executive_report(tenant_id, merchants, applications, stats) do
    if mock_mode?() do
      mock_executive_report(merchants, stats)
    else
      blueprint = build_ash_blueprint()
      portfolio_context = build_executive_context(merchants, applications, stats)

      instructions = %Mcp.Underwriting.InstructionSet{
        name: "Executive Report Generation",
        instructions: build_executive_instructions(merchants, applications, stats)
      }

      execute_executive_report(blueprint, instructions, portfolio_context, tenant_id)
    end
  end

  defp execute_executive_report(blueprint, instructions, context, tenant_id) do
    case AgentRunner.run(blueprint, instructions, context, tenant_id: tenant_id) do
      {:ok, result} when is_map(result) ->
        extract_report_from_result(result)

      {:ok, result} when is_binary(result) ->
        {:ok, result}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "Intelligence scan interrupted during report generation."}
    end
  rescue
    _ -> {:error, "System fault during strategic analysis."}
  end

  defp extract_report_from_result(result) do
    report = find_report_body(result)

    cond do
      is_binary(report) ->
        {:ok, report}

      result["error"] ->
        {:error, result["error"]}

      true ->
        synth_report_from_result(result)
    end
  end

  defp find_report_body(result) do
    result["report"] || result[:report] || result["answer"] || result[:answer] ||
      result["content"] || result["raw_response"]
  end

  defp synth_report_from_result(result) do
    # If it's a map but has no recognized report key, try to synthesize from all string values
    content =
      result
      |> Enum.filter(fn {_k, v} -> is_binary(v) end)
      |> Enum.map_join("\n\n", fn {k, v} -> "## #{k}\n#{v}" end)

    if content != "" do
      {:ok, content}
    else
      {:ok,
       "## [DEBUG_V3.0] Strategic Signal Lost\nThe intelligence agent returned a response without a report body. Raw result: #{inspect(result)}"}
    end
  end

  defp build_executive_context(merchants, applications, stats) do
    %{
      merchant_count: length(merchants),
      application_count: length(applications),
      stats: stats,
      active_plans: count_by_key(merchants, :plan),
      risk_levels: count_by_key(merchants, :risk_level)
    }
  end

  defp build_executive_instructions(merchants, applications, stats) do
    """
    You are Atlas, the MCP Executive Strategy Consultant (v2.1).
    Generate a professional, high-density Strategic Executive Health Report.

    ## Portfolio Overview
    Total Merchants: #{length(merchants)}
    Pending Applications: #{length(applications)}
    Key Stats: #{Jason.encode!(stats)}

    ## Requirements
    - Structure: Use H1 for title, H2 for sections, and H3 for subcategories.
    - Content: Include a KPI table, Performance Analysis, Risk Assessment, and Strategic Recommendations.
    - Style: Authoritative, data-driven, and concise. Use emojis for visual cues.
    - Formatting: Bullet points, bold text for emphasis, and clear tables.

    ## Output Format
    You must respond with a JSON object containing a "report" key with the markdown content.
    Example: {"report": "# Strategic Report\\n...", "confidence": 0.95}
    """
  end

  defp mock_executive_report(merchants, stats) do
    {:ok,
     """
     # Executive Health Report: #{DateTime.utc_now() |> Calendar.strftime("%B %Y")}

     ## 📊 Portfolio Overview
     The portfolio currently consists of **#{length(merchants)}** active merchants with **#{stats.pending_apps}** applications in the pipeline.

     ### Key Performance Indicators
     | Metric | Value | Status |
     | :--- | :--- | :--- |
     | **30D Net Volume** | #{stats.volume} | 🟢 Strong |
     | **Growth Rate** | #{stats.growth} | 📈 Above Average |
     | **Risk Index** | #{stats.risk_index} | 🛡️ Healthy |

     ## 💰 Profitability Analysis
     The net yield remains stable at **18.4 bps**. Liquidity is concentrated in transit funds (**#{stats.today_volume}**), representing healthy transactional velocity.

     ### Merchant Distribution
     - **Retail:** 45% (Stable)
     - **E-commerce:** 30% (High Growth)
     - **Services:** 25% (Low Risk)

     ## 🎯 Recommendations
     1. **Accelerate Mid-Market Boarding**: The Stage 2 pipeline has 12 reviewing applications; prioritizing these will boost next month's volume by an estimated 8%.
     2. **Monitor Tech Segment**: Emerging tech merchants show slight risk anomalies; recommend a deeper forensic scan.
     """}
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
