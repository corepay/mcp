defmodule Mcp.Underwriting.HybridRiskEngine do
  @moduledoc """
  Hybrid risk evaluation engine combining ML predictions with rule-based scoring.

  This module orchestrates risk assessment by:
  1. Extracting numeric features from application data
  2. Getting ML-based risk predictions when available
  3. Getting rule-based risk scores from RiskEngine
  4. Combining scores with confidence-based weighting
  5. Generating final recommendations

  The ML weight is determined by prediction confidence:
  - confidence >= 0.9: ml_weight = 0.8
  - confidence >= 0.8: ml_weight = 0.7
  - confidence >= 0.7: ml_weight = 0.6
  - else: ml_weight = 0.5

  When ML predictions are unavailable, falls back to rules-only evaluation.
  """

  alias Mcp.Underwriting.RiskEngine

  defstruct [
    :score,
    :reasons,
    :recommendation,
    :ml_score,
    :rule_score,
    :ml_weight,
    :flags
  ]

  @type t :: %__MODULE__{
          score: integer(),
          reasons: [String.t()],
          recommendation: :approve | :manual_review | :reject,
          ml_score: integer() | nil,
          rule_score: integer(),
          ml_weight: float(),
          flags: [String.t()]
        }

  @doc """
  Evaluates an application using hybrid ML + rule-based approach.

  ## Parameters
    - application: Application struct with application_data map
    - vendor_data: Map of vendor verification data
    - ml_client: Module implementing predict/1 (defaults to MlRiskClient)

  ## Returns
    - HybridRiskEngine struct with combined evaluation results
  """
  def evaluate(application, vendor_data, ml_client \\ Mcp.Underwriting.MlRiskClient) do
    # Get rule-based score
    rule_result = RiskEngine.evaluate(application, vendor_data)
    rule_score = rule_result.score

    # Attempt ML prediction
    features = extract_features(application)

    {ml_score, ml_weight, reasons} =
      case ml_client.predict(features) do
        {:ok, %{score: score, confidence: confidence}} ->
          weight = calculate_ml_weight(confidence)
          {score, weight, rule_result.reasons}

        {:error, _reason} ->
          {nil, 0.0, rule_result.reasons ++ ["ML prediction unavailable, using rules only"]}
      end

    # Calculate combined score
    combined_score =
      if ml_score do
        round(ml_score * ml_weight + rule_score * (1.0 - ml_weight))
      else
        rule_score
      end

    # Determine recommendation
    recommendation = determine_recommendation(combined_score)

    %__MODULE__{
      score: combined_score,
      reasons: reasons,
      recommendation: recommendation,
      ml_score: ml_score,
      rule_score: rule_score,
      ml_weight: ml_weight,
      flags: rule_result.flags
    }
  end

  @doc """
  Extracts numeric features from application data for ML prediction.

  Converts string values to integers and handles special cases:
  - business_years, monthly_volume, mcc, owner_count: parsed as integers
  - has_website: 1 if website field is present and non-empty, 0 otherwise

  ## Parameters
    - application: Application struct with application_data map

  ## Returns
    - Map of numeric features for ML model
  """
  def extract_features(application) do
    data = application.application_data

    %{
      business_years: parse_int(data["business_years"]),
      monthly_volume: parse_int(data["monthly_volume"]),
      mcc: parse_int(data["mcc"]),
      owner_count: parse_int(data["owner_count"]),
      has_website: if(has_website?(data), do: 1, else: 0)
    }
  end

  # Private Functions

  defp calculate_ml_weight(confidence) when confidence >= 0.9, do: 0.8
  defp calculate_ml_weight(confidence) when confidence >= 0.8, do: 0.7
  defp calculate_ml_weight(confidence) when confidence >= 0.7, do: 0.6
  defp calculate_ml_weight(_confidence), do: 0.5

  defp determine_recommendation(score) when score >= 80, do: :approve
  defp determine_recommendation(score) when score >= 50, do: :manual_review
  defp determine_recommendation(_score), do: :reject

  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp parse_int(_value), do: 0

  defp has_website?(data) do
    case data["website"] do
      nil -> false
      "" -> false
      _url -> true
    end
  end
end
