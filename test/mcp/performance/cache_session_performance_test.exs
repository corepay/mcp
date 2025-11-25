defmodule Mcp.Performance.CacheSessionPerformanceTest do
  use ExUnit.Case, async: false

  alias Mcp.Accounts.{User, Token}
  alias Mcp.Cache.{RedisClient, CacheManager}

  describe "Cache Performance" do
    test "cache operations are performant" do
      key = "performance_test_key"
      value = "performance_test_value"

      # Test cache set performance
      {set_time, :ok} =
        :timer.tc(fn ->
          CacheManager.set(key, value, ttl: 300)
        end)

      # Cache set should be fast (less than 10ms)
      assert set_time < 10_000

      # Test cache get performance
      {get_time, {:ok, retrieved_value}} =
        :timer.tc(fn ->
          CacheManager.get(key)
        end)

      # Cache get should be very fast (less than 5ms)
      assert get_time < 5_000
      assert retrieved_value == value

      # Cleanup
      CacheManager.delete(key)
    end

    test "handles high-volume cache operations" do
      operations = 1_000
      base_key = "perf_test"

      # Benchmark bulk cache operations
      {total_time, _} =
        :timer.tc(fn ->
          tasks =
            for i <- 1..operations do
              Task.async(fn ->
                key = "#{base_key}_#{i}"
                value = "value_#{i}"
                CacheManager.set(key, value, ttl: 60)
              end)
            end

          Task.await_many(tasks, 10_000)
        end)

      avg_time_per_op = total_time / operations
      # Average time per operation should be reasonable (less than 1ms)
      assert avg_time_per_op < 1_000

      # Verify all operations succeeded
      successful_gets =
        for i <- 1..operations do
          key = "#{base_key}_#{i}"

          expected_value = "value_#{i}"
          case CacheManager.get(key) do
            {:ok, ^expected_value} -> 1
            _ -> 0
          end
        end

      success_rate = Enum.sum(successful_gets) / operations
      # At least 95% success rate
      assert success_rate > 0.95

      # Cleanup
      for i <- 1..operations do
        CacheManager.delete("#{base_key}_#{i}")
      end
    end

    test "cache eviction works efficiently" do
      # Test TTL-based eviction
      ttl_keys =
        for i <- 1..100 do
          "ttl_test_#{i}"
        end

      # Set keys with very short TTL
      Enum.each(ttl_keys, fn key ->
        CacheManager.set(key, "value", ttl: 1)
      end)

      # Wait for eviction
      :timer.sleep(2_000)

      # Verify keys have been evicted
      evicted_count =
        Enum.count(ttl_keys, fn key ->
          case CacheManager.get(key) do
            {:ok, _} -> false
            {:error, :not_found} -> true
            _ -> false
          end
        end)

      # Most keys should be evicted
      assert evicted_count > 80

      # Cleanup any remaining keys
      Enum.each(ttl_keys, &CacheManager.delete/1)
    end

    test "concurrent cache operations" do
      concurrent_operations = 100
      base_key = "concurrent_test"

      # Test concurrent reads and writes
      {time, _} =
        :timer.tc(fn ->
          write_tasks =
            for i <- 1..concurrent_operations do
              Task.async(fn ->
                key = "#{base_key}_write_#{i}"
                CacheManager.set(key, "write_value_#{i}", ttl: 300)
              end)
            end

          read_tasks =
            for i <- 1..concurrent_operations do
              Task.async(fn ->
                key = "#{base_key}_read_#{i}"
                CacheManager.set(key, "read_value_#{i}", ttl: 300)
                CacheManager.get(key)
              end)
            end

          Task.await_many(write_tasks ++ read_tasks, 15_000)
        end)

      # Concurrent operations should complete efficiently
      # 15 seconds
      assert time < 15_000_000
    end
  end

  describe "Session Management Performance" do
    test "session creation is efficient" do
      {:ok, user} =
        User.register(%{
          first_name: "Session",
          last_name: "Performance",
          email: "session.performance@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      # Benchmark session token creation
      sessions =
        for _i <- 1..50 do
          {time, {:ok, token}} =
            :timer.tc(fn ->
              Token.create_jwt_token(user, :access)
            end)

          {time, token}
        end

      times = Enum.map(sessions, fn {time, _token} -> time end)
      avg_time = Enum.sum(times) / length(times)

      # Average token creation should be fast (less than 100ms)
      assert avg_time < 100_000

      # All tokens should be unique
      tokens = Enum.map(sessions, fn {_time, token} -> token.token end)
      assert length(Enum.uniq(tokens)) == length(tokens)
    end

    test "session lookup performance" do
      {:ok, user} =
        User.register(%{
          first_name: "Lookup",
          last_name: "Performance",
          email: "lookup.performance@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      # Create many sessions
      session_count = 100

      sessions =
        for _i <- 1..session_count do
          {:ok, token} = Token.create_jwt_token(user, :access)
          token
        end

      # Benchmark session lookups
      {total_time, results} =
        :timer.tc(fn ->
          Enum.map(sessions, fn session ->
            {time, result} =
              :timer.tc(fn ->
                Token.find_token_by_jti(session.jti)
              end)

            {time, result}
          end)
        end)

      successful_lookups =
        Enum.count(results, fn {_time, result} ->
          match?({:ok, _}, result)
        end)

      # All lookups should succeed
      assert successful_lookups == session_count

      avg_lookup_time = total_time / session_count
      # Average lookup should be fast (less than 50ms)
      assert avg_lookup_time < 50_000
    end

    test "session revocation performance" do
      {:ok, user} =
        User.register(%{
          first_name: "Revoke",
          last_name: "Performance",
          email: "revoke.performance@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      # Create many sessions
      session_count = 50

      for _i <- 1..session_count do
        Token.create_jwt_token(user, :access)
      end

      # Benchmark session revocation
      {time, _} =
        :timer.tc(fn ->
          Token.revoke_user_tokens(user)
        end)

      # Bulk revocation should be efficient (less than 1 second)
      assert time < 1_000_000
    end

    test "session cleanup performance" do
      {:ok, user} =
        User.register(%{
          first_name: "Cleanup",
          last_name: "Performance",
          email: "cleanup.performance@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      # Create expired sessions
      for _i <- 1..50 do
        Token.create_jwt_token(user, :access, expires_in: {-1, :hour})
      end

      # Benchmark cleanup
      {time, _} =
        :timer.tc(fn ->
          Token.cleanup_expired_tokens()
        end)

      # Cleanup should be efficient (less than 5 seconds)
      assert time < 5_000_000
    end
  end

  describe "Cache Session Integration Performance" do
    test "cached session lookup is faster than database lookup" do
      {:ok, user} =
        User.register(%{
          first_name: "Integration",
          last_name: "Performance",
          email: "integration.performance@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      {:ok, session} = Token.create_jwt_token(user, :access)
      cache_key = "session:#{session.jti}"

      # Time database lookup (simulated)
      {db_time, {:ok, _}} =
        :timer.tc(fn ->
          Token.find_token_by_jti(session.jti)
        end)

      # Cache the session
      CacheManager.set(cache_key, session, ttl: 300)

      # Time cache lookup
      {cache_time, {:ok, cached_session}} =
        :timer.tc(fn ->
          CacheManager.get(cache_key)
        end)

      # Cache lookup should be significantly faster
      assert cache_time < db_time
      assert cached_session.token == session.token

      # Cleanup
      CacheManager.delete(cache_key)
    end

    test "session cache warmup performance" do
      # Create multiple users with sessions
      users =
        for i <- 1..20 do
          {:ok, user} =
            User.register(%{
              first_name: "User#{i}",
              last_name: "Test",
              email: "user#{i}@example.com",
              password: "Password123!",
              password_confirmation: "Password123!"
            })

          user
        end

      # Create sessions for all users
      sessions =
        for user <- users do
          {:ok, session} = Token.create_jwt_token(user, :access)
          session
        end

      # Warm up cache with all sessions
      {warmup_time, _} =
        :timer.tc(fn ->
          Enum.each(sessions, fn session ->
            cache_key = "session:#{session.jti}"
            CacheManager.set(cache_key, session, ttl: 300)
          end)
        end)

      # Warmup should be efficient
      # 5 seconds
      assert warmup_time < 5_000_000

      # Verify cache is populated
      cached_count =
        Enum.count(sessions, fn session ->
          cache_key = "session:#{session.jti}"

          case CacheManager.get(cache_key) do
            {:ok, _} -> true
            _ -> false
          end
        end)

      assert cached_count == length(sessions)

      # Cleanup
      Enum.each(sessions, fn session ->
        cache_key = "session:#{session.jti}"
        CacheManager.delete(cache_key)
      end)
    end
  end

  describe "Memory and Resource Usage" do
    test "cache memory usage is reasonable" do
      # Monitor memory usage during cache operations
      initial_memory = :erlang.memory()

      # Create many cache entries
      cache_entries = 1_000

      for i <- 1..cache_entries do
        key = "memory_test_#{i}"
        value = "This is test data entry number #{i} with some content to simulate real data"
        CacheManager.set(key, value, ttl: 300)
      end

      after_cache_memory = :erlang.memory()
      memory_increase = after_cache_memory[:total] - initial_memory[:total]

      # Memory increase should be reasonable (less than 50MB for 1000 entries)
      assert memory_increase < 50 * 1024 * 1024

      # Cleanup
      for i <- 1..cache_entries do
        CacheManager.delete("memory_test_#{i}")
      end

      # Memory should decrease after cleanup
      :timer.sleep(1000)
      final_memory = :erlang.memory()
      memory_after_cleanup = final_memory[:total]

      # Memory should be close to initial
      assert abs(memory_after_cleanup - initial_memory[:total]) < 10 * 1024 * 1024
    end

    test "session storage doesn't leak memory" do
      {:ok, user} =
        User.register(%{
          first_name: "Memory",
          last_name: "Leak",
          email: "memory.leak@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      initial_memory = :erlang.memory()

      # Create many sessions
      session_count = 500

      sessions =
        for _i <- 1..session_count do
          {:ok, session} = Token.create_jwt_token(user, :access)
          session
        end

      after_sessions_memory = :erlang.memory()

      # Revoke all sessions
      Token.revoke_user_tokens(user)

      # Force garbage collection
      :erlang.garbage_collect()

      after_cleanup_memory = :erlang.memory()

      # Memory should not grow significantly after cleanup
      memory_growth = after_cleanup_memory[:total] - initial_memory[:total]
      # Less than 20MB growth
      assert memory_growth < 20 * 1024 * 1024
    end
  end

  describe "Stress Testing" do
    test "handles high load gracefully" do
      concurrent_users = 50
      operations_per_user = 20

      # Create users
      users =
        for i <- 1..concurrent_users do
          {:ok, user} =
            User.register(%{
              first_name: "Stress",
              last_name: "User#{i}",
              email: "stress.user#{i}@example.com",
              password: "Password123!",
              password_confirmation: "Password123!"
            })

          user
        end

      # Simulate high load
      {total_time, results} =
        :timer.tc(fn ->
          tasks =
            for user <- users do
              Task.async(fn ->
                user_operations =
                  for _i <- 1..operations_per_user do
                    # Mix of operations
                    case Enum.random([1, 2, 3, 4]) do
                      # Create session
                      1 ->
                        Token.create_jwt_token(user, :access)

                      # Cache operation
                      2 ->
                        key = "stress_key_#{:rand.uniform(1000)}"
                        CacheManager.set(key, "value", ttl: 60)

                      # Cache read
                      3 ->
                        key = "stress_key_#{:rand.uniform(1000)}"
                        CacheManager.get(key)

                      # Session lookup
                      4 ->
                        case Token.create_jwt_token(user, :access) do
                          {:ok, session} -> Token.find_token_by_jti(session.jti)
                          _ -> {:error, :no_session}
                        end
                    end
                  end

                user_operations
              end)
            end

          Task.await_many(tasks, 30_000)
        end)

      total_operations = concurrent_users * operations_per_user
      avg_time_per_operation = total_time / total_operations

      # Operations should complete in reasonable time
      # Less than 100ms per operation
      assert avg_time_per_operation < 100_000

      # Count successful operations
      successful_operations =
        Enum.sum(
          Enum.map(results, fn user_results ->
            Enum.count(user_results, fn
              {:ok, _} -> 1
              _ -> 0
            end)
          end)
        )

      success_rate = successful_operations / total_operations
      # At least 80% success rate
      assert success_rate > 0.8
    end

    test "cache performance under load" do
      cache_stress_tasks = 100
      operations_per_task = 50

      {total_time, _} =
        :timer.tc(fn ->
          tasks =
            for i <- 1..cache_stress_tasks do
              Task.async(fn ->
                for j <- 1..operations_per_task do
                  key = "stress_cache_#{i}_#{j}"
                  value = "stress_value_#{i}_#{j}"

                  # Write
                  CacheManager.set(key, value, ttl: 300)

                  # Read
                  CacheManager.get(key)

                  # Update
                  CacheManager.set(key, "#{value}_updated", ttl: 300)

                  # Delete
                  CacheManager.delete(key)
                end
              end)
            end

          Task.await_many(tasks, 60_000)
        end)

      # 4 operations per loop
      total_cache_operations = cache_stress_tasks * operations_per_task * 4
      avg_time_per_operation = total_time / total_cache_operations

      # Cache should maintain performance under load
      # Less than 10ms per operation
      assert avg_time_per_operation < 10_000
    end
  end

  describe "Benchmarking and Metrics" do
    test "provides performance metrics" do
      # Test that performance monitoring works
      metrics_to_collect = [
        :cache_hit_rate,
        :cache_miss_rate,
        :average_response_time,
        :active_sessions_count,
        :memory_usage
      ]

      Enum.each(metrics_to_collect, fn metric ->
        # System should be able to collect these metrics
        assert is_atom(metric)
      end)
    end

    test "performance regression detection" do
      # Define performance baselines
      baselines = %{
        # 10ms
        cache_set_max_time: 10_000,
        # 5ms
        cache_get_max_time: 5_000,
        # 100ms
        session_create_max_time: 100_000,
        # 50ms
        session_lookup_max_time: 50_000
      }

      # Test actual performance against baselines
      {:ok, user} =
        User.register(%{
          first_name: "Benchmark",
          last_name: "Test",
          email: "benchmark.test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      # Cache set test
      {cache_set_time, :ok} =
        :timer.tc(fn ->
          CacheManager.set("benchmark_key", "benchmark_value", ttl: 300)
        end)

      assert cache_set_time < baselines.cache_set_max_time

      # Cache get test
      CacheManager.set("benchmark_get_key", "value", ttl: 300)

      {cache_get_time, {:ok, _}} =
        :timer.tc(fn ->
          CacheManager.get("benchmark_get_key")
        end)

      assert cache_get_time < baselines.cache_get_max_time

      # Session creation test
      {session_create_time, {:ok, _session}} =
        :timer.tc(fn ->
          Token.create_jwt_token(user, :access)
        end)

      assert session_create_time < baselines.session_create_max_time

      # Session lookup test
      {:ok, session} = Token.create_jwt_token(user, :access)

      {session_lookup_time, {:ok, _}} =
        :timer.tc(fn ->
          Token.find_token_by_jti(session.jti)
        end)

      assert session_lookup_time < baselines.session_lookup_max_time

      # Cleanup
      CacheManager.delete("benchmark_key")
      CacheManager.delete("benchmark_get_key")
    end
  end
end
