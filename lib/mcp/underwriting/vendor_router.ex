defmodule Mcp.Underwriting.VendorRouter do
  @moduledoc """
  Decides which Underwriting Vendor to use for a given request.
  """

  alias Mcp.Underwriting.Adapters.ComplyCube
  alias Mcp.Underwriting.Adapters.Idenfy
  alias Mcp.Underwriting.Adapters.Mock

  def select_adapter(_context \\ %{}) do
    # 1. Determine preferred adapter based on config or env
    adapter = determine_adapter()

    # 2. Check circuit breaker
    case Mcp.Underwriting.CircuitBreaker.check_circuit(service_name(adapter)) do
      :ok ->
        adapter

      {:error, :circuit_open} ->
        # Fallback logic
        fallback = get_fallback_adapter(adapter)

        case Mcp.Underwriting.CircuitBreaker.check_circuit(service_name(fallback)) do
          :ok ->
            fallback

          {:error, :circuit_open} ->
            # Both down, return original (Gateway handles failure)
            adapter
        end
    end
  end

  defp determine_adapter do
    case Application.get_env(:mcp, :underwriting_adapter) do
      :idenfy ->
        Idenfy

      :complycube ->
        ComplyCube

      :mock ->
        Mock

      _ ->
        # Auto-detect based on API keys
        cond do
          System.get_env("COMPLY_CUBE_API_KEY") -> ComplyCube
          true -> Mock
        end
    end
  end

  defp get_fallback_adapter(Idenfy), do: ComplyCube
  defp get_fallback_adapter(ComplyCube), do: Idenfy
  defp get_fallback_adapter(_), do: Mock

  defp service_name(adapter), do: Atom.to_string(adapter)
end
