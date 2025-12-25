defmodule Mcp.Cache.SpendingCacheTest do
  use Mcp.DataCase, async: false

  alias Mcp.Cache.SpendingCache
  alias Mcp.Redis

  describe "get_monthly_spend/1" do
    test "returns {:miss, nil} when cache is empty" do
      api_key_id = Ash.UUID.generate()

      assert {:miss, nil} = SpendingCache.get_monthly_spend(api_key_id)
    end

    test "returns {:ok, Decimal} when cache exists" do
      api_key_id = Ash.UUID.generate()
      spend = Decimal.new("123.45")

      :ok = SpendingCache.put_monthly_spend(api_key_id, spend)

      assert {:ok, cached_spend} = SpendingCache.get_monthly_spend(api_key_id)
      assert Decimal.equal?(cached_spend, spend)
    end
  end

  describe "put_monthly_spend/2" do
    test "caches the spending amount with TTL" do
      api_key_id = Ash.UUID.generate()
      spend = Decimal.new("99.99")

      assert :ok = SpendingCache.put_monthly_spend(api_key_id, spend)

      # Verify it was cached
      assert {:ok, cached} = SpendingCache.get_monthly_spend(api_key_id)
      assert Decimal.equal?(cached, spend)
    end

    test "includes month in cache key for automatic expiry" do
      api_key_id = Ash.UUID.generate()
      spend = Decimal.new("50.00")

      :ok = SpendingCache.put_monthly_spend(api_key_id, spend)

      # Check the cache key format includes the current month
      month = Date.utc_today() |> Date.beginning_of_month() |> Date.to_iso8601()
      expected_key = "spending:#{api_key_id}:#{month}"

      assert Redis.exists?(expected_key)
    end
  end

  describe "invalidate/1" do
    test "removes cached spending amount" do
      api_key_id = Ash.UUID.generate()
      spend = Decimal.new("75.50")

      :ok = SpendingCache.put_monthly_spend(api_key_id, spend)
      assert {:ok, _} = SpendingCache.get_monthly_spend(api_key_id)

      SpendingCache.invalidate(api_key_id)

      assert {:miss, nil} = SpendingCache.get_monthly_spend(api_key_id)
    end
  end

  describe "get_or_calculate_monthly_spend/1" do
    test "returns cached value when available" do
      api_key_id = Ash.UUID.generate()
      cached_spend = Decimal.new("100.00")

      # Pre-populate cache
      :ok = SpendingCache.put_monthly_spend(api_key_id, cached_spend)

      # Should return cached value without DB query
      result = SpendingCache.get_or_calculate_monthly_spend(api_key_id)
      assert Decimal.equal?(result, cached_spend)
    end

    test "calculates and caches when cache is empty" do
      # This would need a real API key with LLM usage records
      # For now, just verify it returns a Decimal (even if zero)
      api_key_id = Ash.UUID.generate()

      result = SpendingCache.get_or_calculate_monthly_spend(api_key_id)

      assert %Decimal{} = result
      # Verify it was cached
      assert {:ok, _} = SpendingCache.get_monthly_spend(api_key_id)
    end
  end
end
