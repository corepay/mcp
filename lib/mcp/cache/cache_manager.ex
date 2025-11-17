defmodule McpCache.CacheManager do
  @moduledoc """
  High-level cache management service.
  Handles cache warming, invalidation, and analytics.
  """

  use GenServer
  require Logger

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Cache CacheManager")
    {:ok, %{stats: %{hits: 0, misses: 0, operations: 0}}}
  end

  def cache_query_result(query_key, query_result, opts \\ []) do
    GenServer.call(__MODULE__, {:cache_query, query_key, query_result, opts})
  end

  def get_cached_query(query_key, opts \\ []) do
    GenServer.call(__MODULE__, {:get_cached_query, query_key, opts})
  end

  def invalidate_cache_pattern(pattern, opts \\ []) do
    GenServer.call(__MODULE__, {:invalidate_pattern, pattern, opts})
  end

  def warm_cache(cache_items, opts \\ []) do
    GenServer.call(__MODULE__, {:warm_cache, cache_items, opts})
  end

  def get_cache_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  def increment_cache_hit do
    GenServer.cast(__MODULE__, :increment_hit)
  end

  def increment_cache_miss do
    GenServer.cast(__MODULE__, :increment_miss)
  end

  @impl true
  def handle_call({:cache_query, query_key, query_result, opts}, _from, state) do
    cache_key = build_cache_key("query", query_key, opts)
    ttl = Keyword.get(opts, :ttl, 1800)  # 30 minutes default

    case McpCache.RedisClient.set_with_ttl(cache_key, query_result, ttl, opts) do
      :ok ->
        new_stats = update_stats(state.stats, :operations)
        {:reply, :ok, %{state | stats: new_stats}}
      error ->
        Logger.error("Failed to cache query result: #{inspect(error)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_cached_query, query_key, opts}, _from, state) do
    cache_key = build_cache_key("query", query_key, opts)

    case McpCache.RedisClient.get(cache_key, opts) do
      {:ok, result} ->
        # Async hit update to avoid blocking
        GenServer.cast(__MODULE__, :increment_hit)
        {:reply, {:ok, result}, state}
      {:error, :not_found} ->
        # Async miss update to avoid blocking
        GenServer.cast(__MODULE__, :increment_miss)
        {:reply, {:error, :not_found}, state}
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:invalidate_pattern, pattern, opts}, _from, state) do
    cache_pattern = build_cache_key("", pattern, opts)

    case McpCache.RedisClient.clear_pattern(cache_pattern, opts) do
      :ok ->
        Logger.info("Invalidated cache pattern: #{cache_pattern}")
        new_stats = update_stats(state.stats, :operations)
        {:reply, :ok, %{state | stats: new_stats}}
      error ->
        Logger.error("Failed to invalidate cache pattern: #{inspect(error)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:warm_cache, cache_items, opts}, _from, state) do
    results = Enum.map(cache_items, fn {key, value, item_opts} ->
      merged_opts = Keyword.merge(opts, item_opts)
      cache_key = build_cache_key("warm", key, merged_opts)

      case McpCache.RedisClient.set(cache_key, value, merged_opts) do
        :ok -> {:ok, key}
        error -> {:error, {key, error}}
      end
    end)

    successful_warms = Enum.count(results, &match?({:ok, _}, &1))
    Logger.info("Cache warming completed: #{successful_warms}/#{length(cache_items)} items")

    new_stats = update_stats(state.stats, :operations)
    {:reply, {:ok, results}, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    hit_rate = calculate_hit_rate(state.stats)
    stats_with_rate = Map.put(state.stats, :hit_rate, hit_rate)
    {:reply, {:ok, stats_with_rate}, state}
  end

  @impl true
  def handle_cast(:increment_hit, state) do
    new_stats = update_stats(state.stats, :hits)
    {:noreply, %{state | stats: new_stats}}
  end

  @impl true
  def handle_cast(:increment_miss, state) do
    new_stats = update_stats(state.stats, :misses)
    {:noreply, %{state | stats: new_stats}}
  end

  defp build_cache_key(prefix, key, opts) do
    tenant_id = Keyword.get(opts, :tenant_id, "global")
    parts = [prefix, key] |> Enum.reject(&(&1 == ""))
    Enum.join([tenant_id | parts], ":")
  end

  defp update_stats(stats, operation) do
    Map.update(stats, operation, 1, &(&1 + 1))
  end

  defp calculate_hit_rate(%{hits: hits, misses: misses}) when hits + misses > 0 do
    Float.round(hits / (hits + misses) * 100, 2)
  end

  defp calculate_hit_rate(_), do: 0.0
end