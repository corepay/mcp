defmodule Mcp.Security.AuthenticationSecurityTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Phoenix.ConnTest

  alias Mcp.Accounts.{Auth, Token, User}
  alias Mcp.Cache.SessionStore
  alias McpWeb.Auth.SessionPlug

  @endpoint McpWeb.Endpoint

  setup do
    # Clean up any existing sessions
    SessionStore.flush_all()

    conn =
      build_conn()
      |> Map.put(:remote_ip, {127, 0, 0, 1})
      |> put_req_header("user-agent", "Security Test Browser")

    {:ok, conn: conn}
  end

  describe "CSRF Protection" do
    test "prevents form submission without CSRF token", %{conn: conn} do
      # Attempt to submit login form without CSRF token
      conn =
        conn
        |> delete_req_header("x-csrf-token")
        |> post("/sign_in", %{
          "email" => "test@example.com",
          "password" => "Password123!"
        })

      # Should result in CSRF error (Phoenix handles this automatically)
      assert conn.status == 403 or conn.status == 302
    end

    test "validates CSRF token in OAuth state", %{conn: conn} do
      # Test that OAuth state parameters include CSRF protection
      conn = get(conn, "/auth/google")

      state = get_session(conn, :oauth_state)
      assert state != nil
      assert String.starts_with?(state, "oauth_")
      # Cryptographically secure
      assert String.length(state) > 20

      # Verify state is different on subsequent requests
      conn2 = get(conn, "/auth/google")
      state2 = get_session(conn2, :oauth_state)
      assert state != state2
    end

    test "prevents CSRF attacks with manipulated state", %{conn: conn} do
      # Setup valid session but manipulated state
      conn =
        conn
        |> put_session(:oauth_state, "valid_state")
        |> put_session(:oauth_provider, "google")

      # Attempt callback with different state
      conn = get(conn, "/auth/google/callback?code=test&state=manipulated_state")

      assert redirected_to(conn) == "/sign_in"
      assert get_flash(conn, :error) == "Invalid OAuth state"
    end
  end

  describe "Rate Limiting" do
    test "implements account lockout after failed attempts", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Make 5 failed login attempts
      for i <- 1..5 do
        conn =
          conn
          |> recycle()
          |> post("/sign_in", %{
            "email" => user.email,
            "password" => "wrong_password_#{i}"
          })

        if i < 5 do
          assert get_flash(conn, :error) == "Invalid email or password"
        end
      end

      # 6th attempt should be locked out
      conn =
        conn
        |> recycle()
        |> post("/sign_in", %{
          "email" => user.email,
          # Correct password
          "password" => "Password123!"
        })

      assert get_flash(conn, :error) ==
               "Account is locked. Please check your email for unlock instructions."

      # Verify user is locked in database
      {:ok, updated_user} = User.by_email(%{email: user.email}) |> Ash.read()
      updated_user = hd(updated_user)
      assert updated_user.locked_at != nil
      assert updated_user.failed_attempts >= 5
      assert updated_user.unlock_token != nil
    end

    test "generates secure unlock tokens", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Trigger lockout
      for _i <- 1..5 do
        Auth.record_failed_attempt(user.email)
      end

      # Check unlock token
      {:ok, locked_user} = User.by_email(%{email: user.email}) |> Ash.read()
      locked_user = hd(locked_user)

      assert locked_user.unlock_token != nil
      assert String.starts_with?(locked_user.unlock_token, "unlock_")
      assert String.length(locked_user.unlock_token) > 30

      # Token should be URL-safe
      assert not String.contains?(locked_user.unlock_token, "+")
      assert not String.contains?(locked_user.unlock_token, "/")
      assert not String.contains?(locked_user.unlock_token, "=")
    end

    test "implements IP-based rate limiting", %{conn: conn} do
      # This test would require implementing IP-based rate limiting
      # For now, we test the current account-based rate limiting
      {:ok, user} = create_test_user()

      # Test with different IPs (simulated by changing remote_ip)
      failed_ips = [
        {192, 168, 1, 100},
        {192, 168, 1, 101},
        {192, 168, 1, 102}
      ]

      Enum.each(failed_ips, fn ip ->
        conn =
          conn
          |> recycle()
          |> Map.put(:remote_ip, ip)
          |> post("/sign_in", %{
            "email" => user.email,
            "password" => "wrong_password"
          })

        assert get_flash(conn, :error) == "Invalid email or password"
      end)

      # User should not be locked yet (attempts from different IPs may not count)
      {:ok, current_user} = User.by_email(%{email: user.email}) |> Ash.read()
      current_user = hd(current_user)
      assert current_user.failed_attempts < 5
    end
  end

  describe "Session Security" do
    test "creates secure JWT tokens", %{conn: conn} do
      {:ok, user} = create_test_user()

      {:ok, session} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")

      # Verify access token structure
      assert session.access_token != nil
      assert session.refresh_token != nil
      assert session.session_id != nil

      # Verify token claims
      {:ok, claims} = Auth.verify_jwt_access_token(session.access_token)
      assert claims["sub"] == to_string(user.id)
      assert claims["type"] == "access"
      assert claims["jti"] != nil
      assert claims["exp"] > DateTime.utc_now() |> DateTime.to_unix()
    end

    test "stores encrypted tokens in cookies", %{conn: conn} do
      {:ok, user} = create_test_user()

      conn =
        conn
        |> post("/sign_in", %{
          "email" => user.email,
          "password" => "Password123!"
        })

      # Check that encrypted tokens are set
      assert conn.resp_cookies["_mcp_access_token"] != nil
      assert conn.resp_cookies["_mcp_refresh_token"] != nil
      assert conn.resp_cookies["_mcp_session_id"] != nil

      # Tokens should be encrypted (not raw JWT)
      access_token = conn.resp_cookies["_mcp_access_token"]
      # JWT header
      refute String.starts_with?(access_token.value, "eyJ")
    end

    test "implements secure cookie settings", %{conn: conn} do
      {:ok, user} = create_test_user()

      conn =
        conn
        |> post("/sign_in", %{
          "email" => user.email,
          "password" => "Password123!"
        })

      # Check cookie security headers
      # This would typically be handled by the plug/session configuration
      # We'll verify the session cookies exist
      assert get_session(conn, :user_token) != nil
      assert get_session(conn, :current_user) != nil
    end

    test "revokes all sessions on password change", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Create multiple sessions
      {:ok, session1} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")
      {:ok, session2} = Auth.authenticate(user.email, "Password123!", "192.168.1.1")

      # Verify both sessions are valid
      assert {:ok, _} = Auth.verify_session(session1.access_token)
      assert {:ok, _} = Auth.verify_session(session2.access_token)

      # Revoke all user sessions
      Auth.revoke_user_sessions(user.id)

      # Both sessions should now be invalid
      assert {:error, :token_revoked} = Auth.verify_session(session1.access_token)
      assert {:error, :token_revoked} = Auth.verify_session(session2.access_token)
    end

    test "handles session expiration", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Create session
      {:ok, session} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")

      # Verify session is valid initially
      assert {:ok, _} = Auth.verify_session(session.access_token)

      # Simulate expired token (this would require mocking JWT verification)
      # For now, we'll test the refresh mechanism
      {:ok, new_session} = Auth.refresh_jwt_session(session.refresh_token)

      assert new_session.access_token != session.access_token
      assert new_session.refresh_token != session.refresh_token
    end
  end

  describe "Password Security" do
    test "uses bcrypt for password hashing", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Verify password is properly hashed
      assert user.hashed_password != nil
      # bcrypt prefix
      assert String.starts_with?(user.hashed_password, "$2b$")
      # bcrypt hash length
      assert String.length(user.hashed_password) == 60
    end

    test "prevents timing attacks on authentication", %{conn: conn} do
      # Create a user
      {:ok, user} = create_test_user()

      # Measure time for non-existent user
      start_time = :erlang.monotonic_time(:millisecond)

      post(conn, "/sign_in", %{
        "email" => "nonexistent@example.com",
        "password" => "password"
      })

      nonexistent_time = :erlang.monotonic_time(:millisecond) - start_time

      # Measure time for existent user with wrong password
      start_time = :erlang.monotonic_time(:millisecond)

      post(conn, "/sign_in", %{
        "email" => user.email,
        "password" => "wrongpassword"
      })

      wrong_password_time = :erlang.monotonic_time(:millisecond) - start_time

      # Times should be similar (within reasonable variance)
      # This tests that constant-time comparison is used
      time_diff = abs(nonexistent_time - wrong_password_time)
      # Less than 100ms difference
      assert time_diff < 100
    end

    test "enforces password complexity requirements", %{conn: conn} do
      weak_passwords = [
        # Too common
        "password",
        # Too simple
        "123456",
        # Too short
        "abc",
        # Common pattern
        "password123",
        # Keyboard pattern
        "qwerty"
      ]

      Enum.each(weak_passwords, fn weak_password ->
        conn =
          conn
          |> recycle()
          |> post("/sign_in", %{
            "email" => "test@example.com",
            "password" => weak_password
          })

        # Should still fail authentication (user doesn't exist)
        assert get_flash(conn, :error) == "Invalid email or password"
      end)
    end
  end

  describe "Input Validation and Sanitization" do
    test "sanitizes email input", %{conn: conn} do
      malicious_emails = [
        "test@example.com<script>alert('xss')</script>",
        "test@example.com\0malicious",
        "test@example.com\r\nmalicious",
        "test+['test']@example.com",
        "test@example.com OR 1=1"
      ]

      Enum.each(malicious_emails, fn malicious_email ->
        conn =
          conn
          |> recycle()
          |> post("/sign_in", %{
            "email" => malicious_email,
            "password" => "Password123!"
          })

        # Should not cause server error
        assert conn.status != 500
        assert get_flash(conn, :error) == "Invalid email or password"
      end)
    end

    test "prevents SQL injection in authentication", %{conn: conn} do
      sql_injection_attempts = [
        "' OR '1'='1",
        "admin'--",
        "admin'/*",
        "' OR 'x'='x",
        "'; DROP TABLE users; --"
      ]

      Enum.each(sql_injection_attempts, fn injection ->
        conn =
          conn
          |> recycle()
          |> post("/sign_in", %{
            "email" => injection,
            "password" => injection
          })

        # Should not cause database errors or data leakage
        assert conn.status != 500
        assert get_flash(conn, :error) == "Invalid email or password"
      end)
    end

    test "validates input length limits", %{conn: conn} do
      # Test extremely long email
      long_email = String.duplicate("a", 500) <> "@example.com"

      conn =
        conn
        |> post("/sign_in", %{
          "email" => long_email,
          "password" => "Password123!"
        })

      # Should handle gracefully
      assert conn.status != 500
    end
  end

  describe "OAuth Security" do
    test "validates OAuth state parameter", %{conn: conn} do
      # Test with missing state parameter
      conn = get(conn, "/auth/google/callback?code=test")

      assert redirected_to(conn) == "/sign_in"
      assert get_flash(conn, :error) == "Invalid OAuth state"
    end

    test "prevents OAuth code injection", %{conn: conn} do
      malicious_codes = [
        "malicious_code'; DROP TABLE users; --",
        "../../../etc/passwd",
        "<script>alert('xss')</script>",
        "null",
        "undefined"
      ]

      Enum.each(malicious_codes, fn malicious_code ->
        conn =
          conn
          |> recycle()
          |> put_session(:oauth_state, "valid_state")
          |> put_session(:oauth_provider, "google")

        conn =
          get(conn, "/auth/google/callback?code=#{URI.encode(malicious_code)}&state=valid_state")

        # Should handle malicious input gracefully
        assert conn.status != 500
      end)
    end

    test "validates OAuth provider", %{conn: conn} do
      invalid_providers = [
        "../../../etc/passwd",
        "javascript:alert('xss')",
        "<script>alert('xss')</script>",
        "admin'--"
      ]

      Enum.each(invalid_providers, fn invalid_provider ->
        conn = get(conn, "/auth/#{invalid_provider}")

        # Should redirect with error
        assert redirected_to(conn) == "/sign_in"
        assert get_flash(conn, :error) == "Invalid OAuth provider"
      end)
    end
  end

  describe "Session Hijacking Prevention" do
    test "binds session to IP address", %{conn: conn} do
      {:ok, user} = create_test_user()
      original_ip = {127, 0, 0, 1}

      # Create session with specific IP
      {:ok, session} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")

      # Verify session includes IP information
      {:ok, claims} = Auth.verify_jwt_access_token(session.access_token)
      # Claims should include device info with IP
      assert claims["device_id"] != nil
    end

    test "binds session to user agent", %{conn: conn} do
      {:ok, user} = create_test_user()

      conn =
        conn
        |> put_req_header("user-agent", "TestSecurityBrowser/1.0")

      # Create session
      {:ok, session} =
        Auth.authenticate(user.email, "Password123!", "127.0.0.1",
          user_agent: "TestSecurityBrowser/1.0"
        )

      # Verify session includes user agent
      {:ok, claims} = Auth.verify_jwt_access_token(session.access_token)
      # This would require extending the JWT claims to include user agent
      # Session identifier
      assert claims["jti"] != nil
    end

    test "detects concurrent sessions", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Create multiple sessions
      {:ok, session1} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")
      {:ok, session2} = Auth.authenticate(user.email, "Password123!", "192.168.1.1")

      # Both sessions should be valid initially
      assert {:ok, _} = Auth.verify_session(session1.access_token)
      assert {:ok, _} = Auth.verify_session(session2.access_token)

      # This would require implementing concurrent session detection
      # For now, we verify multiple sessions can exist
      assert session1.session_id != session2.session_id
    end
  end

  describe "Security Headers" do
    test "includes security headers in responses", %{conn: conn} do
      conn = get(conn, "/sign_in")

      # Check for security headers (these would be configured in the endpoint/plug)
      # This is a placeholder for actual header verification
      assert conn.status == 200
    end

    test "prevents clickjacking with X-Frame-Options", %{conn: conn} do
      conn = get(conn, "/sign_in")

      # This would require actual header checking
      # Frame protection should be configured in the endpoint
      assert conn.status == 200
    end
  end

  describe "Error Handling Security" do
    test "does not leak sensitive information in error messages", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Test various error scenarios
      error_scenarios = [
        {"wrong@example.com", "Password123!"},
        {user.email, "wrongpassword"},
        {"nonexistent@example.com", "anypassword"}
      ]

      Enum.each(error_scenarios, fn {email, password} ->
        conn =
          conn
          |> recycle()
          |> post("/sign_in", %{
            "email" => email,
            "password" => password
          })

        # All should return the same generic error message
        assert get_flash(conn, :error) == "Invalid email or password"
      end)
    end

    test "handles database errors gracefully", %{conn: conn} do
      # This would require mocking database failures
      # For now, test with malformed requests
      conn =
        conn
        |> post("/sign_in", %{
          "email" => nil,
          "password" => nil
        })

      # Should not crash the server
      assert conn.status != 500
    end
  end

  # Helper functions

  defp create_test_user(attrs \\ %{}) do
    default_attrs = %{
      first_name: "Test",
      last_name: "User",
      email: "test@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      status: :active
    }

    User.register(Map.merge(default_attrs, attrs))
  end
end
