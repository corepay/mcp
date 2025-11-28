defmodule Mcp.Underwriting.VendorRouterTest do
  use ExUnit.Case
  alias Mcp.Underwriting.VendorRouter
  alias Mcp.Underwriting.CircuitBreaker
  alias Mcp.Underwriting.Adapters.ComplyCube
  alias Mcp.Underwriting.Adapters.Idenfy

  setup do
    # Reset configuration
    original_adapter = Application.get_env(:mcp, :underwriting_adapter)
    original_preferred = Application.get_env(:mcp, :preferred_vendor)
    
    # Disable forced Mock for these tests
    Application.delete_env(:mcp, :underwriting_adapter)
    
    on_exit(fn ->
      if original_adapter, do: Application.put_env(:mcp, :underwriting_adapter, original_adapter)
      if original_preferred, do: Application.put_env(:mcp, :preferred_vendor, original_preferred)
    end)
    
    :ok
  end

  test "selects preferred vendor when circuit is closed" do
    Application.put_env(:mcp, :preferred_vendor, :comply_cube)
    
    # Ensure circuit is closed (might need to reset if previous tests opened it)
    # Since we can't easily reset, we rely on unique names or just reporting success enough times?
    # Or we can just assume it's closed if we haven't failed it.
    # To be safe, report success.
    CircuitBreaker.report_success("Elixir.Mcp.Underwriting.Adapters.ComplyCube")
    
    assert VendorRouter.select_adapter() == ComplyCube
  end

  test "falls back to secondary vendor when preferred circuit is open" do
    Application.put_env(:mcp, :preferred_vendor, :comply_cube)
    
    service_name = "Elixir.Mcp.Underwriting.Adapters.ComplyCube"
    
    # Open the circuit for ComplyCube
    for _ <- 1..6 do
      CircuitBreaker.report_failure(service_name)
    end
    
    assert CircuitBreaker.check_circuit(service_name) == {:error, :circuit_open}
    
    # Should now return Idenfy
    assert VendorRouter.select_adapter() == Idenfy
  end

  test "falls back to primary if secondary is also open (last resort)" do
    Application.put_env(:mcp, :preferred_vendor, :comply_cube)
    
    primary = "Elixir.Mcp.Underwriting.Adapters.ComplyCube"
    secondary = "Elixir.Mcp.Underwriting.Adapters.Idenfy"
    
    # Open both circuits
    for _ <- 1..6 do
      CircuitBreaker.report_failure(primary)
      CircuitBreaker.report_failure(secondary)
    end
    
    assert CircuitBreaker.check_circuit(primary) == {:error, :circuit_open}
    assert CircuitBreaker.check_circuit(secondary) == {:error, :circuit_open}
    
    # Should return primary (ComplyCube) as last resort
    assert VendorRouter.select_adapter() == ComplyCube
  end
end
