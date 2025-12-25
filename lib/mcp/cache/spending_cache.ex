defmodule Mcp.Cache.SpendingCache do
  @moduledoc """
  Provides caching for API key spending limit queries using Redis.
  Caches monthly spending totals to reduce database load on API requests.
  """
  alias Mcp.Ai.LlmUsage
  alias Mcp.Redis

  @ttl_seconds 60

  @doc """
  Retrieves cached monthly spend for the given API key ID.
  Returns `{:ok, Decimal}` if found in cache, or `{:miss, nil}` if not cached.
  """
  def get_monthly_spend(api_key_id) do
    key = cache_key(api_key_id)

    case Redis.get(key) do
      {:ok, nil} ->
        {:miss, nil}

      {:ok, json_string} ->
        case Jason.decode(json_string) do
          {:ok, %{"value" => value}} ->
            {:ok, Decimal.new(value)}

          _ ->
            {:miss, nil}
        end

      _ ->
        {:miss, nil}
    end
  end

  @doc """
  Caches the monthly spend for the given API key ID.
  TTL is set to #{@ttl_seconds} seconds to balance freshness with performance.
  """
  def put_monthly_spend(api_key_id, spend) when is_struct(spend, Decimal) do
    key = cache_key(api_key_id)
    value = %{"value" => Decimal.to_string(spend)}

    case Jason.encode(value) do
      {:ok, json_string} ->
        Redis.set(key, json_string, @ttl_seconds)

      _ ->
        :error
    end
  end

  @doc """
  Invalidates the cached monthly spend for the given API key ID.
  Should be called whenever new LLM usage is recorded.
  """
  def invalidate(api_key_id) do
    key = cache_key(api_key_id)
    Redis.delete(key)
  end

  @doc """
  Gets monthly spend from cache, or calculates it from the database if not cached.
  This is the primary function to use for checking spending limits.
  """
  def get_or_calculate_monthly_spend(api_key_id) do
    case get_monthly_spend(api_key_id) do
      {:ok, spend} ->
        spend

      {:miss, nil} ->
        start_date = Date.beginning_of_month(Date.utc_today())
        end_date = Date.utc_today()
        spend = LlmUsage.calculate_spend(api_key_id, start_date, end_date)
        put_monthly_spend(api_key_id, spend)
        spend
    end
  end

  defp cache_key(api_key_id) do
    month = Date.utc_today() |> Date.beginning_of_month() |> Date.to_iso8601()
    "spending:#{api_key_id}:#{month}"
  end
end
