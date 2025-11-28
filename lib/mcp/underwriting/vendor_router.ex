defmodule Mcp.Underwriting.VendorRouter do
  @moduledoc """
  Decides which Underwriting Vendor to use for a given request.
  """

  alias Mcp.Underwriting.Adapters.ComplyCube
  alias Mcp.Underwriting.Adapters.Idenfy
  alias Mcp.Underwriting.Adapters.Mock

  alias Mcp.Underwriting.CircuitBreaker

  def select_adapter(_context \\ %{}) do
    # 1. Check if we are in test mode or forced mock
    if Application.get_env(:mcp, :underwriting_adapter) == Mock do
      Mock
    else
      # Fetch settings from DB (or default)
      settings = 
        case Mcp.Underwriting.VendorSettings.get_settings() do
          {:ok, [record | _]} -> record
          {:ok, []} -> %{preferred_vendor: :comply_cube} # Default
          _ -> %{preferred_vendor: :comply_cube}
        end

      preferred = settings.preferred_vendor
      preferred_adapter = get_adapter_module(preferred)
      
      # Check circuit for preferred vendor
      if CircuitBreaker.check_circuit(service_name(preferred_adapter)) == :ok do
        preferred_adapter
      else
        # Preferred is down, try fallback
        fallback = get_fallback_vendor(preferred)
        fallback_adapter = get_adapter_module(fallback)
        
        if CircuitBreaker.check_circuit(service_name(fallback_adapter)) == :ok do
          fallback_adapter
        else
          # Both down, return preferred (will likely fail, or we could return a special error tuple if we refactor Gateway)
          # For now, return preferred to maintain contract, Gateway will handle the failure
          preferred_adapter
        end
      end
    end
  end

  defp get_adapter_module(:idenfy), do: Idenfy
  defp get_adapter_module(:comply_cube), do: ComplyCube
  defp get_adapter_module(_), do: ComplyCube

  defp get_fallback_vendor(:idenfy), do: :comply_cube
  defp get_fallback_vendor(:comply_cube), do: :idenfy
  defp get_fallback_vendor(_), do: :idenfy

  defp service_name(adapter), do: Atom.to_string(adapter)
end
