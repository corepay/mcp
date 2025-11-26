defmodule Mcp.Gdpr.Integration.WorkflowTest do
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

  describe "End-to-End GDPR Workflow" do
    setup [:create_user, :auth_user_conn]

    test "complete data export workflow", %{conn: conn, user: user} do
      # RED: Test complete workflow from request to status check to download
      # 1. Request data export
      conn = post(conn, "/api/gdpr/export", %{"format" => "json"})

      # Should return 202 with export details
      response = json_response(conn, 202)
      assert %{"export_id" => export_id, "status" => "pending"} = response
      assert is_binary(export_id)
      assert response["status"] == "pending"

      # 2. Check export status
      conn = get(conn, "/api/gdpr/export/#{export_id}/status")

      # Should return current status
      status_response = json_response(conn, 200)
      assert %{"export_id" => ^export_id, "status" => status} = status_response
      assert status in ["pending", "processing", "completed"]

      # 3. Attempt download (may fail if not completed, but should be proper endpoint)
      conn = get(conn, "/api/gdpr/export/#{export_id}/download")

      # Should return either successful download or status indicating not ready
      if conn.status == 200 do
        # Download successful
        assert get_resp_header(conn, "content-type") == ["application/json"]
      else
        # Export not ready yet
        assert json_response(conn, 404)["error"] =~ "not found"
      end
    end

    test "data deletion workflow with admin privileges", %{conn: conn} do
      # RED: Test user data deletion workflow requires admin role
      admin_user = %{
        id: Ecto.UUID.generate(),
        email: "admin@example.com",
        role: :admin,
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      auth_conn =
        conn
        |> assign(:current_user, admin_user)
        |> put_req_header("authorization", "Bearer admin.token.#{admin_user.id}")

      # Delete user data
      user_id = Ecto.UUID.generate()
      conn = delete(auth_conn, "/api/gdpr/data/#{user_id}")

      # Should return 202 for successful deletion request
      response = json_response(conn, 202)
      assert %{"deletion_id" => deletion_id, "status" => "pending"} = response
      assert is_binary(deletion_id)
      assert response["status"] == "pending"

      # Check deletion status
      conn = get(auth_conn, "/api/gdpr/deletion-status")

      # Should return deletion status information
      status_response = json_response(conn, 200)
      assert %{"status" => status} = status_response
      assert status in ["pending", "processing", "completed"]
    end

    test "consent management workflow", %{conn: conn, user: user} do
      # RED: Test consent update workflow
      consent_data = %{
        "legal_basis" => "consent",
        "purpose" => "marketing",
        "granted" => true
      }

      # Update consent
      conn = post(conn, "/api/gdpr/consent", consent_data)

      # Should return 200 for successful consent update
      response = json_response(conn, 200)
      assert %{"consent_id" => consent_id, "status" => "updated"} = response
      assert is_binary(consent_id)
      assert response["status"] == "updated"

      # Retrieve current consent status
      conn = get(conn, "/api/gdpr/consent")

      # Should return current consent information
      consent_response = json_response(conn, 200)
      assert %{"user_id" => user_id, "consents" => consents} = consent_response
      assert user_id == user.id
      assert is_list(consents)
    end

    test "audit trail workflow integration", %{conn: conn, user: user} do
      # RED: Test that audit trail captures all GDPR actions
      # Perform multiple actions that should generate audit entries

      # 1. Request export (should generate audit entry)
      post(conn, "/api/gdpr/export", %{"format" => "json"})

      # 2. Get audit trail
      conn = get(conn, "/api/gdpr/audit-trail")

      # Should return audit trail entries
      audit_response = json_response(conn, 200)
      assert %{"user_id" => user_id, "audit_entries" => entries} = audit_response
      assert user_id == user.id
      assert is_list(entries)

      # Should contain export request entry
      export_entries =
        Enum.filter(entries, fn entry ->
          entry["action"] == "DATA_EXPORT_REQUEST" or
            entry["endpoint"] == "/api/gdpr/export"
        end)

      assert length(export_entries) >= 1
    end
  end

  describe "Error Handling in Integration Workflows" do
    setup [:create_user, :auth_user_conn]

    test "invalid export ID handling", %{conn: conn} do
      # RED: Test handling of invalid export IDs in status checks
      invalid_export_id = "invalid-uuid-format"

      conn = get(conn, "/api/gdpr/export/#{invalid_export_id}/status")

      # Should return 400 for invalid UUID format
      response = json_response(conn, 400)
      assert response["error"] =~ "Invalid export ID"
    end

    test "non-existent export ID handling", %{conn: conn} do
      # RED: Test handling of non-existent export IDs
      non_existent_id = Ecto.UUID.generate()

      conn = get(conn, "/api/gdpr/export/#{non_existent_id}/download")

      # Should return 404 for non-existent export
      response = json_response(conn, 404)
      assert response["error"] =~ "not found"
    end

    test "concurrent export requests", %{conn: conn} do
      # RED: Test handling of multiple concurrent export requests
      # This tests rate limiting and request handling

      # Make multiple requests rapidly
      results =
        for i <- 1..3 do
          post(conn, "/api/gdpr/export", %{"format" => "json", "request_id" => "#{i}"})
        end

      # All requests should be processed (rate limiting may affect some)
      successful_requests = Enum.filter(results, fn conn -> conn.status == 202 end)
      assert length(successful_requests) >= 1

      # Each successful request should have unique export ID
      export_ids =
        successful_requests
        |> Enum.map(&json_response(&1, 202)["export_id"])
        |> Enum.uniq()

      assert length(export_ids) == length(successful_requests)
    end
  end
end
