defmodule Mcp.Cache.TenantIsolation do
  @moduledoc """
  Tenant-aware cache isolation helpers for multi-tenant applications.

  Provides automatic tenant prefixing and isolation for all cache operations
  to prevent cross-tenant data leakage and ensure proper data separation.
  """

  require Logger
  alias Mcp.Cache.CacheManager

  @doc """
  Get a value from tenant-isolated cache.

  Automatically uses the current tenant context or accepts an explicit tenant_id.
  """
  @spec tenant_get(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def tenant_get(key, opts \\ []) do
    tenant_id = resolve_tenant_id(opts)
    cache_opts = Keyword.put(opts, :tenant_id, tenant_id)

    CacheManager.get(key, cache_opts)
  end

  @doc """
  Set a value in tenant-isolated cache.

  Automatically uses the current tenant context or accepts an explicit tenant_id.
  """
  @spec tenant_set(String.t(), term(), keyword()) :: :ok | {:error, term()}
  def tenant_set(key, value, opts \\ []) do
    tenant_id = resolve_tenant_id(opts)
    cache_opts = Keyword.put(opts, :tenant_id, tenant_id)

    CacheManager.set(key, value, cache_opts)
  end

  @doc """
  Delete a key from tenant-isolated cache.
  """
  @spec tenant_delete(String.t(), keyword()) :: :ok | {:error, term()}
  def tenant_delete(key, opts \\ []) do
    tenant_id = resolve_tenant_id(opts)
    cache_opts = Keyword.put(opts, :tenant_id, tenant_id)

    CacheManager.delete(key, cache_opts)
  end

  @doc """
  Check if a key exists in tenant-isolated cache.
  """
  @spec tenant_exists?(String.t(), keyword()) :: boolean()
  def tenant_exists?(key, opts \\ []) do
    tenant_id = resolve_tenant_id(opts)
    cache_opts = Keyword.put(opts, :tenant_id, tenant_id)

    CacheManager.exists?(key, cache_opts)
  end

  @doc """
  Execute multiple cache operations within a specific tenant context.

  Useful for bulk operations that need to be isolated to a specific tenant.
  """
  defmacro with_tenant_cache(tenant_id_or_conn, do: block) do
    quote do
      tenant_id =
        resolve_tenant_id_from_input(unquote(tenant_id_or_conn))

      Process.put(:current_tenant_id, tenant_id)

      try do
        unquote(block)
      after
        Process.delete(:current_tenant_id)
      end
    end
  end

  @doc """
  Clear all cache data for a specific tenant.

  Useful for tenant data cleanup and migration operations.
  """
  @spec clear_tenant_cache(String.t() | nil) :: :ok | {:error, term()}
  def clear_tenant_cache(tenant_id \\ nil) do
    resolved_tenant_id = resolve_tenant_id(tenant_id: tenant_id)

    # Clear all patterns for this tenant
    patterns = [
      "tenant:#{resolved_tenant_id}:*",
      # Sessions are already tenant-prefixed in SessionStore
      "session:*",
      "user_sessions:*"
    ]

    results =
      Enum.map(patterns, fn pattern ->
        CacheManager.clear_pattern(pattern, tenant_id: resolved_tenant_id)
      end)

    # Return :ok if all operations succeeded, otherwise return first error
    case Enum.find(results, &(&1 != :ok)) do
      nil -> :ok
      error -> error
    end
  end

  @doc """
  Get cache statistics for a specific tenant.
  """
  @spec get_tenant_cache_stats(String.t() | nil) :: {:ok, map()}
  def get_tenant_cache_stats(tenant_id \\ nil) do
    resolved_tenant_id = resolve_tenant_id(tenant_id: tenant_id)

    # Get overall cache stats and then tenant-specific info
    case CacheManager.get_stats() do
      {:ok, stats} ->
        tenant_stats = %{
          tenant_id: resolved_tenant_id,
          cache_keys_count: count_tenant_cache_keys(resolved_tenant_id),
          total_size_bytes: estimate_tenant_cache_size(resolved_tenant_id)
        }

        {:ok, Map.merge(stats, tenant_stats)}

      error ->
        error
    end
  end

  @doc """
  Migrate cache data from one tenant to another.

  Used during tenant migration or data reorganization.
  """
  @spec migrate_tenant_cache(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def migrate_tenant_cache(source_tenant_id, target_tenant_id) do
    Logger.info("Starting cache migration from tenant #{source_tenant_id} to #{target_tenant_id}")

    # Get all keys for source tenant (excluding system keys)
    source_keys = get_tenant_keys(source_tenant_id)

    migration_results =
      Enum.map(source_keys, fn key ->
        case CacheManager.get(key, tenant_id: source_tenant_id) do
          {:ok, value} ->
            # Copy to target tenant
            case CacheManager.set(key, value, tenant_id: target_tenant_id) do
              :ok ->
                # Delete from source after successful copy
                CacheManager.delete(key, tenant_id: source_tenant_id)
                {:ok, key}

              error ->
                Logger.warning("Failed to migrate key #{key} to target tenant: #{inspect(error)}")
                {:error, key, error}
            end

          error ->
            Logger.warning("Failed to read key #{key} from source tenant: #{inspect(error)}")
            {:error, key, error}
        end
      end)

    successful_migrations = Enum.count(migration_results, &match?({:ok, _}, &1))
    failed_migrations = Enum.count(migration_results, &match?({:error, _, _}, &1))

    Logger.info(
      "Cache migration completed: #{successful_migrations} successful, #{failed_migrations} failed"
    )

    if failed_migrations == 0 do
      {:ok, %{migrated_keys: successful_migrations, failed_keys: 0}}
    else
      {:error, %{migrated_keys: successful_migrations, failed_keys: failed_migrations}}
    end
  end

  @doc """
  Warm up cache with essential tenant data.

  Pre-populates cache with frequently accessed tenant-specific data.
  """
  @spec warm_tenant_cache(String.t(), map()) :: :ok | {:error, term()}
  def warm_tenant_cache(tenant_id, cache_items \\ %{}) do
    default_items = %{
      "tenant:config" => %{
        tenant_id: tenant_id,
        cache_warmed_at: DateTime.utc_now(),
        version: "1.0.0"
      },
      "tenant:features" => %{
        multi_tenant: true,
        cache_isolation: true,
        database_isolation: true
      }
    }

    items_to_warm = Map.merge(default_items, cache_items)

    cache_ops =
      Enum.map(items_to_warm, fn {key, value} ->
        {key, value, [tenant_id: tenant_id, type: :tenant_info]}
      end)

    case CacheManager.warm_cache(cache_ops, tenant_id: tenant_id) do
      {:ok, results} ->
        successful_warms = Enum.count(results, &(&1 == :ok))

        Logger.info(
          "Tenant cache warming completed for #{tenant_id}: #{successful_warms}/#{length(items_to_warm)} items"
        )

        :ok

      error ->
        Logger.error("Failed to warm tenant cache for #{tenant_id}: #{inspect(error)}")
        error
    end
  end

  # Private helper functions

  defp resolve_tenant_id(opts) do
    case Keyword.get(opts, :tenant_id) do
      nil ->
        # Try to get from process dictionary (set by tenant context)
        case Process.get(:current_tenant_id) do
          nil -> "global"
          tenant_id -> tenant_id
        end

      tenant_id when is_binary(tenant_id) ->
        tenant_id

      other ->
        Logger.warning("Invalid tenant_id type: #{inspect(other)}, using 'global'")
        "global"
    end
  end

  def resolve_tenant_id_from_input(input) do
    case input do
      nil -> "global"
      tenant_id when is_binary(tenant_id) -> tenant_id
      conn when is_map(conn) -> resolve_tenant_id_from_conn(conn)
      _ -> "global"
    end
  end

  defp resolve_tenant_id_from_conn(conn) do
    case Map.get(conn.assigns, :tenant_id) do
      nil -> "global"
      tenant_id -> tenant_id
    end
  end

  defp count_tenant_cache_keys(tenant_id) do
    # This is an approximation - in a real implementation you'd use Redis SCAN
    # with pattern matching to count keys without loading them all
    pattern = "tenant:#{tenant_id}:*"

    case CacheManager.get(pattern, tenant_id: tenant_id) do
      # Placeholder - actual implementation would use Redis SCAN
      {:ok, _} -> 1
      {:error, :not_found} -> 0
      _ -> 0
    end
  end

  defp estimate_tenant_cache_size(tenant_id) do
    # Estimate size based on key count and average value size
    key_count = count_tenant_cache_keys(tenant_id)
    # Assume 1KB average per item
    key_count * 1024
  end

  defp get_tenant_keys(_tenant_id) do
    # In a real implementation, you'd use Redis SCAN to get all keys for a tenant
    # This is a simplified version that returns common patterns
    [
      "tenant:config",
      "tenant:features",
      "tenant:settings",
      "tenant:metadata"
    ]
  end
end
