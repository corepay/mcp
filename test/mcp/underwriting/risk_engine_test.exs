defmodule Mcp.Underwriting.RiskEngineTest do
  use ExUnit.Case
  alias Mcp.Underwriting.RiskEngine

  # Mock Application struct
  defmodule MockApplication do
    defstruct [:id, :merchant_id, :application_data]
  end

  test "evaluates rules and calculates score" do
    application = %MockApplication{
      application_data: %{}
    }

    # Scenario 1: High Credit Score, Valid Documents
    vendor_data = %{
      kyb: %{credit_score: 750},
      documents: [{:ok, %{status: :valid}}, {:ok, %{status: :valid}}]
    }

    result = RiskEngine.evaluate(application, vendor_data)
    
    # Base 50 + 20 (Credit) + 20 (Docs) = 90
    assert result.score == 90
    assert "Good Credit Score" in result.reasons
    assert "2 Valid Documents" in result.reasons

    # Scenario 2: Low Credit Score, Invalid Documents
    vendor_data_bad = %{
      kyb: %{credit_score: 450},
      documents: [{:ok, %{status: :invalid}}]
    }

    result_bad = RiskEngine.evaluate(application, vendor_data_bad)
    
    # Base 50 - 20 (Credit) - 50 (Docs) = -20 -> clamped to 0
    assert result_bad.score == 0
    assert "Poor Credit Score" in result_bad.reasons
    assert "Invalid Documents Found" in result_bad.reasons
  end
end
