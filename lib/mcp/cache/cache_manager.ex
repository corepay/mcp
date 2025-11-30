defmodule Mcp.Cache.CacheManager do
  @moduledoc """
  High-level cache management service with authentication support.

  Provides a simple key-value interface for caching with Redis backend.
  Handles authentication tokens, sessions, rate limiting, and query caching.
  Supports tenant isolation and comprehensive error handling.
  """

  use GenServer
  require Logger

  alias Mcp.Cache.RedisClient

  # Define behaviour for mocking
  @callback get(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  @callback set(String.t(), term(), keyword()) :: :ok | {:error, term()}
  @callback delete(String.t(), keyword()) :: :ok | {:error, term()}
  @callback exists?(String.t(), keyword()) :: boolean()
  @callback increment(String.t(), integer(), keyword()) :: {:ok, integer()} | {:error, term()}
  @callback setex(String.t(), integer(), term(), keyword()) :: :ok | {:error, term()}
  @callback clear_pattern(String.t(), keyword()) :: :ok | {:error, term()}
  @callback get_stats() :: {:ok, map()}
  @callback warm_cache(list(), keyword()) :: {:ok, list()} | {:error, term()}

  # Default TTL values for different cache types
  @default_ttls %{
    # 1 hour
    default: 3600,
    # 24 hours
    session: 86_400,
    # 30 minutes
    token: 1800,
    # 5 minutes
    rate_limit: 300,
    # 1 hour
    email_template: 3600,
    # 30 minutes
    tenant_info: 1800,
    # 24 hours
    security: 86_400
  }

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting CacheManager with Redis backend")

    # Initialize cache statistics
    state = %{
      stats: %{
        hits: 0,
        misses: 0,
        operations: 0,
        errors: 0
      },
      started_at: DateTime.utc_now()
    }

    {:ok, state}
  end

  @doc """
  Get a value from cache by key.

  ## Parameters
  - key: Cache key (string)
  - opts: Options list, including:
    - tenant_id: Tenant ID for isolation (default: "global")
    - type: Cache type for default TTL (default: :default)

  ## Returns
  {:ok, value} if found
  {:error, :not_found} if key doesn't exist
  {:error, reason} for other errors
  """
  @spec get(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def get(key, opts \\ []) do
    GenServer.call(__MODULE__, {:get, key, opts})
  end

  @doc """
  Set a value in cache with optional TTL.

  ## Parameters
  - key: Cache key (string)
  - value: Value to cache (any term)
  - opts: Options list, including:
    - ttl: Time to live in seconds (overrides type-based TTL)
    - tenant_id: Tenant ID for isolation (default: "global")
    - type: Cache type for default TTL (default: :default)

  ## Returns
  :ok on success
  {:error, reason} on failure
  """
  @spec set(String.t(), term(), keyword()) :: :ok | {:error, term()}
  def set(key, value, opts \\ []) do
    GenServer.call(__MODULE__, {:set, key, value, opts})
  end

  @doc """
  Delete a key from cache.

  ## Parameters
  - key: Cache key (string)
  - opts: Options list, including:
    - tenant_id: Tenant ID for isolation (default: "global")

  ## Returns
  :ok on success
  {:error, reason} on failure
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, term()}
  def delete(key, opts \\ []) do
    GenServer.call(__MODULE__, {:delete, key, opts})
  end

  @doc """
  Check if a key exists in cache.

  ## Parameters
  - key: Cache key (string)
  - opts: Options list, including:
    - tenant_id: Tenant ID for isolation (default: "global")

  ## Returns
  true if key exists, false otherwise
  """
  @spec exists?(String.t(), keyword()) :: boolean()
  def exists?(key, opts \\ []) do
    GenServer.call(__MODULE__, {:exists, key, opts})
  end

  @doc """
  Increment a counter value in cache.

  ## Parameters
  - key: Cache key (string)
  - amount: Amount to increment (default: 1)
  - opts: Options list, including:
    - tenant_id: Tenant ID for isolation (default: "global")

  ## Returns
  {:ok, new_value} on success
  {:error, reason} on failure
  """
  @spec increment(String.t(), integer(), keyword()) :: {:ok, integer()} | {:error, term()}
  def increment(key, amount \\ 1, opts \\ []) do
    GenServer.call(__MODULE__, {:increment, key, amount, opts})
  end

  @doc """
  Set a value with explicit TTL in seconds.

  ## Parameters
  - key: Cache key (string)
  - value: Value to cache (any term)
  - ttl: Time to live in seconds
  - opts: Options list, including:
    - tenant_id: Tenant ID for isolation (default: "global")

  ## Returns
  :ok on success
  {:error, reason} on failure
  """
  @spec setex(String.t(), integer(), term(), keyword()) :: :ok | {:error, term()}
  def setex(key, ttl, value, opts \\ []) do
    GenServer.call(__MODULE__, {:setex, key, ttl, value, opts})
  end

  @doc """
  Clear all keys matching a pattern.

  ## Parameters
  - pattern: Pattern to match (supports Redis wildcards)
  - opts: Options list, including:
    - tenant_id: Tenant ID for isolation (default: "global")

  ## Returns
  :ok on success
  {:error, reason} on failure
  """
  @spec clear_pattern(String.t(), keyword()) :: :ok | {:error, term()}
  def clear_pattern(pattern, opts \\ []) do
    GenServer.call(__MODULE__, {:clear_pattern, pattern, opts})
  end

  # Legacy methods for backward compatibility
  def cache_query_result(query_key, query_result, opts \\ []) do
    set(query_key, query_result, Keyword.put(opts, :type, :default))
  end

  def get_cached_query(query_key, opts \\ []) do
    get(query_key, opts)
  end

  def invalidate_cache_pattern(pattern, opts \\ []) do
    clear_pattern(pattern, opts)
  end

  def warm_cache(cache_items, opts \\ []) do
    results =
      Enum.map(cache_items, fn {key, value, item_opts} ->
        merged_opts = Keyword.merge(opts, item_opts)
        set(key, value, merged_opts)
      end)

    successful_warms = Enum.count(results, &(&1 == :ok))
    Logger.info("Cache warming completed: #{successful_warms}/#{length(cache_items)} items")
    {:ok, results}
  end

  @doc """
  Get cache statistics including hit rate and uptime.

  ## Returns
  {:ok, stats_map} with cache performance metrics
  """
  @spec get_stats() :: {:ok, map()}
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # GenServer handle implementations

  @impl true
  def handle_call({:get, key, opts}, _from, state) do
    redis_opts = build_redis_opts(opts)

    case RedisClient.get(key, redis_opts) do
      {:ok, result} ->
        # Update statistics
        new_state = increment_stat(state, :hits)
        Logger.debug("Cache hit for key: #{key}")
        {:reply, {:ok, result}, new_state}

      {:error, :not_found} ->
        # Update statistics
        new_state = increment_stat(state, :misses)
        Logger.debug("Cache miss for key: #{key}")
        {:reply, {:error, :not_found}, new_state}

      {:error, reason} ->
        # Update error statistics
        new_state = increment_stat(state, :errors)
        Logger.error("Cache get error for key #{key}: #{inspect(reason)}")
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call({:set, key, value, opts}, _from, state) do
    ttl = determine_ttl(opts)
    redis_opts = build_redis_opts(opts)

    result =
      if ttl do
        RedisClient.set_with_ttl(key, value, ttl, redis_opts)
      else
        RedisClient.set(key, value, redis_opts)
      end

    case result do
      :ok ->
        new_state = increment_stat(state, :operations)
        Logger.debug("Cache set successful for key: #{key}, ttl: #{ttl || "default"}")
        {:reply, :ok, new_state}

      {:error, reason} ->
        new_state = increment_stat(state, :errors)
        Logger.error("Cache set error for key #{key}: #{inspect(reason)}")
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call({:delete, key, opts}, _from, state) do
    redis_opts = build_redis_opts(opts)

    case RedisClient.delete(key, redis_opts) do
      :ok ->
        new_state = increment_stat(state, :operations)
        Logger.debug("Cache delete successful for key: #{key}")
        {:reply, :ok, new_state}

      {:error, reason} ->
        new_state = increment_stat(state, :errors)
        Logger.error("Cache delete error for key #{key}: #{inspect(reason)}")
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call({:exists, key, opts}, _from, state) do
    redis_opts = build_redis_opts(opts)

    case RedisClient.exists?(key, redis_opts) do
      exists when is_boolean(exists) ->
        new_state = increment_stat(state, :operations)
        {:reply, exists, new_state}

      {:error, reason} ->
        new_state = increment_stat(state, :errors)
        Logger.error("Cache exists error for key #{key}: #{inspect(reason)}")
        {:reply, false, new_state}
    end
  end

  @impl true
  def handle_call({:increment, key, amount, opts}, _from, state) do
    redis_opts = build_redis_opts(opts)

    case RedisClient.increment(key, amount, redis_opts) do
      {:ok, result} ->
        new_state = increment_stat(state, :operations)
        Logger.debug("Cache increment successful for key: #{key}, amount: #{amount}")
        {:reply, {:ok, result}, new_state}

      {:error, reason} ->
        new_state = increment_stat(state, :errors)
        Logger.error("Cache increment error for key #{key}: #{inspect(reason)}")
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call({:setex, key, ttl, value, opts}, _from, state) do
    redis_opts = build_redis_opts(opts)

    case RedisClient.set_with_ttl(key, value, ttl, redis_opts) do
      :ok ->
        new_state = increment_stat(state, :operations)
        Logger.debug("Cache setex successful for key: #{key}, ttl: #{ttl}")
        {:reply, :ok, new_state}

      {:error, reason} ->
        new_state = increment_stat(state, :errors)
        Logger.error("Cache setex error for key #{key}: #{inspect(reason)}")
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call({:clear_pattern, pattern, opts}, _from, state) do
    redis_opts = build_redis_opts(opts)

    case RedisClient.clear_pattern(pattern, redis_opts) do
      :ok ->
        new_state = increment_stat(state, :operations)
        Logger.info("Cache pattern cleared: #{pattern}")
        {:reply, :ok, new_state}

      {:error, reason} ->
        new_state = increment_stat(state, :errors)
        Logger.error("Cache pattern clear error for #{pattern}: #{inspect(reason)}")
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    uptime = DateTime.diff(DateTime.utc_now(), state.started_at)
    hit_rate = calculate_hit_rate(state.stats)

    stats = %{
      hits: state.stats.hits,
      misses: state.stats.misses,
      operations: state.stats.operations,
      errors: state.stats.errors,
      hit_rate: hit_rate,
      uptime_seconds: uptime,
      started_at: state.started_at
    }

    {:reply, {:ok, stats}, state}
  end

  # Legacy handle implementations for backward compatibility
  @impl true
  def handle_call({:cache_query, query_key, query_result, opts}, from, state) do
    handle_call({:set, query_key, query_result, opts}, from, state)
  end

  @impl true
  def handle_call({:get_cached_query, query_key, opts}, from, state) do
    handle_call({:get, query_key, opts}, from, state)
  end

  @impl true
  def handle_call({:invalidate_pattern, pattern, opts}, from, state) do
    handle_call({:clear_pattern, pattern, opts}, from, state)
  end

  # Legacy cast implementations for backward compatibility
  @impl true
  def handle_cast(:increment_hit, state) do
    {:noreply, increment_stat(state, :hits)}
  end

  @impl true
  def handle_cast(:increment_miss, state) do
    {:noreply, increment_stat(state, :misses)}
  end

  # Helper functions

  # Determine TTL based on cache type or explicit setting
  defp determine_ttl(opts) do
    cond do
      ttl = Keyword.get(opts, :ttl) ->
        ttl

      cache_type = Keyword.get(opts, :type, :default) ->
        Map.get(@default_ttls, cache_type, @default_ttls.default)

      true ->
        @default_ttls.default
    end
  end

  # Build Redis client options from cache manager options
  defp build_redis_opts(opts) do
    # Extract tenant_id for Redis client
    Keyword.take(opts, [:tenant_id])
  end

  # Increment a specific statistic counter
  defp increment_stat(state, stat_key) do
    new_stats = Map.update(state.stats, stat_key, 1, &(&1 + 1))
    %{state | stats: new_stats}
  end

  # Calculate cache hit rate as percentage
  defp calculate_hit_rate(%{hits: hits, misses: misses}) when hits + misses > 0 do
    Float.round(hits / (hits + misses) * 100, 2)
  end

  defp calculate_hit_rate(_), do: 0.0
end
