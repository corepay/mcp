defmodule Mcp.Underwriting.Rules.CreditScoreRule do
  @behaviour Mcp.Underwriting.RiskEngine.RiskRule

  def evaluate(_application, vendor_data) do
    # Extract credit score from vendor data (e.g., from KYB or separate check)
    # For now, assume it's in kyb_result under "credit_score" or similar
    
    score = get_in(vendor_data, [:kyb, :credit_score]) || 0
    
    cond do
      score >= 700 -> {:ok, 20, ["Good Credit Score"]}
      score >= 600 -> {:ok, 10, ["Average Credit Score"]}
      score < 500 && score > 0 -> {:ok, -20, ["Poor Credit Score"]}
      true -> {:ok, 0, []}
    end
  end
end
