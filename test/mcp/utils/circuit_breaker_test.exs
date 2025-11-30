defmodule Mcp.Utils.CircuitBreakerTest do
  use ExUnit.Case
  alias Mcp.Utils.CircuitBreaker

  setup do
    # Reset circuit breaker state for test service
    service = "test_service_#{System.unique_integer()}"
    CircuitBreaker.record_success(service)
    {:ok, service: service}
  end

  test "execute/2 runs function successfully", %{service: service} do
    result = CircuitBreaker.execute(service, fn -> {:ok, :success} end)
    assert {:ok, :success} == result
    assert false == CircuitBreaker.open?(service)
  end

  test "execute/2 records failure and opens circuit", %{service: service} do
    # Fail 5 times to trip threshold
    for _ <- 1..5 do
      CircuitBreaker.execute(service, fn -> {:error, :fail} end)
    end

    assert true == CircuitBreaker.open?(service)
    
    # Next call should fail fast
    assert {:error, :circuit_open} == CircuitBreaker.execute(service, fn -> {:ok, :should_not_run} end)
  end

  test "execute/2 recovers after success", %{service: service} do
    CircuitBreaker.record_failure(service)
    assert false == CircuitBreaker.open?(service)
    
    CircuitBreaker.record_success(service)
    assert false == CircuitBreaker.open?(service)
  end
end
