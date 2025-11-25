defmodule Mcp.Cache.TenantIsolationTest do
  use ExUnit.Case, async: true

  alias Mcp.Cache.TenantIsolation
  alias Mcp.Cache.CacheManager

  import Mox

  # Mock CacheManager
  Mox.defmock(CacheManagerMock, for: CacheManager)

  setup do
    Mox.verify_on_exit!()

    # Set up process dictionary for tenant context
    on_exit(fn ->
      Process.delete(:current_tenant_id)
    end)

    :ok
  end

  describe "tenant_get/2" do
    test "gets value with explicit tenant_id" do
      expect(CacheManagerMock, :get, fn "test_key", [tenant_id: "tenant-123"] ->
        {:ok, "test_value"}
      end)

      assert {:ok, "test_value"} = TenantIsolation.tenant_get("test_key", tenant_id: "tenant-123")
    end

    test "gets value using process tenant context" do
      Process.put(:current_tenant_id, "process-tenant")

      expect(CacheManagerMock, :get, fn "test_key", [tenant_id: "process-tenant"] ->
        {:ok, "test_value"}
      end)

      assert {:ok, "test_value"} = TenantIsolation.tenant_get("test_key")
    end

    test "gets value with global fallback when no tenant context" do
      expect(CacheManagerMock, :get, fn "test_key", [tenant_id: "global"] ->
        {:ok, "test_value"}
      end)

      assert {:ok, "test_value"} = TenantIsolation.tenant_get("test_key")
    end
  end

  describe "tenant_set/3" do
    test "sets value with explicit tenant_id" do
      expect(CacheManagerMock, :set, fn "test_key",
                                        "test_value",
                                        [tenant_id: "tenant-123", type: :default] ->
        :ok
      end)

      assert :ok = TenantIsolation.tenant_set("test_key", "test_value", tenant_id: "tenant-123")
    end

    test "sets value with additional options" do
      expect(CacheManagerMock, :set, fn "test_key",
                                        "test_value",
                                        [tenant_id: "tenant-123", ttl: 3600, type: :session] ->
        :ok
      end)

      assert :ok =
               TenantIsolation.tenant_set("test_key", "test_value",
                 tenant_id: "tenant-123",
                 ttl: 3600,
                 type: :session
               )
    end
  end

  describe "tenant_delete/2" do
    test "deletes key with tenant isolation" do
      expect(CacheManagerMock, :delete, fn "test_key", [tenant_id: "tenant-123"] ->
        :ok
      end)

      assert :ok = TenantIsolation.tenant_delete("test_key", tenant_id: "tenant-123")
    end
  end

  describe "tenant_exists?/2" do
    test "checks if key exists with tenant isolation" do
      expect(CacheManagerMock, :exists?, fn "test_key", [tenant_id: "tenant-123"] ->
        true
      end)

      assert TenantIsolation.tenant_exists?("test_key", tenant_id: "tenant-123") == true
    end

    test "returns false when key doesn't exist" do
      expect(CacheManagerMock, :exists?, fn "test_key", [tenant_id: "tenant-123"] ->
        false
      end)

      assert TenantIsolation.tenant_exists?("test_key", tenant_id: "tenant-123") == false
    end
  end

  describe "with_tenant_cache/2" do
    test "sets tenant context for block execution" do
      expect(CacheManagerMock, :get, fn "test_key", [tenant_id: "test-tenant"] ->
        {:ok, "test_value"}
      end)

      result =
        TenantIsolation.with_tenant_cache "test-tenant" do
          assert Process.get(:current_tenant_id) == "test-tenant"
          TenantIsolation.tenant_get("test_key")
        end

      assert {:ok, "test_value"} = result
      assert Process.get(:current_tenant_id) == nil
    end

    test "cleans up tenant context even on error" do
      expect(CacheManagerMock, :get, fn "test_key", [tenant_id: "test-tenant"] ->
        {:error, :not_found}
      end)

      try do
        TenantIsolation.with_tenant_cache "test-tenant" do
          assert Process.get(:current_tenant_id) == "test-tenant"
          TenantIsolation.tenant_get("test_key")
          raise "test error"
        end
      rescue
        RuntimeError -> :ok
      end

      assert Process.get(:current_tenant_id) == nil
    end
  end

  describe "clear_tenant_cache/1" do
    test "clears all cache patterns for tenant" do
      expect(CacheManagerMock, :clear_pattern, fn "tenant:test-tenant:*",
                                                  [tenant_id: "test-tenant"] ->
        :ok
      end)

      expect(CacheManagerMock, :clear_pattern, fn "session:*", [tenant_id: "test-tenant"] ->
        :ok
      end)

      expect(CacheManagerMock, :clear_pattern, fn "user_sessions:*", [tenant_id: "test-tenant"] ->
        :ok
      end)

      assert :ok = TenantIsolation.clear_tenant_cache("test-tenant")
    end

    test "handles partial failures gracefully" do
      expect(CacheManagerMock, :clear_pattern, fn "tenant:test-tenant:*",
                                                  [tenant_id: "test-tenant"] ->
        :ok
      end)

      expect(CacheManagerMock, :clear_pattern, fn "session:*", [tenant_id: "test-tenant"] ->
        {:error, :redis_connection_failed}
      end)

      expect(CacheManagerMock, :clear_pattern, fn "user_sessions:*", [tenant_id: "test-tenant"] ->
        :ok
      end)

      assert {:error, :redis_connection_failed} =
               TenantIsolation.clear_tenant_cache("test-tenant")
    end
  end

  describe "get_tenant_cache_stats/1" do
    test "returns enhanced stats with tenant information" do
      expect(CacheManagerMock, :get_stats, fn ->
        {:ok, %{hits: 100, misses: 20, operations: 120, errors: 0}}
      end)

      # Mock the internal count function (simplified)
      expect(CacheManagerMock, :get, fn "tenant:test-tenant:*", [tenant_id: "test-tenant"] ->
        {:ok, "mock_key_count"}
      end)

      assert {:ok, stats} = TenantIsolation.get_tenant_cache_stats("test-tenant")
      assert stats.hits == 100
      assert stats.misses == 20
      assert stats.tenant_id == "test-tenant"
    end
  end

  describe "migrate_tenant_cache/2" do
    test "migrates cache from source to target tenant" do
      # Mock source tenant keys and values
      expect(CacheManagerMock, :get, fn "config", [tenant_id: "source-tenant"] ->
        {:ok, %{app_config: "value"}}
      end)

      expect(CacheManagerMock, :set, fn "config",
                                        %{app_config: "value"},
                                        [tenant_id: "target-tenant"] ->
        :ok
      end)

      expect(CacheManagerMock, :delete, fn "config", [tenant_id: "source-tenant"] ->
        :ok
      end)

      expect(CacheManagerMock, :get, fn "features", [tenant_id: "source-tenant"] ->
        {:ok, %{feature_flag: true}}
      end)

      expect(CacheManagerMock, :set, fn "features",
                                        %{feature_flag: true},
                                        [tenant_id: "target-tenant"] ->
        :ok
      end)

      expect(CacheManagerMock, :delete, fn "features", [tenant_id: "source-tenant"] ->
        :ok
      end)

      result = TenantIsolation.migrate_tenant_cache("source-tenant", "target-tenant")

      assert {:ok, %{migrated_keys: 2, failed_keys: 0}} = result
    end

    test "handles migration failures gracefully" do
      expect(CacheManagerMock, :get, fn "config", [tenant_id: "source-tenant"] ->
        {:error, :not_found}
      end)

      result = TenantIsolation.migrate_tenant_cache("source-tenant", "target-tenant")

      assert {:ok, %{migrated_keys: 0, failed_keys: 2}} = result
    end
  end

  describe "warm_tenant_cache/2" do
    test "warms cache with default and custom items" do
      default_items = %{
        "tenant:config" => %{tenant_id: "test-tenant", cache_warmed_at: "timestamp", version: "1.0.0"},
        "tenant:features" => %{
          multi_tenant: true,
          cache_isolation: true,
          database_isolation: true
        }
      }

      custom_items = %{
        "custom_data" => %{custom: "value"}
      }

      expect(CacheManagerMock, :warm_cache, fn cache_ops, [tenant_id: "test-tenant"] ->
        assert length(cache_ops) == 3
        :ok
      end)

      assert :ok = TenantIsolation.warm_tenant_cache("test-tenant", custom_items)
    end

    test "handles cache warming failures" do
      expect(CacheManagerMock, :warm_cache, fn cache_ops, [tenant_id: "test-tenant"] ->
        [{:ok, "config"}, {:error, "features"}]
      end)

      assert :ok = TenantIsolation.warm_tenant_cache("test-tenant")
    end
  end

  describe "resolve_tenant_id_from_input/1" do
    test "returns nil for nil input" do
      assert TenantIsolation.resolve_tenant_id_from_input(nil) == "global"
    end

    test "returns string input as-is" do
      assert TenantIsolation.resolve_tenant_id_from_input("tenant-123") == "tenant-123"
    end

    test "extracts tenant_id from connection assigns" do
      conn = %Plug.Conn{assigns: %{tenant_id: "conn-tenant"}}
      assert TenantIsolation.resolve_tenant_id_from_input(conn) == "conn-tenant"
    end

    test "falls back to global for connection without tenant_id" do
      conn = %Plug.Conn{assigns: %{}}
      assert TenantIsolation.resolve_tenant_id_from_input(conn) == "global"
    end

    test "handles other input types" do
      assert TenantIsolation.resolve_tenant_id_from_input(123) == "global"
      assert TenantIsolation.resolve_tenant_id_from_input(%{id: "test"}) == "global"
    end
  end
end
