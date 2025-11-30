defmodule Mcp.Utils.RateLimiterTest do
  use ExUnit.Case
  alias Mcp.Utils.RateLimiter

  setup do
    # Clear Redis before tests
    Mcp.Redis.clear_pattern("rate_limit:*")
    :ok
  end

  test "check_limit/2 allows requests within limit" do
    key = "test_key_#{System.unique_integer()}"
    assert :ok == RateLimiter.check_limit(key, 2)
    assert :ok == RateLimiter.check_limit(key, 2)
  end

  test "check_limit/2 blocks requests exceeding limit" do
    key = "test_key_#{System.unique_integer()}"
    assert :ok == RateLimiter.check_limit(key, 1)
    assert {:error, :rate_limit_exceeded} == RateLimiter.check_limit(key, 1)
  end
end
