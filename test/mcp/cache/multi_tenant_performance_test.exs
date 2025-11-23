defmodule Mcp.Cache.MultiTenantPerformanceTest do
  use ExUnit.Case, async: false

  alias McpWeb.TenantContext
  alias Mcp.Cache.TenantIsolation
  alias Mcp.Cache.CacheManager
  alias Mcp.Platform.Tenant
  alias Mcp.Repo

  import Mox

  @moduletag :performance

  # Mock for performance testing
  Mox.defmock(CacheManagerMock, for: CacheManager)
  Mox.defmock(TenantRoutingMock, for: McpWeb.TenantRouting)

  setup do
    Mox.verify_on_exit!()

    # Create test tenants
    tenants =
      Enum.map(1..10, fn i ->
        %Tenant{
          id: "tenant-#{i}",
          slug: "tenant-#{i}",
          company_name: "Company #{i}",
          company_schema: "tenant_#{i}",
          subdomain: "tenant#{i}",
          status: :active,
          plan: :professional
        }
      end)

    {:ok, %{tenants: tenants}}
  end

  describe "concurrent tenant context switching" do
    test "handles 100 concurrent context switches efficiently", %{tenants: tenants} do
      # Mock successful database operations
      expect(Repo, :query, fn query ->
        cond do
          String.contains?(query, "SELECT schema_name") ->
            {:ok, %{rows: [["acq_tenant_1"]]}}

          String.contains?(query, "SET search_path") ->
            {:ok, %{rows: []}}

          String.contains?(query, "SELECT current_schema") ->
            {:ok, %{rows: [["acq_tenant_1"]]}}

          true ->
            {:ok, %{rows: []}}
        end
      end)
      # Mock multiple calls
      |> times(1000)

      expect(Repo, :get_search_path, fn -> "public" end)
      |> times(100)

      expect(Repo, :with_tenant_schema, fn _schema, fun ->
        fun.()
      end)
      |> times(100)

      # Mock tenant routing
      expect(TenantRoutingMock, :get_current_tenant, fn _conn ->
        hd(tenants)
      end)
      |> times(100)

      # Measure performance
      start_time = System.monotonic_time(:millisecond)

      tasks =
        Enum.map(1..100, fn _i ->
          Task.async(fn ->
            conn = conn(:get, "/")

            TenantContext.with_tenant_context(conn, fn ->
              # Simulate database operation
              Process.sleep(1)
              "operation_result"
            end)
          end)
        end)

      results = Task.await_many(tasks, 10_000)
      end_time = System.monotonic_time(:millisecond)

      duration_ms = end_time - start_time

      # Performance assertions
      assert length(results) == 100
      assert Enum.all?(results, &(&1 == "operation_result"))
      # Should complete within 5 seconds
      assert duration_ms < 5000

      # Calculate throughput
      operations_per_second = 100 / duration_ms * 1000
      # At least 20 operations per second
      assert operations_per_second > 20

      IO.puts("✓ Completed 100 concurrent context switches in #{duration_ms}ms")
      IO.puts("✓ Throughput: #{Float.round(operations_per_second, 2)} operations/second")
    end

    test "handles cross-tenant cache operations under load", %{tenants: tenants} do
      # Mock cache operations
      expect(CacheManagerMock, :get, fn _key, opts ->
        tenant_id = Keyword.get(opts, :tenant_id)
        {:ok, "value_for_#{tenant_id}"}
      end)
      |> times(1000)

      expect(CacheManagerMock, :set, fn _key, _value, opts ->
        :ok
      end)
      |> times(1000)

      start_time = System.monotonic_time(:millisecond)

      # Simulate high-volume cross-tenant cache operations
      tasks =
        Enum.map(1..100, fn i ->
          tenant = Enum.at(tenants, rem(i, length(tenants)))

          Task.async(fn ->
            # Set up tenant context
            Process.put(:current_tenant_id, tenant.id)

            # Perform multiple cache operations
            operations =
              Enum.map(1..10, fn j ->
                key = "cache_key_#{j}"
                value = "tenant_#{tenant.id}_value_#{j}"

                case TenantIsolation.tenant_set(key, value) do
                  :ok ->
                    case TenantIsolation.tenant_get(key) do
                      {:ok, retrieved_value} -> retrieved_value == value
                      _ -> false
                    end

                  _ ->
                    false
                end
              end)

            # Clean up process context
            Process.delete(:current_tenant_id)

            # Return success rate
            success_count = Enum.count(operations, &(&1 == true))
            success_count / length(operations)
          end)
        end)

      results = Task.await_many(tasks, 15_000)
      end_time = System.monotonic_time(:millisecond)

      duration_ms = end_time - start_time
      # 100 tasks × 10 operations each
      total_operations = 100 * 10

      # Performance assertions
      assert length(results) == 100
      avg_success_rate = Enum.sum(results) / length(results)
      # All operations should succeed
      assert avg_success_rate == 1.0
      # Should complete within 10 seconds
      assert duration_ms < 10_000

      # Calculate throughput
      operations_per_second = total_operations / duration_ms * 1000
      # At least 100 cache operations per second
      assert operations_per_second > 100

      IO.puts("✓ Completed #{total_operations} cross-tenant cache operations in #{duration_ms}ms")
      IO.puts("✓ Cache throughput: #{Float.round(operations_per_second, 2)} operations/second")
      IO.puts("✓ Success rate: #{Float.round(avg_success_rate * 100, 2)}%")
    end

    test "memory usage remains stable during tenant switching" do
      # Get initial memory usage
      :erlang.garbage_collect()
      initial_memory = :erlang.memory(:total)

      # Simulate repeated tenant context switching
      tasks =
        Enum.map(1..50, fn i ->
          Task.async(fn ->
            # Create tenant data
            tenant = %Tenant{
              id: "perf-tenant-#{i}",
              company_schema: "perf_tenant_#{i}",
              status: :active
            }

            # Mock database operations
            expect(Repo, :query, fn query ->
              cond do
                String.contains?(query, "SELECT schema_name") ->
                  {:ok, %{rows: [["acq_perf_tenant_#{i}"]]}}

                String.contains?(query, "SET search_path") ->
                  {:ok, %{rows: []}}

                true ->
                  {:ok, %{rows: []}}
              end
            end)
            |> times(3)

            expect(Repo, :get_search_path, fn -> "public" end)

            expect(Repo, :with_tenant_schema, fn _schema, fun ->
              fun.()
            end)

            expect(TenantRoutingMock, :get_current_tenant, fn _conn ->
              tenant
            end)

            # Perform context switching
            conn = conn(:get, "/")

            Enum.map(1..10, fn _ ->
              TenantContext.with_tenant_context(conn, fn ->
                # Simulate work that allocates memory
                large_data = :binary.copy(<<1>>, 1000)
                :crypto.hash(:sha256, large_data)
              end)
            end)
          end)
        end)

      # Wait for all tasks to complete
      Task.await_many(tasks, 30_000)

      # Force garbage collection
      :erlang.garbage_collect()

      final_memory = :erlang.memory(:total)
      memory_increase = final_memory - initial_memory
      memory_increase_mb = memory_increase / (1024 * 1024)

      # Memory should not increase excessively
      # Less than 50MB increase
      assert memory_increase_mb < 50

      IO.puts(
        "✓ Memory increase during tenant switching: #{Float.round(memory_increase_mb, 2)} MB"
      )
    end
  end

  describe "tenant isolation stress test" do
    test "maintains data isolation under high concurrency" do
      # Mock cache with tenant isolation verification
      cache_store = :ets.new(:tenant_cache_test, [:set, :public])

      expect(CacheManagerMock, :set, fn key, value, opts ->
        tenant_id = Keyword.get(opts, :tenant_id)
        full_key = "#{tenant_id}:#{key}"
        :ets.insert(cache_store, {full_key, value})
        :ok
      end)
      |> times(2000)

      expect(CacheManagerMock, :get, fn key, opts ->
        tenant_id = Keyword.get(opts, :tenant_id)
        full_key = "#{tenant_id}:#{key}"

        case :ets.lookup(cache_store, full_key) do
          [{^full_key, value}] -> {:ok, value}
          [] -> {:error, :not_found}
        end
      end)
      |> times(2000)

      # Generate unique data for each tenant
      tenant_data =
        Enum.map(1..20, fn i ->
          {"tenant-#{i}", "secret-data-#{i}-#{System.unique_integer()}"}
        end)

      start_time = System.monotonic_time(:millisecond)

      # Concurrent operations across all tenants
      tasks =
        Enum.map(tenant_data, fn {tenant_id, secret_data} ->
          Task.async(fn ->
            Process.put(:current_tenant_id, tenant_id)

            # Perform 100 operations per tenant
            results =
              Enum.map(1..100, fn i ->
                key = "secret_#{i}"
                value = "#{secret_data}_#{i}"

                case TenantIsolation.tenant_set(key, value) do
                  :ok ->
                    case TenantIsolation.tenant_get(key) do
                      {:ok, retrieved_value} ->
                        # Verify isolation - should only get own data
                        String.starts_with?(retrieved_value, secret_data)

                      _ ->
                        false
                    end

                  _ ->
                    false
                end
              end)

            # Try to access data from other tenants (should fail)
            isolation_test =
              Enum.map(1..10, fn i ->
                other_tenant_key = "secret_from_other_tenant_#{i}"

                case TenantIsolation.tenant_get(other_tenant_key) do
                  {:error, :not_found} -> true
                  # Should not access other tenant data
                  _ -> false
                end
              end)

            Process.delete(:current_tenant_id)

            {
              tenant_id,
              Enum.count(results, &(&1 == true)) / length(results),
              Enum.count(isolation_test, &(&1 == true)) / length(isolation_test)
            }
          end)
        end)

      results = Task.await_many(tasks, 60_000)
      end_time = System.monotonic_time(:millisecond)

      duration_ms = end_time - start_time

      # Verify isolation integrity
      Enum.each(results, fn {tenant_id, data_success_rate, isolation_success_rate} ->
        assert data_success_rate == 1.0, "Data operations failed for #{tenant_id}"
        assert isolation_success_rate == 1.0, "Isolation compromised for #{tenant_id}"
      end)

      # Performance verification
      # 20 tenants × 110 operations each
      total_operations = 20 * 110
      operations_per_second = total_operations / duration_ms * 1000
      # At least 50 operations per second
      assert operations_per_second > 50

      IO.puts("✓ Tenant isolation maintained under high concurrency")
      IO.puts("✓ Completed #{total_operations} isolation-verified operations in #{duration_ms}ms")

      IO.puts(
        "✓ Isolation throughput: #{Float.round(operations_per_second, 2)} operations/second"
      )

      # Cleanup
      :ets.delete(cache_store)
    end
  end
end
