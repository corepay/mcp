defmodule Mcp.Performance.LoginPerformanceTest do
  # Not async due to shared state
  use ExUnit.Case, async: false
  @moduletag timeout: 120_000

  import Phoenix.ConnTest

  alias Mcp.Accounts.{Auth, User}
  alias Mcp.Cache.SessionStore

  alias Mcp.Performance.LoginPerformanceTest.Statistics

  @endpoint McpWeb.Endpoint

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Mcp.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Mcp.Repo, {:shared, self()})
    # Clean up sessions before each test
    SessionStore.flush_all()
    {:ok, conn: build_conn()}
  end

  # ...

  describe "Login Page Load Performance" do
    test "loads login page within acceptable time limits", %{conn: conn} do
      # Measure initial load time
      {time, conn} =
        :timer.tc(fn ->
          get(conn, "/admin/sign-in")
        end)

      assert html_response(conn, 200)

      # Should load within 200ms
      assert time < 200_000, "Login page took #{time}μs, expected < 200ms"
    end

    test "handles concurrent login page loads", %{conn: _conn} do
      num_requests = 10
      num_users = 5

      # Create test users
      users =
        for i <- 1..num_users do
          {:ok, user} =
            create_test_user(%{
              email: "perf_test_#{i}@example.com"
            })

          user
        end

      # Simulate concurrent page loads
      tasks =
        for i <- 1..num_requests do
          Task.async(fn ->
            _user = Enum.at(users, rem(i - 1, num_users))
            conn = build_conn()

            {time, conn} =
              :timer.tc(fn ->
                get(conn, "/admin/sign-in")
              end)

            {time, conn, i}
          end)
        end

      results = Task.await_many(tasks, 10_000)

      # All requests should complete
      assert length(results) == num_requests

      # Check average response time
      times = Enum.map(results, fn {time, _result, _i} -> time end)
      avg_time = Enum.sum(times) / length(times)

      # Average should be under 100ms for concurrent requests
      assert avg_time < 100_000, "Average load time: #{avg_time}μs, expected < 100ms"

      # All should be successful
      successes =
        Enum.count(results, fn {_time, conn, _i} ->
          conn.status == 200
        end)

      assert successes == num_requests
    end
  end

  describe "Authentication Performance" do
    test "authenticates user within acceptable time", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Measure authentication time
      {time, {:ok, session}} =
        :timer.tc(fn ->
          {:ok, user} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")
          Auth.create_user_session(user, "127.0.0.1")
        end)

      # Should authenticate within 1s (hashing is slow)
      assert time < 1_000_000, "Authentication took #{time}μs, expected < 1s"
      assert session.access_token != nil
    end

    test "handles concurrent authentication requests efficiently", %{conn: _conn} do
      num_requests = 20
      num_users = 5

      # Create test users
      users =
        for i <- 1..num_users do
          {:ok, user} =
            create_test_user(%{
              email: "concurrent_test_#{i}@example.com"
            })

          user
        end

      # Simulate concurrent authentication attempts
      tasks =
        for i <- 1..num_requests do
          Task.async(fn ->
            user = Enum.at(users, rem(i - 1, num_users))

            {time, result} =
              :timer.tc(fn ->
                {:ok, user} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")
                Auth.create_user_session(user, "127.0.0.1")
              end)

            {time, result, i}
          end)
        end

      results = Task.await_many(tasks, 15_000)

      # All requests should complete
      assert length(results) == num_requests

      # Check performance metrics
      times = Enum.map(results, fn {time, _result, _i} -> time end)
      avg_time = Enum.sum(times) / length(times)
      max_time = Enum.max(times)

      # Average should be under 3s for concurrent auth
      assert avg_time < 3_000_000, "Average auth time: #{avg_time}μs, expected < 3s"
      # No request should take more than 5s
      assert max_time < 5_000_000, "Max auth time: #{max_time}μs, expected < 5s"

      # Check success rate
      successes = Enum.count(results, fn {_time, {:ok, _session}, _i} -> true end)
      assert successes == num_requests, "Success rate: #{successes}/#{num_requests}"
    end

    test "maintains performance with many failed login attempts", %{conn: _conn} do
      {:ok, user} = create_test_user()

      num_attempts = 10

      # Measure failed authentication attempts
      times =
        for i <- 1..num_attempts do
          {time, _result} =
            :timer.tc(fn ->
              Auth.authenticate(user.email, "wrong_password_#{i}", "127.0.0.1")
            end)

          time
        end

      avg_time = Enum.sum(times) / length(times)
      max_time = Enum.max(times)

      # Failed attempts should still be fast
      assert avg_time < 500_000, "Average failed auth time: #{avg_time}μs, expected < 500ms"
      assert max_time < 1_000_000, "Max failed auth time: #{max_time}μs, expected < 1s"
    end
  end

  describe "Session Management Performance" do
    test "creates and verifies sessions efficiently", %{conn: _conn} do
      {:ok, user} = create_test_user()
      num_sessions = 10

      # Create multiple sessions
      {creation_time, sessions} =
        :timer.tc(fn ->
          for i <- 1..num_sessions do
            {:ok, user} =
              Auth.authenticate(
                user.email,
                "Password123!",
                "127.0.0.#{i}"
              )

            {:ok, session} = Auth.create_user_session(user, "127.0.0.#{i}")
            session
          end
        end)

      # Verify all sessions
      {verification_time, verification_results} =
        :timer.tc(fn ->
          for session <- sessions do
            Auth.verify_jwt_access_token(session.access_token)
          end
        end)

      # Check performance
      avg_creation_time = creation_time / num_sessions
      avg_verification_time = verification_time / num_sessions

      assert avg_creation_time < 1_000_000, "Avg session creation: #{avg_creation_time}μs"

      assert avg_verification_time < 50_000,
             "Avg session verification: #{avg_verification_time}μs"

      # All verifications should succeed
      successes = Enum.count(verification_results, fn {:ok, _} -> true end)
      assert successes == num_sessions
    end

    test "revokes sessions efficiently", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Create multiple sessions
      sessions =
        for i <- 1..5 do
          {:ok, user} =
            Auth.authenticate(
              user.email,
              "Password123!",
              "127.0.0.#{i}"
            )

          {:ok, session} = Auth.create_user_session(user, "127.0.0.#{i}")
          session
        end

      # Measure session revocation time
      {time, _result} =
        :timer.tc(fn ->
          Auth.revoke_user_sessions(user.id)
        end)

      # Revocation should be fast
      assert time < 100_000, "Session revocation took #{time}μs, expected < 100ms"

      # Verify all sessions are revoked
      verification_results =
        for session <- sessions do
          Auth.verify_session(session.access_token)
        end

      failures = Enum.count(verification_results, fn {:error, _} -> true end)
      assert failures == length(sessions), "Expected all sessions to be revoked"
    end

    test "refreshes tokens efficiently", %{conn: _conn} do
      {:ok, user} = create_test_user()
      num_refreshes = 10

      # Create initial session
      {:ok, user} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")
      {:ok, session} = Auth.create_user_session(user, "127.0.0.1")

      # Measure token refresh performance
      times =
        for _i <- 1..num_refreshes do
          {time, _result} =
            :timer.tc(fn ->
              Auth.refresh_jwt_session(session.refresh_token)
            end)

          time
        end

      avg_time = Enum.sum(times) / length(times)
      max_time = Enum.max(times)

      # Token refresh should be efficient
      assert avg_time < 100_000, "Avg refresh time: #{avg_time}μs, expected < 100ms"
      assert max_time < 200_000, "Max refresh time: #{max_time}μs, expected < 200ms"
    end
  end

  describe "Memory Usage Performance" do
    test "doesn't leak memory during authentication cycles", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Measure initial memory
      :erlang.garbage_collect()
      initial_memory = :erlang.memory()

      # Perform many authentication cycles
      for i <- 1..100 do
        {:ok, user} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")
        {:ok, session} = Auth.create_user_session(user, "127.0.0.1")
        Auth.verify_jwt_access_token(session.access_token)
        Auth.revoke_jwt_session(session.session_id)

        # Force garbage collection periodically
        if rem(i, 10) == 0 do
          :erlang.garbage_collect()
        end
      end

      # Final garbage collection and memory measurement
      :erlang.garbage_collect()
      final_memory = :erlang.memory()

      # Check memory growth (should be minimal)
      memory_growth = final_memory[:total] - initial_memory[:total]
      memory_growth_mb = memory_growth / (1024 * 1024)

      # Memory growth should be less than 10MB
      assert memory_growth_mb < 10, "Memory grew by #{memory_growth_mb}MB, expected < 10MB"
    end

    test "efficiently manages session storage", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Create many sessions
      num_sessions = 50

      sessions =
        for i <- 1..num_sessions do
          {:ok, user} =
            Auth.authenticate(
              user.email,
              "Password123!",
              "127.0.0.#{rem(i, 255)}"
            )

          {:ok, session} = Auth.create_user_session(user, "127.0.0.#{rem(i, 255)}")
          session
        end

      # Measure memory usage with many sessions
      :erlang.garbage_collect()
      memory_with_sessions = :erlang.memory()

      # Revoke half the sessions
      half_count = div(num_sessions, 2)
      sessions_to_revoke = Enum.take(sessions, half_count)

      Enum.each(sessions_to_revoke, fn session ->
        Auth.revoke_jwt_session(session.session_id)
      end)

      # Force garbage collection
      :erlang.garbage_collect()
      memory_after_revoke = :erlang.memory()

      # Memory should be released after session revocation
      memory_diff = memory_with_sessions[:total] - memory_after_revoke[:total]
      memory_diff_mb = memory_diff / (1024 * 1024)

      # Should see memory reduction
      assert memory_diff_mb > 0, "Expected memory reduction after session revocation"
      assert memory_diff_mb < 5, "Memory reduction of #{memory_diff_mb}MB seems reasonable"
    end
  end

  describe "Database Performance" do
    test "efficient database queries during authentication", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # This test would require database query instrumentation
      # For now, we measure overall authentication time
      num_attempts = 20

      times =
        for _i <- 1..num_attempts do
          {time, _result} =
            :timer.tc(fn ->
              {:ok, user} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")
              Auth.create_user_session(user, "127.0.0.1")
            end)

          time
        end

      avg_time = Enum.sum(times) / length(times)
      max_time = Enum.max(times)

      # Database operations should be efficient
      assert avg_time < 1_000_000, "Avg auth time: #{avg_time}μs, expected < 1s"
      assert max_time < 2_000_000, "Max auth time: #{max_time}μs, expected < 2s"

      # Low variance indicates consistent performance
      variance = Statistics.variance(times)
      assert variance < 1_000_000_000, "High variance in auth times: #{variance}"
    end

    test "handles database connection pooling under load", %{conn: _conn} do
      num_users = 10
      num_requests_per_user = 5

      # Create users
      users =
        for i <- 1..num_users do
          {:ok, user} =
            create_test_user(%{
              email: "db_perf_test_#{i}@example.com"
            })

          user
        end

      # Generate concurrent requests
      tasks =
        for i <- 1..(num_users * num_requests_per_user) do
          Task.async(fn ->
            user = Enum.at(users, rem(i - 1, num_users))

            {time, result} =
              :timer.tc(fn ->
                {:ok, user} = Auth.authenticate(user.email, "Password123!", "127.0.0.#{i}")
                Auth.create_user_session(user, "127.0.0.#{i}")
              end)

            {time, result}
          end)
        end

      results = Task.await_many(tasks, 30_000)

      # All should complete without database connection issues
      assert length(results) == num_users * num_requests_per_user

      # Check for database-related errors
      db_errors =
        Enum.count(results, fn
          {_time, {:error, reason}} ->
            String.contains?(inspect(reason), "database") or
              String.contains?(inspect(reason), "connection") or
              String.contains?(inspect(reason), "timeout")

          {_time, {:ok, _}} ->
            false
        end)

      assert db_errors == 0, "Found #{db_errors} database-related errors"

      # Performance should remain acceptable under load
      times = Enum.map(results, fn {time, _result} -> time end)
      avg_time = Enum.sum(times) / length(times)
      assert avg_time < 3_000_000, "High load avg time: #{avg_time}μs, expected < 3s"
    end
  end

  describe "Load Testing" do
    test "handles sustained load over time", %{conn: _conn} do
      {:ok, user} = create_test_user()
      duration_seconds = 2
      # ms between requests
      request_interval = 100

      start_time = :erlang.monotonic_time(:millisecond)
      end_time = start_time + duration_seconds * 1000

      results =
        Stream.iterate(1, &(&1 + 1))
        |> Stream.take_while(fn _i ->
          :erlang.monotonic_time(:millisecond) < end_time
        end)
        |> Enum.map(fn i ->
          :timer.sleep(request_interval)

          {time, result} =
            :timer.tc(fn ->
              Auth.authenticate(user.email, "Password123!", "127.0.0.1")
            end)

          {i, time, result}
        end)

      total_requests = length(results)
      successful_requests = Enum.count(results, fn {_i, _time, {:ok, _}} -> true end)

      # Calculate throughput (requests per second)
      actual_duration = :erlang.monotonic_time(:millisecond) - start_time
      throughput = total_requests / (actual_duration / 1000)

      # Should handle sustained load
      assert throughput > 2, "Throughput: #{throughput} req/s, expected > 2 req/s"

      assert successful_requests / total_requests > 0.95,
             "Success rate: #{successful_requests}/#{total_requests}"

      # Performance should not degrade over time
      times = Enum.map(results, fn {_i, time, _result} -> time end)
      avg_time = Enum.sum(times) / length(times)
      assert avg_time < 3_000_000, "Sustained load avg time: #{avg_time}μs, expected < 3s"
    end

    test "handles burst load efficiently", %{conn: _conn} do
      num_users = 20
      burst_size = 10

      # Create users
      users =
        for i <- 1..num_users do
          {:ok, user} =
            create_test_user(%{
              email: "burst_test_#{i}@example.com"
            })

          user
        end

      # Generate burst of concurrent requests
      tasks =
        for i <- 1..burst_size do
          Task.async(fn ->
            user = Enum.at(users, rem(i - 1, num_users))

            # Make multiple requests per task
            results =
              for j <- 1..5 do
                {time, result} =
                  :timer.tc(fn ->
                    {:ok, user} =
                      Auth.authenticate(user.email, "Password123!", "127.0.#{i}.#{j}")

                    Auth.create_user_session(user, "127.0.#{i}.#{j}")
                  end)

                {time, result}
              end

            results
          end)
        end

      # Wait for all burst requests to complete
      all_results = Task.await_many(tasks, 20_000)
      total_results = List.flatten(all_results)

      # All burst requests should complete
      assert length(total_results) == burst_size * 5

      # Check burst performance
      times = Enum.map(total_results, fn {time, _result} -> time end)
      avg_time = Enum.sum(times) / length(times)
      max_time = Enum.max(times)

      # Burst performance should be acceptable
      assert avg_time < 3_000_000, "Burst avg time: #{avg_time}μs, expected < 3s"
      assert max_time < 5_000_000, "Burst max time: #{max_time}μs, expected < 5s"

      # High success rate even under burst
      successes = Enum.count(total_results, fn {_time, {:ok, _}} -> true end)
      success_rate = successes / length(total_results)
      assert success_rate > 0.90, "Burst success rate: #{success_rate}"
    end
  end

  describe "Stress Testing" do
    test "recovers from resource exhaustion", %{conn: _conn} do
      # This test simulates resource exhaustion scenarios
      # In a real environment, this would test memory, CPU, and database limits

      {:ok, user} = create_test_user()

      # Generate high load
      high_load_tasks =
        for i <- 1..100 do
          Task.async(fn ->
            try do
              {time, result} =
                :timer.tc(fn ->
                  {:ok, user} =
                    Auth.authenticate(user.email, "Password123!", "127.0.0.#{rem(i, 255)}")

                  Auth.create_user_session(user, "127.0.0.#{rem(i, 255)}")
                end)

              {:ok, time, result}
            catch
              kind, reason -> {:error, kind, reason}
            end
          end)
        end

      results = Task.await_many(high_load_tasks, 60_000)

      # Most requests should succeed even under stress
      successes =
        Enum.count(results, fn
          {:ok, _time, {:ok, _}} -> true
          _ -> false
        end)

      errors =
        Enum.count(results, fn
          {:error, _kind, _reason} -> true
          _ -> false
        end)

      success_rate = successes / length(results)
      assert success_rate > 0.80, "Stress test success rate: #{success_rate}"
      assert errors < 20, "Too many errors under stress: #{errors}"

      # System should recover after stress
      :timer.sleep(1000)

      # Test normal operation after stress
      {recovery_time, {:ok, _session}} =
        :timer.tc(fn ->
          {:ok, user} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")
          Auth.create_user_session(user, "127.0.0.1")
        end)

      assert recovery_time < 500_000, "Recovery time: #{recovery_time}μs, expected < 500ms"
    end
  end

  # Helper modules for statistics
  defmodule Statistics do
    def variance(values) do
      count = length(values)

      if count > 0 do
        mean = Enum.sum(values) / count

        sum_of_squares =
          Enum.reduce(values, 0, fn x, acc ->
            acc + :math.pow(x - mean, 2)
          end)

        sum_of_squares / count
      else
        0
      end
    end
  end

  # Helper functions
  defp create_test_user(attrs \\ %{}) do
    default_attrs = %{
      first_name: "Performance",
      last_name: "Test",
      email: "perf_test@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    User.register(merged_attrs)
  end
end
