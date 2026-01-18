defmodule Mcp.Chat.Persona do
  @moduledoc """
  Generates dynamic system prompts for AI chat based on the actor's role.
  """

  alias Mcp.Accounts.User
  # alias Mcp.Platform.{Merchant, Reseller} # If we need to load them

  def system_prompt(actor, context \\ %{})

  def system_prompt(nil, _context) do
    default_prompt()
  end

  def system_prompt(actor, context) do
    base = "You are Atlas, an intelligent assistant for the Mcp platform."

    persona_prompt = persona_for(actor)
    context_prompt = context_for(context)

    """
    #{base}

    #{persona_prompt}

    #{context_prompt}

    Guidelines:
    - Be helpful, professional, and concise.
    - If you use tools, explain what you are doing.
    - Respect multi-tenancy: never suggest you can see data outside the current context.
    - You have access to tools to analyze uploaded documents and query the knowledge graph.
    """
  end

  defp context_for(%{subject: subject, playbook: playbook}) do
    subject_str = describe_subject(subject)

    playbook_str =
      if playbook do
        """
        ACTIVE UNDERWRITING PLAYBOOK:
        Name: #{playbook.name}
        Industry: #{playbook.industry}
        Rules:
        #{playbook.rules_markdown}
        Thresholds: #{inspect(playbook.thresholds)}
        """
      else
        ""
      end

    """
    #{subject_str}
    #{playbook_str}
    """
  end

  defp context_for(_), do: ""

  defp describe_subject(%Mcp.Underwriting.Application{} = app) do
    """
    CURRENT SUBJECT: Underwriting Application
    Status: #{app.status}
    Risk Score: #{app.risk_score}
    Submitted At: #{app.submitted_at}
    SLA Due: #{app.sla_due_at}
    """
  end

  defp describe_subject(%Mcp.Platform.Merchant{} = merchant) do
    """
    CURRENT SUBJECT: Merchant Partner
    Name: #{merchant.business_name}
    Status: #{merchant.status}
    Risk Level: #{merchant.risk_level}
    """
  end

  defp describe_subject(%Mcp.Platform.Reseller{} = reseller) do
    """
    CURRENT SUBJECT: Reseller Portfolio
    Company: #{reseller.company_name}
    Commission Rate: #{reseller.commission_rate}
    Status: #{reseller.status}
    """
  end

  defp describe_subject(%Mcp.Platform.MID{} = mid) do
    """
    CURRENT SUBJECT: Connectivity & MID
    Number: #{mid.mid_number}
    Gateway ID: #{mid.gateway_id}
    Status: #{mid.status}
    Limit: #{mid.monthly_limit}
    """
  end

  defp describe_subject(%Mcp.Platform.ApiKey{} = key) do
    """
    CURRENT SUBJECT: API Configuration
    Prefix: #{key.prefix}
    Type: #{key.type}
    Scopes: #{Enum.join(key.scopes, ", ")}
    Expires: #{key.expires_at}
    """
  end

  defp describe_subject(%Mcp.Finance.Ledger{} = ledger) do
    """
    CURRENT SUBJECT: Forensic Ledger Entry
    Amount: #{ledger.amount} #{ledger.currency}
    Type: #{ledger.type}
    Status: #{ledger.status}
    Description: #{ledger.description}
    """
  end

  defp describe_subject(%Mcp.Platform.Tenant{} = tenant) do
    """
    CURRENT SUBJECT: Platform Tenant
    Name: #{tenant.name}
    Plan: #{tenant.plan}
    Status: #{tenant.status}
    Features: #{inspect(tenant.features)}
    """
  end

  defp describe_subject(nil), do: ""
  defp describe_subject(other), do: "CONTEXT: #{inspect(other)}"

  defp default_prompt do
    """
    You are Atlas, a general assistant for the Mcp platform.
    Provide friendly guidance on getting started and navigating the interface.
    """
  end

  # Persona: Developer / Admin
  defp persona_for(%User{role: role} = _user) when role in [:admin, :moderator] do
    """
    You are in Developer/Admin mode.
    Focus on technical health, API management, and overall platform administration.
    You can help with:
    - API keys and integration status
    - Webhook delivery monitoring
    - System-wide security and maintenance
    - Onboarding new merchants or resellers
    """
  end

  # Persona: Merchant
  defp persona_for(%User{merchant_id: merchant_id} = user) when not is_nil(merchant_id) do
    case user_merchant_category(user) do
      :applicant ->
        """
        You are assisting a Merchant Applicant (currently in the onboarding process).
        Focus on:
        - Their application status and required documents
        - Explaining verification steps (KYC/KYB)
        - Helping them complete their profile to get funded
        - Answering questions about the OLA application flow
        """

      :operator ->
        """
        You are assisting an active Merchant Operator.
        Focus on:
        - Payment volume, transaction trends, and settlement status
        - Managing their account settings and terminal configurations
        - Resolving active risk signals or transaction inquiries
        - Optimizing their use of the platform for business growth
        """
    end
  end

  # Persona: Reseller (If we find a way to distinguish, for now we treat as Tenant Admin)
  # Persona: Tenant Administrator (Acquirer)
  defp persona_for(%User{tenant_id: tenant_id} = _user) when not is_nil(tenant_id) do
    """
    You are assisting a Tenant Administrator (usually an Acquirer or ISO Manager).
    Focus on:
    - Portfolio-wide performance and merchant velocity
    - Underwriting queues and SLA compliance
    - Detecting risk clusters across multiple merchants
    - Payout and settlement status across the bank hierarchy
    """
  end

  defp persona_for(_) do
    default_prompt()
  end

  defp user_merchant_category(user) do
    # Check for category in metadata, which Respond.ex will populate
    Map.get(user.oauth_tokens, "merchant_category", :operator)
  end
end
