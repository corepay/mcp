defmodule Mcp.Underwriting.VendorRouter do
  @moduledoc """
  Decides which Underwriting Vendor to use for a given request.
  """

  alias Mcp.Underwriting.Adapters.ComplyCube
  alias Mcp.Underwriting.Adapters.Idenfy
  alias Mcp.Underwriting.Adapters.Mock
  alias Mcp.Utils.CircuitBreaker

  def select_adapter(_context \\ %{}) do
    # 1. Determine preferred adapter based on config or env
    adapter = determine_adapter()

    if CircuitBreaker.open?(service_name(adapter)) do
      # Fallback logic
      fallback = get_fallback_adapter(adapter)

      if CircuitBreaker.open?(service_name(fallback)) do
        # Both down, return original (Gateway handles failure)
        adapter
      else
        fallback
      end
    else
      adapter
    end
  end

  defp determine_adapter do
    from_adapter_config() || from_preferred_vendor() || from_api_keys()
  end

  defp from_adapter_config do
    case Application.get_env(:mcp, :underwriting_adapter) do
      :idenfy -> Idenfy
      :complycube -> ComplyCube
      :mock -> Mock
      _ -> nil
    end
  end

  defp from_preferred_vendor do
    case Application.get_env(:mcp, :preferred_vendor) do
      :idenfy -> Idenfy
      :comply_cube -> ComplyCube
      :complycube -> ComplyCube
      _ -> nil
    end
  end

  defp from_api_keys do
    if System.get_env("COMPLY_CUBE_API_KEY"), do: ComplyCube, else: Mock
  end

  defp get_fallback_adapter(Idenfy), do: ComplyCube
  defp get_fallback_adapter(ComplyCube), do: Idenfy
  defp get_fallback_adapter(_), do: Mock

  defp service_name(adapter), do: Atom.to_string(adapter)
end
