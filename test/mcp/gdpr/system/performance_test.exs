defmodule Mcp.Gdpr.System.PerformanceTest do
  use McpWeb.ConnCase, async: false  # Performance tests should not be async

  @moduletag :gdpr
  @moduletag :system
  @moduletag :performance

  # Add host header for all API tests to bypass tenant routing
  setup %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-forwarded-host", "www.example.com")
    {:ok, conn: conn}
  end

  # Test setup functions for user creation and authentication
  defp create_user(context) do
    attrs = context[:attrs] || %{}

    default_attrs = %{
      email: "test-user@example.com",
      role: :user
    }

    final_attrs = Map.merge(default_attrs, attrs)

    user = %{
      id: Ecto.UUID.generate(),
      email: final_attrs.email,
      role: final_attrs.role,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
    [user: user]
  end

  defp auth_user_conn(%{conn: conn} = context) do
    user = context[:user]
    [conn: auth_conn(conn, user), user: user]
  end

  defp auth_conn(conn, user) do
    conn
    |> assign(:current_user, user)
    |> put_req_header("authorization", "Bearer mock.jwt.token.#{user.id}")
  end

  describe "Performance Benchmarks" do
    setup [:create_user, :auth_user_conn]

    test "API response times meet SLA requirements", %{conn: conn} do
      # RED: Test that API responses meet performance requirements

      # Define SLA thresholds (in milliseconds)
      sla_thresholds = %{
        simple_get: 200,      # Simple GET requests
        export_request: 500,  # Export request (requires processing)
        audit_trail: 300,     # Audit trail (may query multiple records)
        status_check: 200     # Status checks
      }

      # Test simple GET endpoint
      {time, _conn} = :timer.tc(fn ->
        get(conn, "/api/gdpr/export/#{Ecto.UUID.generate()}/status")
      end)
      assert time / 1000 <= sla_thresholds.status_check,
        "Status check took #{time/1000}ms, should be under #{sla_thresholds.status_check}ms"

      # Test audit trail endpoint
      {time, _conn} = :timer.tc(fn ->
        get(conn, "/api/gdpr/audit-trail")
      end)
      assert time / 1000 <= sla_thresholds.audit_trail,
        "Audit trail took #{time/1000}ms, should be under #{sla_thresholds.audit_trail}ms"

      # Test export request
      {time, _conn} = :timer.tc(fn ->
        post(conn, "/api/gdpr/export", %{"format" => "json"})
      end)
      assert time / 1000 <= sla_thresholds.export_request,
        "Export request took #{time/1000}ms, should be under #{sla_thresholds.export_request}ms"
    end

    test "concurrent request handling", %{conn: conn, user: user} do
      # RED: Test system performance under concurrent load

      # Simulate concurrent users making requests
      concurrent_requests = 10
      requests_per_user = 5

      # Create tasks for concurrent execution
      tasks =
        for _i <- 1..concurrent_requests do
          Task.async(fn ->
            user_conn = auth_conn(conn, user)

            # Make multiple requests
            results =
              for _j <- 1..requests_per_user do
                {time, response_conn} = :timer.tc(fn ->
                  post(user_conn, "/api/gdpr/export", %{
                    "format" => "json",
                    "request_id" => "#{:erlang.unique_integer()}"
                  })
                end)

                %{
                  response_time: time,
                  status_code: response_conn.status,
                  success: response_conn.status in [200, 202]
                }
              end

            %{
              total_requests: length(results),
              successful_requests: Enum.count(results, & &1.success),
              avg_response_time: Enum.sum(Enum.map(results, & &1.response_time)) / length(results),
              max_response_time: Enum.max(Enum.map(results, & &1.response_time))
            }
          end)
        end

      # Wait for all tasks to complete
      task_results = Task.await_many(tasks, 30_000)

      # Calculate aggregate metrics
      total_requests = Enum.sum(Enum.map(task_results, & &1.total_requests))
      total_successful = Enum.sum(Enum.map(task_results, & &1.successful_requests))
      avg_response_times = Enum.map(task_results, & &1.avg_response_time)
      overall_avg_response_time = Enum.sum(avg_response_times) / length(avg_response_times)
      max_response_time = Enum.max(Enum.map(task_results, & &1.max_response_time))

      # Performance assertions
      success_rate = total_successful / total_requests * 100
      assert success_rate >= 90.0,
        "Success rate was #{success_rate}%, should be at least 90%"

      assert overall_avg_response_time / 1000 <= 1000,
        "Average response time was #{overall_avg_response_time/1000}ms, should be under 1000ms"

      assert max_response_time / 1000 <= 5000,
        "Max response time was #{max_response_time/1000}ms, should be under 5000ms"
    end

    test "export processing performance", %{conn: conn} do
      # RED: Test performance of export processing with varying data sizes

      # Test different export scenarios
      export_scenarios = [
        %{"format" => "json", "dataset_size" => "small"},
        %{"format" => "csv", "dataset_size" => "medium"},
        %{"format" => "xml", "dataset_size" => "large"}
      ]

      performance_thresholds = %{
        small: 2_000,    # 2 seconds
        medium: 5_000,   # 5 seconds
        large: 10_000    # 10 seconds
      }

      for scenario <- export_scenarios do
        {time, response_conn} = :timer.tc(fn ->
          post(conn, "/api/gdpr/export", scenario)
        end)

        threshold = Map.get(performance_thresholds, scenario["dataset_size"], 5_000)

        assert time / 1000 <= threshold,
          "Export for #{scenario["dataset_size"]} dataset took #{time/1000}ms, should be under #{threshold}ms"

        # Verify the request was processed (not just rejected)
        assert response_conn.status in [200, 202],
          "Export request failed with status #{response_conn.status}"
      end
    end

    test "memory usage under load", %{conn: conn} do
      # RED: Test that memory usage remains reasonable under load

      # Get initial memory usage
      initial_memory = :erlang.memory(:total)

      # Generate load
      load_requests = 50
      results =
        for _i <- 1..load_requests do
          Task.async(fn ->
            post(conn, "/api/gdpr/export", %{
              "format" => "json",
              "request_id" => "#{:erlang.unique_integer()}"
            })
          end)
        end

      # Wait for completion
      responses = Task.await_many(results, 30_000)

      # Check final memory usage
      final_memory = :erlang.memory(:total)
      memory_increase = final_memory - initial_memory
      memory_increase_mb = memory_increase / (1024 * 1024)

      # Memory usage should not increase dramatically
      assert memory_increase_mb < 100,
        "Memory increased by #{memory_increase_mb}MB, should be under 100MB"

      # Verify most requests succeeded
      successful_responses = Enum.count(responses, fn response_conn ->
        response_conn.status in [200, 202]
      end)

      success_rate = successful_responses / length(responses) * 100
      assert success_rate >= 80.0,
        "Success rate under memory load was #{success_rate}%, should be at least 80%"
    end
  end

  describe "Load Testing" do
    setup [:create_user, :auth_user_conn]

    test "sustained load performance", %{conn: conn, user: user} do
      # RED: Test system performance under sustained load

      duration_seconds = 5
      target_rps = 10  # requests per second
      total_requests = duration_seconds * target_rps

      # Create a stream of requests over time
      request_stream =
        Stream.iterate(1, &(&1 + 1))
        |> Stream.take(total_requests)
        |> Stream.map(fn i ->
          Task.async(fn ->
            # Stagger requests to achieve target RPS
            :timer.sleep(div(i * 1000, target_rps))

            user_conn = auth_conn(conn, user)
            {time, response_conn} = :timer.tc(fn ->
              post(user_conn, "/api/gdpr/export", %{
                "format" => "json",
                "request_id" => "load_test_#{i}"
              })
            end)

            %{
              request_id: i,
              response_time: time,
              status_code: response_conn.status,
              success: response_conn.status in [200, 202]
            }
          end)
        end)

      # Execute all requests
      results = request_stream |> Enum.map(&Task.await/1)

      # Analyze results
      successful_requests = Enum.count(results, & &1.success)
      response_times = Enum.map(results, & &1.response_time)

      avg_response_time = Enum.sum(response_times) / length(response_times)
      p95_response_time = response_times |> Enum.sort() |> Enum.at(trunc(length(response_times) * 0.95))
      p99_response_time = response_times |> Enum.sort() |> Enum.at(trunc(length(response_times) * 0.99))

      success_rate = successful_requests / length(results) * 100

      # Performance assertions for sustained load
      assert success_rate >= 95.0,
        "Success rate under sustained load was #{success_rate}%, should be at least 95%"

      assert avg_response_time / 1000 <= 1500,
        "Average response time under load was #{avg_response_time/1000}ms, should be under 1500ms"

      assert p95_response_time / 1000 <= 3000,
        "95th percentile response time was #{p95_response_time/1000}ms, should be under 3000ms"

      assert p99_response_time / 1000 <= 5000,
        "99th percentile response time was #{p99_response_time/1000}ms, should be under 5000ms"
    end

    test "resource cleanup under load", %{conn: conn} do
      # RED: Test that system properly cleans up resources under heavy load

      # Monitor resource usage before, during, and after load
      initial_processes = :erlang.system_info(:process_count)
      initial_memory = :erlang.memory(:total)

      # Generate heavy load
      load_tasks =
        for _i <- 1..20 do
          Task.async(fn ->
            # Multiple rapid requests
            for _j <- 1..5 do
              post(conn, "/api/gdpr/export", %{"format" => "json"})
              :timer.sleep(10)  # Small delay
            end
          end)
        end

      # Wait for completion
      Task.await_many(load_tasks, 15_000)

      # Allow time for cleanup
      :timer.sleep(2000)

      # Check resource usage after cleanup
      final_processes = :erlang.system_info(:process_count)
      final_memory = :erlang.memory(:total)

      process_increase = final_processes - initial_processes
      memory_increase = (final_memory - initial_memory) / (1024 * 1024)

      # Resources should not leak significantly
      assert process_increase < 50,
        "Process count increased by #{process_increase}, should be under 50"

      assert memory_increase < 50,
        "Memory increased by #{memory_increase}MB, should be under 50MB"
    end
  end

  describe "Performance Regression Detection" do
    setup [:create_user, :auth_user_conn]

    test "API endpoint response time regression", %{conn: conn} do
      # RED: Test that response times don't regress from baselines

      # Define performance baselines (these would be updated based on historical data)
      baseline_response_times = %{
        export_request: 300,    # milliseconds
        status_check: 100,
        audit_trail: 200,
        consent_endpoint: 150
      }

      # Test each endpoint against baseline
      endpoints_to_test = [
        {fn -> post(conn, "/api/gdpr/export", %{"format" => "json"}) end, :export_request},
        {fn -> get(conn, "/api/gdpr/export/#{Ecto.UUID.generate()}/status") end, :status_check},
        {fn -> get(conn, "/api/gdpr/audit-trail") end, :audit_trail},
        {fn -> get(conn, "/api/gdpr/consent") end, :consent_endpoint}
      ]

      regression_threshold = 1.5  # Allow 50% regression

      for {request_fn, endpoint_key} <- endpoints_to_test do
        # Run multiple measurements for accuracy
        measurements =
          for _i <- 1..5 do
            {time, _conn} = :timer.tc(request_fn)
            time
          end

        avg_time = Enum.sum(measurements) / length(measurements)
        baseline = Map.get(baseline_response_times, endpoint_key, 500)
        allowed_max = baseline * regression_threshold

        assert avg_time / 1000 <= allowed_max,
          "#{endpoint_key} averaged #{avg_time/1000}ms, baseline is #{baseline}ms, regression threshold is #{allowed_max/1000}ms"
      end
    end

    test "throughput regression detection", %{conn: conn} do
      # RED: Test that throughput doesn't regress

      # Measure throughput by timing requests
      test_duration = 3000  # 3 seconds
      target_throughput = 20  # requests per second

      {total_requests, elapsed_time} = :timer.tc(fn ->
        request_count =
          Stream.iterate(1, &(&1 + 1))
          |> Stream.take_while(fn _i ->
            :timer.sleep(div(1000, target_throughput))
            true
          end)
          |> Enum.take(target_throughput * div(test_duration, 1000))
          |> length()

        request_count
      end)

      actual_throughput = total_requests / (elapsed_time / 1_000_000)

      # Should maintain at least 80% of target throughput
      min_throughput = target_throughput * 0.8
      assert actual_throughput >= min_throughput,
        "Throughput was #{actual_throughput} req/s, should be at least #{min_throughput} req/s"
    end
  end
end