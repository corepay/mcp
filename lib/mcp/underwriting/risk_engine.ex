defmodule Mcp.Underwriting.RiskEngine do
  @moduledoc """
  Evaluates an application against a set of risk rules.
  """



  defmodule RiskRule do
    @callback evaluate(application :: Mcp.Underwriting.Application.t(), vendor_data :: map()) :: 
      {:ok, score_adjustment :: integer(), reasons :: [String.t()]} | {:error, term()}
  end

  @rules [
    Mcp.Underwriting.Rules.KYBRule,
    Mcp.Underwriting.Rules.CreditScoreRule,
    Mcp.Underwriting.Rules.DocumentVerificationRule
  ]

  def evaluate(application, vendor_data) do
    initial_score = 50 # Base score

    Enum.reduce(@rules, %{score: initial_score, reasons: [], flags: []}, fn rule, acc ->
      case rule.evaluate(application, vendor_data) do
        {:ok, adjustment, reasons} ->
          %{acc | 
            score: clamp_score(acc.score + adjustment),
            reasons: acc.reasons ++ reasons
          }
        _ ->
          acc
      end
    end)
  end

  defp clamp_score(score), do: max(0, min(100, score))
end
