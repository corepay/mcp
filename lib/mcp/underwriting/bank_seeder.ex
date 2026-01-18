defmodule Mcp.Underwriting.BankSeeder do
  @moduledoc """
  Seeds the bank profile and processor matrix for placement logic.
  """
  require Ash.Query
  alias Mcp.Underwriting.{BankProfile, Processor}

  def run do
    IO.puts("🌱 Seeding Bank & Processor Matrix...")

    # 1. Create Processors
    p_fiserv = ensure_processor("Fiserv", "Mcp.Underwriting.Adapters.Fiserv")
    p_stripe = ensure_processor("Stripe", "Mcp.Underwriting.Adapters.Stripe")
    p_adyen = ensure_processor("Adyen", "Mcp.Underwriting.Adapters.Adyen")
    p_qorpay = ensure_processor("QorPay", "Mcp.Underwriting.Adapters.QorPay")

    # 2. Create Bank Profiles

    # FISERV PROFILES
    ensure_bank_profile(
      p_fiserv,
      "Fiserv Retail Standard",
      %{
        "allowed_industries" => ["retail", "restaurant"],
        "min_score" => 60,
        "max_monthly_volume" => 500_000,
        "unsupported_industries" => ["cbd", "crypto", "gambling"]
      },
      40
    )

    ensure_bank_profile(
      p_fiserv,
      "Fiserv High Risk",
      %{
        "allowed_industries" => ["gaming", "supplements", "vape"],
        "min_score" => 75,
        "max_monthly_volume" => 1_000_000,
        "unsupported_industries" => ["crypto", "pornography"]
      },
      80
    )

    # STRIPE PROFILES
    ensure_bank_profile(
      p_stripe,
      "Stripe E-Commerce",
      %{
        "allowed_industries" => ["saas", "digital_goods", "clothing"],
        "min_score" => 50,
        "max_monthly_volume" => 250_000,
        "unsupported_industries" => ["high_risk_retail", "travel"]
      },
      30,
      true
    )

    # ADYEN PROFILES
    ensure_bank_profile(
      p_adyen,
      "Adyen Global Enterprise",
      %{
        "allowed_industries" => ["airlines", "hotels", "global_retail"],
        "min_score" => 80,
        "max_monthly_volume" => 50_000_000,
        "unsupported_industries" => ["microlending"]
      },
      60
    )

    # QORPAY PROFILES
    ensure_bank_profile(
      p_qorpay,
      "QorPay Omnichannel",
      %{
        "allowed_industries" => ["retail", "ecommerce", "professional_services"],
        "min_score" => 65,
        "max_monthly_volume" => 1_000_000,
        "unsupported_industries" => ["high_risk_retail"]
      },
      45
    )

    IO.puts("✅ Bank Matrix Seeded.")
  end

  defp ensure_processor(name, adapter) do
    case Ash.Query.filter(Processor, name == ^name) |> Ash.read_one() do
      {:ok, nil} ->
        Ash.create!(Processor, %{name: name, adapter: adapter}, authorize?: false)

      {:ok, p} ->
        p
    end
  end

  defp ensure_bank_profile(processor, name, rules, weight, is_default \\ false) do
    case Ash.Query.filter(BankProfile, name == ^name) |> Ash.read_one() do
      {:ok, nil} ->
        Ash.create!(
          BankProfile,
          %{
            name: name,
            appetite_rules: rules,
            risk_weight: weight,
            is_default: is_default,
            processor_id: processor.id
          },
          authorize?: false
        )

      {:ok, bp} ->
        bp
    end
  end
end
