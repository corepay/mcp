defmodule Mcp.Underwriting.Services.PlacementIntelligence do
  @moduledoc """
  Service for matching underwriting applications with the most profitable and likely bank processor.
  Implements the 'Profit-Aware Router' pattern.
  """
  require Ash.Query
  alias Mcp.Platform.Merchant
  alias Mcp.Underwriting.{Application, BankProfile, RiskAssessment}

  @doc """
  Suggests the best bank placement for a given application and its risk assessment.
  """
  def suggest_placement(application_id, assessment_id, tenant_schema) do
    # 1. Load Data
    app = Application.get_by_id!(application_id, tenant: tenant_schema)
    assessment = RiskAssessment.get_by_id!(assessment_id, tenant: tenant_schema)

    # 2. Load Bank Profiles (Global) with Processors
    profiles =
      BankProfile
      |> Ash.Query.load([:processor])
      |> Ash.read!()

    # 3. Resolve Merchant Country
    # In a real scenario, we'd load this from the Merchant resource.
    # For now, we'll check application_data or default to US.
    merchant_country =
      app.application_data["country"] ||
        if(app.subject_type == :merchant,
          do: Merchant.get_by_id!(app.subject_id, tenant: tenant_schema).country,
          else: "US"
        )

    # 4. Filtering & Scoring
    eligible_profiles =
      profiles
      |> Enum.filter(fn profile ->
        region_ok = merchant_country in profile.processor.supported_regions
        region_ok && can_accept?(profile, app, assessment)
      end)
      |> Enum.sort_by(
        fn profile ->
          # Scoring logic: prefer lower risk weight for safer apps
          score_diff = abs(profile.risk_weight - assessment.score)
          score_diff
        end,
        :asc
      )

    case eligible_profiles do
      [best | _] ->
        rationale = """
        Matched based on risk score (#{assessment.score}) vs profile weight (#{best.risk_weight}).
        Industry: #{app.application_data["industry"] || "standard"} (Eligible).
        Volume: #{app.application_data["monthly_volume"] || 0} / Max: #{best.appetite_rules["max_monthly_volume"] || 999_999_999}.
        """

        {:ok, %{profile: best, rationale: rationale}}

      [] ->
        {:error, :no_eligible_banks}
    end
  end

  defp can_accept?(profile, app, assessment) do
    rules = profile.appetite_rules || %{}

    industry_ok?(rules, app.application_data["industry"]) &&
      score_ok?(rules, assessment.score) &&
      volume_ok?(rules, app.application_data["monthly_volume"])
  end

  defp industry_ok?(rules, industry) do
    industry = industry || "standard"
    unsupported = rules["unsupported_industries"] || []
    allowed = rules["allowed_industries"] || []

    cond do
      Enum.member?(unsupported, industry) -> false
      Enum.empty?(allowed) -> true
      Enum.member?(allowed, industry) -> true
      true -> false
    end
  end

  defp score_ok?(rules, score) do
    min_score = rules["min_score"] || 0
    score >= min_score
  end

  defp volume_ok?(rules, volume) do
    monthly_volume = volume || 0
    max_volume = rules["max_monthly_volume"] || 999_999_999
    monthly_volume <= max_volume
  end
end
