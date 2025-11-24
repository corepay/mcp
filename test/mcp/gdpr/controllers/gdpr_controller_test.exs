defmodule Mcp.Gdpr.Controllers.GdprControllerTest do
  use McpWeb.ConnCase, async: true

  alias Mcp.Gdpr.Supervisor
  alias Mcp.Accounts.User
  alias Mcp.Accounts.Tenant

  @moduletag :gdpr
  @moduletag :unit

  # Add host header for all API tests to bypass tenant routing
  setup %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-forwarded-host", "www.example.com")
    {:ok, conn: conn}
  end

  # Test setup functions for user creation and authentication
  defp create_user(context) do
    # Create a test user for GDPR scenarios
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

  describe "GDPR Controller Authentication" do
    test "requires authentication for data export request", %{conn: conn} do
      # RED: Test that unauthenticated requests are rejected
      conn = post(conn, "/api/gdpr/export", %{"format" => "json"})

      # Should return 401 Unauthorized
      assert json_response(conn, 401)["error"] =~ "Authentication required"
    end

    test "requires authentication for data deletion request", %{conn: conn} do
      # RED: Test that unauthenticated deletion requests are rejected
      conn = delete(conn, "/api/gdpr/data/123")

      # Should return 401 Unauthorized
      assert json_response(conn, 401)["error"] =~ "Authentication required"
    end

    test "requires admin privileges for admin operations", %{conn: conn} do
      # RED: Test that non-admin users cannot access admin endpoints
      [user: user] = create_user(%{attrs: %{role: :user}})
      context = %{conn: conn, user: user}
      auth_result = auth_user_conn(context)
      [conn: auth_conn, user: _user] = auth_result

      conn = get(auth_conn, "/api/gdpr/admin/compliance")

      # Should return 403 Forbidden
      assert json_response(conn, 403)["error"] =~ "Admin access required"
    end
  end

  describe "Data Export Functionality" do
    setup [:create_user, :auth_user_conn]

    test "rejects invalid export formats", %{conn: conn, user: user} do
      # RED: Test validation of export format parameter
      conn = post(conn, "/api/gdpr/export", %{"format" => "invalid"})

      # Should return 400 Bad Request with validation error
      assert json_response(conn, 400)["error"] =~ "Invalid export format"
    end

    test "rejects malicious content in export parameters", %{conn: conn, user: user} do
      # RED: Test XSS injection prevention
      malicious_payload = %{"format" => "json", "purpose" => "<script>alert('xss')</script>"}
      conn = post(conn, "/api/gdpr/export", malicious_payload)

      # Should return 400 Bad Request with dangerous content error
      assert json_response(conn, 400)["error"] =~ "dangerous content"
    end

    test "accepts valid export requests", %{conn: conn, user: user} do
      # RED: Test that valid export requests are accepted
      conn = post(conn, "/api/gdpr/export", %{"format" => "json"})

      # Should return 202 Accepted with export details
      assert %{"export_id" => export_id, "status" => "pending"} = json_response(conn, 202)
      assert is_binary(export_id)
    end
  end

  describe "Input Validation Security" do
    setup [:create_user, :auth_user_conn]

    test "sanitizes user ID parameters", %{conn: conn, user: user} do
      # RED: Test SQL injection prevention in user IDs
      malicious_user_id = "123'; DROP TABLE users; --"
      conn = get(conn, "/api/gdpr/export/#{malicious_user_id}/status")

      # Should return 404 Not Found for invalid UUID format (routing handles this)
      assert json_response(conn, 404)["error"] =~ "Export not found"
    end

    test "validates consent parameters", %{conn: conn, user: user} do
      # RED: Test consent parameter validation
      invalid_consent = %{"legal_basis" => "invalid_basis", "purpose" => ""}
      conn = post(conn, "/api/gdpr/consent", invalid_consent)

      # Should return 400 Bad Request with validation error
      assert json_response(conn, 400)["error"] =~ "Consent parameters required"
    end

    test "prevents XSS in consent parameters", %{conn: conn, user: user} do
      # RED: Test XSS prevention in consent data
      xss_consent = %{"consents" => %{"legal_basis" => "consent", "purpose" => "<img src=x onerror=alert('xss')>"}}
      conn = post(conn, "/api/gdpr/consent", xss_consent)

      # Should return 400 Bad Request with dangerous content error
      assert json_response(conn, 400)["error"] =~ "dangerous content"
    end
  end

  describe "Rate Limiting" do
    setup [:create_user, :auth_user_conn]

    test "enforces rate limits on export requests", %{conn: conn, user: user} do
      # RED: Test rate limiting enforcement
      # Make multiple requests rapidly
      for _ <- 1..60 do
        post(conn, "/api/gdpr/export", %{"format" => "json"})
      end

      # Should hit rate limit on subsequent request
      conn = post(conn, "/api/gdpr/export", %{"format" => "json"})
      assert json_response(conn, 429)["error"] =~ "Rate limit exceeded"
    end
  end

  describe "Error Handling" do
    setup [:create_user, :auth_user_conn]

    test "handles malformed JSON gracefully", %{conn: conn, user: user} do
      # RED: Test malformed JSON handling
      assert_raise Plug.Parsers.ParseError, fn ->
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/gdpr/export", "invalid json{")
      end
    end

    test "sanitizes error responses", %{conn: conn, user: user} do
      # RED: Test that error responses don't leak sensitive information
      conn = post(conn, "/api/gdpr/export", %{"format" => "invalid_format"})

      # Should return generic error without exposing system details
      response = json_response(conn, 400)
      assert response["error"] =~ "Invalid export format"
      refute String.contains?(response["error"], "database")
      refute String.contains?(response["error"], "stack trace")
    end
  end

  defp auth_user_conn(%{conn: conn} = context) do
    user = context[:user]
    [conn: auth_conn(conn, user), user: user]
  end

  defp auth_conn(conn, user) do
    conn
    |> assign(:current_user, user)
    |> put_req_header("authorization", "Bearer mock.jwt.token.#{user.id}")
    |> put_req_header("x-csrf-token", "test-csrf-token")
  end
end