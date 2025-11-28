defmodule Mcp.Underwriting.Rules.DocumentVerificationRule do
  @behaviour Mcp.Underwriting.RiskEngine.RiskRule

  def evaluate(_application, vendor_data) do
    # Check document results
    doc_results = Map.get(vendor_data, :documents, [])
    
    valid_count = Enum.count(doc_results, fn 
      {:ok, %{status: :valid}} -> true
      _ -> false
    end)
    
    invalid_count = Enum.count(doc_results, fn 
      {:ok, %{status: :invalid}} -> true
      {:error, _} -> true # Treat errors as potential invalid for risk scoring? Or neutral?
      _ -> false
    end)
    
    cond do
      invalid_count > 0 -> {:ok, -50, ["Invalid Documents Found"]}
      valid_count > 0 -> {:ok, 10 * valid_count, ["#{valid_count} Valid Documents"]}
      true -> {:ok, 0, []}
    end
  end
end
