defmodule Mcp.Underwriting.Rules.KYBRule do
  @behaviour Mcp.Underwriting.RiskEngine.RiskRule

  def evaluate(_application, vendor_data) do
    kyb = Map.get(vendor_data, :kyb, %{})
    
    case kyb[:status] do
      :clear -> {:ok, 40, ["KYB Clear"]}
      :flagged -> {:ok, -50, ["KYB Flagged"]}
      :review -> {:ok, -20, ["KYB Review Needed"]}
      _ -> {:ok, 0, []}
    end
  end
end
