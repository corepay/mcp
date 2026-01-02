defmodule Mcp.Underwriting.Services.MlRiskClient do
  @moduledoc """
  Client for the ML Risk Model sidecar service.
  Falls back to rule-based scoring if ML service unavailable.
  """

  @default_base_url "http://localhost:48292"

  defstruct [:score, :confidence, :risk_factors, :recommendation]

  def base_url do
    System.get_env("ML_RISK_URL", @default_base_url)
  end

  @doc """
  Gets a risk prediction for the given features.
  Falls back to rule-based scoring if ML service unavailable.

  ## Parameters
    - features: Map with business features like business_years, monthly_volume, mcc
    - opts: Optional keyword list with :base_url override

  ## Returns
    - {:ok, %MlRiskClient{}} with score, confidence, risk_factors, recommendation
    - {:error, reason} if prediction fails

  ## Examples

      iex> MlRiskClient.predict(%{business_years: 5, monthly_volume: 50000})
      {:ok, %MlRiskClient{score: 75, confidence: 0.7, risk_factors: [], recommendation: :manual_review}}
  """
  def predict(features, opts \\ []) do
    url = Keyword.get(opts, :base_url, base_url())

    case Req.post("#{url}/predict", json: %{features: features}) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, parse_prediction(body)}

      {:ok, %{status: _status}} ->
        # API error - fallback to rule-based
        fallback_prediction(features)

      {:error, _} ->
        # Connection error - fallback to rule-based
        fallback_prediction(features)
    end
  end

  @doc """
  Checks if the ML service is healthy.

  ## Returns
    - {:ok, health_data} if service is running
    - {:error, :service_unavailable} if service is down
  """
  def health_check(opts \\ []) do
    url = Keyword.get(opts, :base_url, base_url())

    case Req.get("#{url}/health") do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      _ ->
        {:error, :service_unavailable}
    end
  end

  defp parse_prediction(body) do
    %__MODULE__{
      score: body["score"],
      confidence: body["confidence"],
      risk_factors: body["risk_factors"] || [],
      recommendation: String.to_existing_atom(body["recommendation"])
    }
  end

  defp fallback_prediction(features) do
    # Simple rule-based fallback
    base_score = 50

    score =
      base_score
      |> adjust_for_business_age(features)
      |> adjust_for_volume(features)
      |> clamp(0, 100)

    recommendation =
      cond do
        score >= 80 -> :auto_approve
        score >= 50 -> :manual_review
        true -> :decline
      end

    {:ok,
     %__MODULE__{
       score: score,
       confidence: 0.7,
       risk_factors: [],
       recommendation: recommendation
     }}
  end

  defp adjust_for_business_age(score, %{business_years: years}) when years >= 5, do: score + 15
  defp adjust_for_business_age(score, %{business_years: years}) when years >= 2, do: score + 10
  defp adjust_for_business_age(score, %{business_years: years}) when years < 1, do: score - 10
  defp adjust_for_business_age(score, _), do: score

  defp adjust_for_volume(score, %{monthly_volume: vol}) when vol >= 50_000, do: score + 10
  defp adjust_for_volume(score, %{monthly_volume: vol}) when vol < 10_000, do: score - 5
  defp adjust_for_volume(score, _), do: score

  defp clamp(val, min, max), do: val |> max(min) |> min(max)
end
