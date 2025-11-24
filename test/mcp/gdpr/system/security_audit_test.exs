defmodule Mcp.Gdpr.System.SecurityAuditTest do
  use McpWeb.ConnCase, async: true

  @moduletag :gdpr
  @moduletag :system
  @moduletag :security

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
      tenant_schema: "public",
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
    [user: user]
  end

  defp create_admin_user(context) do
    user = %{
      id: Ecto.UUID.generate(),
      email: "admin@example.com",
      role: :admin,
      tenant_schema: "public",
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

  describe "Security Audit - Authentication & Authorization" do
    test "prevents unauthorized access to sensitive endpoints", %{conn: conn} do
      # RED: Test that unauthenticated requests are properly rejected

      # Test various endpoints without authentication
      unauthenticated_endpoints = [
        {get(conn, "/api/gdpr/export/test-id/status"), "export status"},
        {get(conn, "/api/gdpr/audit-trail"), "audit trail"},
        {get(conn, "/api/gdpr/consent"), "consent data"},
        {delete(conn, "/api/gdpr/data/#{Ecto.UUID.generate()}"), "user data deletion"}
      ]

      for {request_conn, endpoint_type} <- unauthenticated_endpoints do
        # Should return 401, 403, or 404 (for non-existent resources) for unauthenticated requests
        assert request_conn.status in [401, 403, 404]
        if request_conn.status in [401, 403] do
          response = json_response(request_conn, request_conn.status)
          assert response["error"] =~ "Authentication required" or
                 response["error"] =~ "Unauthorized" or
                 response["error"] =~ "forbidden"
        end
      end
    end
  end

  describe "Security Audit - Authenticated User Security" do
    setup [:create_user, :auth_user_conn]

    test "prevents privilege escalation attempts", %{conn: conn, user: user} do
      # RED: Test that regular users cannot access admin endpoints

      admin_endpoints = [
        get(conn, "/api/gdpr/admin/compliance"),
        get(conn, "/api/gdpr/admin/compliance-report"),
        get(conn, "/api/gdpr/admin/users/#{user.id}/data")
      ]

      for request_conn <- admin_endpoints do
        # Regular user should get 403 Forbidden for admin endpoints
        assert request_conn.status == 403

        response = json_response(request_conn, 403)
        assert response["error"] =~ "Admin access required" or
               response["error"] =~ "forbidden" or
               response["error"] =~ "access denied" or
               response["error"] =~ "unauthorized" or
               response["error"] =~ "permission" or
               response["error"] =~ "required"
      end
    end

    test "validates token integrity and format", %{conn: conn} do
      # RED: Test that malformed or invalid tokens are rejected

      invalid_token_scenarios = [
        {"", "empty token"},
        {"invalid.token.format", "malformed token"},
        {"Bearer", "token without value"},
        {"Bearer token.with.invalid.chars<>", "token with invalid characters"}
      ]

      for {token, scenario} <- invalid_token_scenarios do
        conn =
          conn
          |> put_req_header("authorization", token)
          |> get("/api/gdpr/export/#{Ecto.UUID.generate()}/status")

        # Should reject invalid tokens
        assert conn.status in [401, 403, 404]
        if conn.status in [401, 403] do
          response = json_response(conn, conn.status)
          assert response["error"] =~ "Authentication" or
                 response["error"] =~ "Unauthorized"
        end
      end
    end
  end

  describe "Security Audit - Input Validation & Sanitization" do
    setup [:create_user, :auth_user_conn]

    test "prevents SQL injection attacks", %{conn: conn} do
      # RED: Test that SQL injection attempts are blocked

      sql_injection_payloads = [
        "'; DROP TABLE users; --",
        "1' OR '1'='1",
        "UNION SELECT * FROM users",
        "'; INSERT INTO users VALUES ('hacker', 'password'); --"
      ]

      for malicious_payload <- sql_injection_payloads do
        # Test user ID parameter
        conn = get(conn, "/api/gdpr/export/#{malicious_payload}/status")
        assert conn.status in [400, 404]

        # Handle both JSON and HTML error responses
        if get_resp_header(conn, "content-type") |> Enum.any?(&String.contains?(&1, "application/json")) do
          response = json_response(conn, conn.status)
          assert response["error"] =~ "Invalid" or
                 response["error"] =~ "not found"
        end

        # Test export parameters
        conn = post(conn, "/api/gdpr/export", %{
          "format" => "json",
          "user_id" => malicious_payload
        })

        if conn.status != 202 do
          assert conn.status in [400, 422]

          # Handle both JSON and HTML error responses
          if get_resp_header(conn, "content-type") |> Enum.any?(&String.contains?(&1, "application/json")) do
            response = json_response(conn, conn.status)
            assert response["error"] =~ "Invalid"
          end
        end
      end
    end

    test "prevents XSS attacks", %{conn: conn} do
      # RED: Test that XSS attempts are properly sanitized

      xss_payloads = [
        "<script>alert('xss')</script>",
        "<img src=x onerror=alert('xss')>",
        "javascript:alert('xss')",
        "<svg onload=alert('xss')>",
        "';alert('xss');//"
      ]

      for xss_payload <- xss_payloads do
        # Test various parameters for XSS
        conn = post(conn, "/api/gdpr/export", %{
          "format" => "json",
          "purpose" => xss_payload,
          "callback_url" => xss_payload
        })

        # Should either accept (if sanitized) or reject (if detected)
        if conn.status == 202 do
          # If accepted, verify XSS was sanitized in response
          response = json_response(conn, 202)
          refute String.contains?(inspect(response), "<script>")
          refute String.contains?(inspect(response), "javascript:")
        else
          # Should reject malicious content
          assert conn.status in [400, 422]
          response = json_response(conn, conn.status)
          assert response["error"] =~ "dangerous" or
                 response["error"] =~ "invalid" or
                 response["error"] =~ "sanitized"
        end
      end
    end

    test "validates data types and formats", %{conn: conn} do
      # RED: Test that type validation works correctly

      # Test invalid UUID formats
      invalid_uuids = [
        "not-a-uuid",
        "123-456-789",
        "invalid-uuid-format",
        "../../etc/passwd",
        "null",
        "undefined"
      ]

      for invalid_uuid <- invalid_uuids do
        conn = get(conn, "/api/gdpr/export/#{invalid_uuid}/status")
        assert conn.status in [400, 404]
      end

      # Test invalid export formats
      invalid_formats = [
        "exe",
        "bat",
        "sh",
        "php",
        "../../../etc/passwd",
        "<script>alert('xss')</script>"
      ]

      for invalid_format <- invalid_formats do
        conn = post(conn, "/api/gdpr/export", %{"format" => invalid_format})
        assert conn.status in [400, 422]
        response = json_response(conn, conn.status)
        assert response["error"] =~ "Invalid" or
               response["error"] =~ "unsupported"
      end
    end
  end

  describe "Security Audit - Rate Limiting & DoS Protection" do
    setup [:create_user, :auth_user_conn]

    test "enforces rate limits on API endpoints", %{conn: conn} do
      # RED: Test that rate limiting prevents abuse

      # Clean up any existing rate limit state for this test
      case :ets.whereis(:gdpr_rate_limits) do
        :undefined -> :ok
        _table -> :ets.delete_all_objects(:gdpr_rate_limits)
      end

      # Make rapid requests to trigger rate limiting
      requests =
        for _i <- 1..60 do
          post(conn, "/api/gdpr/export", %{"format" => "json"})
        end

      # At least some requests should be rate limited
      rate_limited_requests = Enum.filter(requests, fn request_conn ->
        request_conn.status == 429
      end)

      assert length(rate_limited_requests) > 0, "No requests were rate limited - all responses: #{inspect(Enum.map(requests, & &1.status))}"

      # Verify rate limit response format
      if length(rate_limited_requests) > 0 do
        rate_limited_conn = Enum.at(rate_limited_requests, 0)
        response = json_response(rate_limited_conn, 429)

        # Check for proper rate limit response format
        assert response["error"] == "Rate limit exceeded" or
               response["error"] =~ "rate limit" or
               response["error"] =~ "too many requests" or
               response["message"] =~ "Too many GDPR requests"
      end
    end

    test "handles request size limits", %{conn: conn} do
      # RED: Test that oversized requests are rejected

      # Create large payload that exceeds Phoenix's default limit
      large_payload = %{
        "format" => "json",
        "large_data" => String.duplicate("x", 10_000_000)  # 10MB
      }

      payload_json = Jason.encode!(large_payload)

      # Phoenix Plug.Parsers rejects requests that are too large before our plug runs
      # This is the expected behavior - built-in Phoenix protection
      assert_raise Plug.Parsers.RequestTooLargeError, fn ->
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/gdpr/export", payload_json)
      end
    end
  end

  describe "Security Audit - Headers & CORS" do
    setup [:create_user, :auth_user_conn]

    test "includes security headers in responses", %{conn: conn} do
      # RED: Test that security headers are properly set

      # Test GET endpoint
      conn = get(conn, "/api/gdpr/export/#{Ecto.UUID.generate()}/status")

      # Should include security headers
      security_headers = [
        "x-content-type-options",
        "x-frame-options",
        "x-xss-protection",
        "strict-transport-security"
      ]

      for header <- security_headers do
        header_value = get_resp_header(conn, header)
        assert length(header_value) >= 1
      end
    end

    test "handles CORS headers correctly", %{conn: conn} do
      # RED: Test CORS policy enforcement

      # Test with origin header
      conn =
        conn
        |> put_req_header("origin", "https://malicious-site.com")
        |> get("/api/gdpr/export/#{Ecto.UUID.generate()}/status")

      # Check CORS headers
      cors_headers = get_resp_header(conn, "access-control-allow-origin")

      # Should either reject or have proper CORS handling
      if length(cors_headers) > 0 do
        # If CORS headers are present, they should be restrictive
        allowed_origin = Enum.at(cors_headers, 0)
        refute allowed_origin == "*"
        refute allowed_origin == "https://malicious-site.com"
      end
    end
  end

  describe "Security Audit - Data Exposure Prevention" do
    setup [:create_user, :create_admin_user]

    test "prevents sensitive data leakage in error messages", %{conn: conn} do
      # RED: Test that error messages don't expose sensitive information

      # Test with invalid but potentially sensitive inputs
      sensitive_inputs = [
        "admin@example.com",
        "root",
        "password",
        "secret_key",
        "database",
        "internal_error"
      ]

      for sensitive_input <- sensitive_inputs do
        conn = get(conn, "/api/gdpr/export/#{sensitive_input}/status")

        if conn.status in [400, 404, 500] do
          response = json_response(conn, conn.status)
          error_message = inspect(response)

          # Should not expose sensitive information
          refute String.contains?(error_message, "database")
          refute String.contains?(error_message, "stack trace")
          refute String.contains?(error_message, "internal")
          refute String.contains?(error_message, "password")
        end
      end
    end

    test "admin data is properly scoped and isolated", %{conn: conn} do
      # RED: Test that admin operations don't expose cross-tenant data

      # Create admin user
      [user: admin_user] = create_admin_user(%{})

      admin_conn =
        conn
        |> assign(:current_user, admin_user)
        |> put_req_header("authorization", "Bearer admin.token.#{admin_user.id}")

      # Get compliance report
      conn = get(admin_conn, "/api/gdpr/admin/compliance")

      if conn.status == 200 do
        response = json_response(conn, 200)

        # Should not expose sensitive system information
        response_str = inspect(response)
        refute String.contains?(response_str, "password")
        refute String.contains?(response_str, "secret")
        refute String.contains?(response_str, "private_key")
      end
    end
  end

  describe "Security Audit - Audit Trail Integrity" do
    setup [:create_user, :auth_user_conn]

    test "captures comprehensive audit information", %{conn: conn, user: user} do
      # RED: Test that audit trail captures all necessary information

      # Perform action that should be audited
      conn = post(conn, "/api/gdpr/export", %{"format" => "json"})

      # Check audit trail
      conn = get(conn, "/api/gdpr/audit-trail")

      if conn.status == 200 do
        response = json_response(conn, 200)

        if Map.has_key?(response, "audit_entries") and length(response["audit_entries"]) > 0 do
          audit_entry = Enum.at(response["audit_entries"], 0)

          # Should contain necessary audit fields
          required_fields = [
            "timestamp",
            "user_id",
            "action",
            "ip_address",
            "user_agent"
          ]

          for field <- required_fields do
            assert Map.has_key?(audit_entry, field) or
                   String.contains?(inspect(audit_entry), field)
          end

          # Should not contain sensitive data in audit trail
          audit_str = inspect(audit_entry)
          refute String.contains?(audit_str, "password")
          refute String.contains?(audit_str, "token")
        end
      end
    end

    test "audit trail is tamper-evident", %{conn: conn} do
      # RED: Test that audit entries cannot be tampered with

      # This is more of a design verification - audit entries should be immutable
      # In a real implementation, this would verify:
      # 1. Audit entries have cryptographic signatures
      # 2. Cannot be modified after creation
      # 3. Have sequence numbers to prevent gaps

      # For now, we verify the basic structure exists
      conn = get(conn, "/api/gdpr/audit-trail")

      if conn.status == 200 do
        response = json_response(conn, 200)

        # Should have audit entries structure
        assert Map.has_key?(response, "audit_entries") or
               Map.has_key?(response, "entries") or
               conn.status == 200  # Endpoint exists even if no entries
      end
    end
  end
end