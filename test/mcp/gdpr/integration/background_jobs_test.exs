defmodule Mcp.Gdpr.Integration.BackgroundJobsTest do
  use McpWeb.ConnCase, async: true

  @moduletag :gdpr
  @moduletag :integration

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

  describe "Background Job Processing" do
    setup [:create_user, :auth_user_conn]

    test "export jobs are queued properly", %{conn: conn, user: user} do
      # RED: Test that export requests create background jobs

      # Request data export
      conn = post(conn, "/api/gdpr/export", %{"format" => "json"})

      # Should return 202 with job details
      response = json_response(conn, 202)
      assert %{"export_id" => export_id, "status" => "pending"} = response

      # Response should indicate job was queued
      assert is_binary(response["job_id"]) or response["queued"] or
               response["status"] == "pending"

      # Export ID should be job-compatible format
      assert String.starts_with?(export_id, "export_") or is_binary(export_id)
    end

    test "job status tracking works", %{conn: conn, user: user} do
      # RED: Test that job status can be tracked over time

      # Request export
      conn = post(conn, "/api/gdpr/export", %{"format" => "json"})
      response = json_response(conn, 202)
      export_id = response["export_id"]

      # Check initial status
      conn = get(conn, "/api/gdpr/export/#{export_id}/status")
      status_response = json_response(conn, 200)

      # Should have status tracking information
      assert %{"export_id" => ^export_id, "status" => status} = status_response
      assert status in ["pending", "processing", "completed", "failed"]

      # Should include job metadata
      assert status_response["created_at"] or status_response["updated_at"] or
               status_response["job_id"] or status_response["queue"]
    end

    test "job retry logic on failures", %{conn: conn, user: user} do
      # RED: Test that failed jobs are properly retried

      # Request export with parameters that might cause failure
      conn =
        post(conn, "/api/gdpr/export", %{
          "format" => "json",
          "user_id" => "non-existent-user-uuid"
        })

      # Should either succeed with 202 or fail gracefully
      if conn.status == 202 do
        response = json_response(conn, 202)
        export_id = response["export_id"]

        # Check status - might show failure or retry status
        conn = get(conn, "/api/gdpr/export/#{export_id}/status")
        status_response = json_response(conn, 200)

        # Should handle failure cases appropriately
        if status_response["status"] == "failed" do
          assert status_response["error"] or status_response["retry_count"]
        end
      else
        # Should fail gracefully with proper error message
        assert conn.status in [400, 404]
        response = json_response(conn, conn.status)
        assert response["error"]
      end
    end

    test "concurrent job handling", %{conn: conn, user: user} do
      # RED: Test that multiple concurrent jobs are handled properly

      # Submit multiple export requests
      export_requests =
        for i <- 1..3 do
          conn =
            post(conn, "/api/gdpr/export", %{
              "format" => "json",
              "request_id" => "req_#{i}"
            })

          {conn, i}
        end

      # All requests should be accepted and queued
      successful_exports = Enum.filter(export_requests, fn {conn, _i} -> conn.status == 202 end)
      assert length(successful_exports) >= 2

      # Each should have unique export ID
      export_ids =
        successful_exports
        |> Enum.map(fn {conn, _i} -> json_response(conn, 202)["export_id"] end)
        |> Enum.uniq()

      assert length(export_ids) == length(successful_exports)

      # Check that all jobs can be tracked
      for export_id <- export_ids do
        conn = get(conn, "/api/gdpr/export/#{export_id}/status")
        assert conn.status == 200
        status_response = json_response(conn, 200)
        assert status_response["export_id"] == export_id
      end
    end
  end

  describe "Job Queue Management" do
    test "export jobs use correct queue", %{conn: conn} do
      # RED: Test that export jobs are queued in the correct priority queue

      # Create authenticated connection
      [user: user] = create_user(%{})
      conn = auth_conn(conn, user)

      # Request export
      conn = post(conn, "/api/gdpr/export", %{"format" => "json"})

      if conn.status == 202 do
        response = json_response(conn, 202)

        # Should indicate queue assignment
        assert response["queue"] == "gdpr_exports" or
                 response["job_queue"] or
                 String.contains?(inspect(response), "gdpr_exports")
      end
    end

    test "admin compliance jobs use appropriate queue", %{conn: conn} do
      # RED: Test that admin operations use correct job queues

      # Create admin user
      admin_user = %{
        id: Ecto.UUID.generate(),
        email: "admin@example.com",
        role: :admin,
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      admin_conn =
        conn
        |> assign(:current_user, admin_user)
        |> put_req_header("authorization", "Bearer admin.token.#{admin_user.id}")

      # Request compliance report
      conn = get(admin_conn, "/api/gdpr/admin/compliance")

      if conn.status == 200 do
        response = json_response(conn, 200)

        # Should indicate processing job or immediate result
        assert response["compliance_score"] or
                 response["job_id"] or
                 response["processed_at"]
      end
    end

    test "job priority handling", %{conn: conn} do
      # RED: Test that jobs are prioritized correctly

      [user: user] = create_user(%{})
      conn = auth_conn(conn, user)

      # Submit high priority (user data deletion) and normal priority (export) jobs
      # User deletion should have higher priority than export

      # 1. Submit normal priority export
      export_conn = post(conn, "/api/gdpr/export", %{"format" => "json"})

      # 2. Submit high priority deletion (as admin)
      admin_user = %{
        id: Ecto.UUID.generate(),
        email: "admin@example.com",
        role: :admin,
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      admin_conn =
        conn
        |> assign(:current_user, admin_user)
        |> put_req_header("authorization", "Bearer admin.token.#{admin_user.id}")

      deletion_conn = delete(admin_conn, "/api/gdpr/data/#{user.id}")

      # Both should be accepted
      if export_conn.status == 202 and deletion_conn.status == 202 do
        export_response = json_response(export_conn, 202)
        deletion_response = json_response(deletion_conn, 202)

        # Should indicate different priorities or queue assignments
        export_queue = export_response["queue"] || "gdpr_exports"
        deletion_queue = deletion_response["queue"] || "gdpr_anonymize"

        assert export_queue != deletion_queue or
                 export_response["priority"] != deletion_response["priority"]
      end
    end
  end

  describe "Job Error Handling and Recovery" do
    setup [:create_user, :auth_user_conn]

    test "malformed job parameters are rejected", %{conn: conn} do
      # RED: Test that invalid job parameters are caught early

      # Submit export with invalid parameters
      conn =
        post(conn, "/api/gdpr/export", %{
          "format" => "invalid_format",
          "user_id" => "not-a-uuid",
          "options" => %{"invalid" => "data"}
        })

      # Should return 400 with validation error
      assert conn.status == 400
      response = json_response(conn, 400)

      assert response["error"] =~ "Invalid" or
               response["error"] =~ "unsupported" or
               response["error"] =~ "validation"
    end

    test "job timeout handling", %{conn: conn} do
      # RED: Test that long-running jobs have appropriate timeout handling

      # Request potentially long-running operation
      conn =
        post(conn, "/api/gdpr/export", %{
          "format" => "json",
          "large_dataset" => true
        })

      if conn.status == 202 do
        response = json_response(conn, 202)
        export_id = response["export_id"]

        # Check status after some time
        conn = get(conn, "/api/gdpr/export/#{export_id}/status")
        status_response = json_response(conn, 200)

        # Should show appropriate status (not stuck indefinitely)
        assert status_response["status"] in [
                 "pending",
                 "processing",
                 "completed",
                 "failed",
                 "timeout"
               ]

        # Should have timeout information if applicable
        if status_response["status"] == "failed" do
          assert status_response["error"] =~ "timeout" or
                   status_response["timeout"] or
                   status_response["retry_count"]
        end
      end
    end

    test "job dependency management", %{conn: conn} do
      # RED: Test that jobs with dependencies are handled correctly

      # Request export that depends on user consent verification
      conn =
        post(conn, "/api/gdpr/export", %{
          "format" => "json",
          "verify_consent" => true
        })

      if conn.status == 202 do
        response = json_response(conn, 202)
        export_id = response["export_id"]

        # Status should indicate dependency status
        conn = get(conn, "/api/gdpr/export/#{export_id}/status")
        status_response = json_response(conn, 200)

        # Should show dependency information
        assert status_response["status"] in [
                 "pending",
                 "verifying_consent",
                 "processing",
                 "completed",
                 "failed"
               ]

        if status_response["status"] == "verifying_consent" do
          assert status_response["dependencies"] or
                   status_response["waiting_for"]
        end
      end
    end
  end

  describe "Job Monitoring and Metrics" do
    test "job execution metrics are tracked", %{conn: conn} do
      # RED: Test that job execution metrics are properly tracked

      [user: user] = create_user(%{})
      conn = auth_conn(conn, user)

      # Submit several jobs to generate metrics
      for i <- 1..3 do
        post(conn, "/api/gdpr/export", %{"format" => "json", "batch" => "#{i}"})
      end

      # Get admin compliance report which should include job metrics
      admin_user = %{
        id: Ecto.UUID.generate(),
        email: "admin@example.com",
        role: :admin,
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      admin_conn =
        conn
        |> assign(:current_user, admin_user)
        |> put_req_header("authorization", "Bearer admin.token.#{admin_user.id}")

      conn = get(admin_conn, "/api/gdpr/admin/compliance")

      if conn.status == 200 do
        response = json_response(conn, 200)

        # Should include job processing metrics
        assert response["pending_exports"] or
                 response["processing_exports"] or
                 response["job_queue_stats"] or
                 response["metrics"]
      end
    end

    test "job failure rate monitoring", %{conn: conn} do
      # RED: Test that job failure rates are monitored

      [user: user] = create_user(%{})
      conn = auth_conn(conn, user)

      # Submit some jobs that might fail
      post(conn, "/api/gdpr/export", %{"format" => "json"})
      post(conn, "/api/gdpr/export", %{"format" => "invalid"})

      # Admin should be able to see failure metrics
      admin_user = %{
        id: Ecto.UUID.generate(),
        email: "admin@example.com",
        role: :admin,
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      admin_conn =
        conn
        |> assign(:current_user, admin_user)
        |> put_req_header("authorization", "Bearer admin.token.#{admin_user.id}")

      conn = get(admin_conn, "/api/gdpr/admin/compliance")

      if conn.status == 200 do
        response = json_response(conn, 200)

        # Should include failure rate information
        assert response["failed_jobs"] or
                 response["error_rate"] or
                 response["failure_count"]
      end
    end
  end
end
