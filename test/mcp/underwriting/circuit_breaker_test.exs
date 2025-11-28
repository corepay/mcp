defmodule Mcp.Underwriting.CircuitBreakerTest do
  use ExUnit.Case
  alias Mcp.Underwriting.CircuitBreaker

  setup do
    # Ensure CircuitBreaker is running (it should be started by app, but for isolation we might want to restart or clear state if possible)
    # Since it's a named GenServer, we can just use it. 
    # For robust testing, we might want to start a fresh one with a different name, but the module is hardcoded to name __MODULE__.
    # We'll just use unique service names for each test.
    :ok
  end

  test "circuit is initially closed" do
    service = "test_service_1"
    assert :ok == CircuitBreaker.check_circuit(service)
  end

  test "circuit opens after threshold failures" do
    service = "test_service_2"
    
    # Report 4 failures (threshold is 5)
    for _ <- 1..4 do
      CircuitBreaker.report_failure(service)
    end
    assert :ok == CircuitBreaker.check_circuit(service)

    # Report 5th failure
    CircuitBreaker.report_failure(service)
    
    # Circuit should now be open
    assert {:error, :circuit_open} == CircuitBreaker.check_circuit(service)
  end

  test "success resets failure count" do
    service = "test_service_3"
    
    # Report 4 failures
    for _ <- 1..4 do
      CircuitBreaker.report_failure(service)
    end
    
    # Report success
    CircuitBreaker.report_success(service)
    
    # Report 1 more failure (total 1 since reset)
    CircuitBreaker.report_failure(service)
    
    # Should still be closed
    assert :ok == CircuitBreaker.check_circuit(service)
  end
end
