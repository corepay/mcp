defmodule Mcp.Underwriting.Atlas.ContextHints do
  @moduledoc """
  Provides contextual guidance hints for the OLA application flow.
  This is "Atlas Lite" - predetermined helpful prompts based on application state.
  """

  defmodule Hint do
    @moduledoc false
    defstruct [:message, :suggestions, :idle_prompt, :icon]
  end

  @doc """
  Returns a hint based on current step and context.

  Context options:
  - idle_seconds: How long user has been idle
  - field_focus: Which field they're currently on
  - errors: Any validation errors
  """
  def get_hint(step, context \\ %{})

  def get_hint(:business_info, context) do
    %Hint{
      message: "Let's start with your business details. I'll help you through each step.",
      suggestions: [
        "What's my business type?",
        "Where do I find my EIN?"
      ],
      idle_prompt: idle_prompt_for(:business_info, context),
      icon: "hero-building-office"
    }
  end

  def get_hint(:owners, context) do
    %Hint{
      message: "Now I need info about anyone who owns 25% or more of the business.",
      suggestions: [
        "What if I'm the only owner?",
        "Why do you need SSN?"
      ],
      idle_prompt: idle_prompt_for(:owners, context),
      icon: "hero-users"
    }
  end

  def get_hint(:documents, context) do
    %Hint{
      message: "Almost there! Upload your documents and I'll verify them instantly.",
      suggestions: [
        "What documents do I need?",
        "Can I use my phone camera?"
      ],
      idle_prompt: idle_prompt_for(:documents, context),
      icon: "hero-document"
    }
  end

  def get_hint(:banking, context) do
    %Hint{
      message: "Final step - where should we send your money?",
      suggestions: [
        "Is Plaid secure?",
        "Can I change this later?"
      ],
      idle_prompt: idle_prompt_for(:banking, context),
      icon: "hero-banknotes"
    }
  end

  def get_hint(:review, _context) do
    %Hint{
      message: "Review your application. Once submitted, I'll have a decision in minutes!",
      suggestions: [
        "What happens after I submit?",
        "Can I edit after submission?"
      ],
      idle_prompt: nil,
      icon: "hero-check-circle"
    }
  end

  def get_hint(_, _context) do
    %Hint{
      message: "I'm here to help! Ask me anything about the application.",
      suggestions: ["How long does approval take?", "Is my data secure?"],
      idle_prompt: nil,
      icon: "hero-chat-bubble-left-right"
    }
  end

  defp idle_prompt_for(:business_info, %{idle_seconds: s}) when s > 30 do
    "Not sure about something? The business name should match your tax documents exactly."
  end

  defp idle_prompt_for(:owners, %{idle_seconds: s}) when s > 30 do
    "Stuck on the SSN? We use it for identity verification only - " <>
      "it's encrypted and never stored in plain text."
  end

  defp idle_prompt_for(:documents, %{idle_seconds: s}) when s > 30 do
    "Need help with documents? A clear photo of your driver's license " <>
      "(front and back) is all we need for ID."
  end

  defp idle_prompt_for(:banking, %{idle_seconds: s}) when s > 30 do
    "Having trouble? You can connect via Plaid (instant) or enter your " <>
      "routing/account numbers manually."
  end

  defp idle_prompt_for(_, _), do: nil

  @doc """
  Returns a response to a common question.
  """
  def answer_faq(question) do
    faqs = %{
      "business type" =>
        "Choose the legal structure of your business: LLC, Corporation, " <>
          "Sole Proprietor, etc. Not sure? Check your formation documents.",
      "ein" =>
        "Your EIN (Employer Identification Number) is on your IRS SS-4 " <>
          "confirmation letter, usually at the top right. It's 9 digits: XX-XXXXXXX",
      "ssn" =>
        "We need SSN for identity verification and credit check. It's encrypted " <>
          "immediately and we never store it in plain text.",
      "document" =>
        "You'll need: 1) Government ID (driver's license or passport), " <>
          "2) Voided check or bank letter, 3) Optionally: business license",
      "approval" =>
        "Most applications are approved in under 5 minutes. Complex cases may " <>
          "take up to 24 hours for manual review.",
      "secure" =>
        "Absolutely. We use bank-level encryption, and your data is protected " <>
          "under PCI DSS and SOC 2 compliance."
    }

    question_lower = String.downcase(question)

    Enum.find_value(faqs, fn {key, answer} ->
      if String.contains?(question_lower, key), do: answer
    end) ||
      "I don't have a specific answer for that, but you can always ask " <>
        "our support team for help."
  end
end
