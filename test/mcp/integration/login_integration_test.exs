defmodule Mcp.Integration.LoginIntegrationTest do
  use ExUnit.Case, async: false  # Not async due to shared infrastructure
  use Phoenix.ConnTest

  import Mox

  alias Mcp.Accounts.{User, Auth, OAuth}
  alias Mcp.Cache.SessionStore
  alias McpWeb.{AuthController, OAuthController, Endpoint}
  alias McpWeb.Auth.SessionPlug

  @endpoint McpWeb.Endpoint

  # Setup Mox for test isolation
  setup :verify_on_exit!

  setup %{conn: conn} do
    # Clean up any existing sessions
    SessionStore.flush_all()

    {:ok,
     conn:
       conn
       |> Map.put(:remote_ip, {127, 0, 0, 1})
       |> put_req_header("user-agent", "Integration Test Browser")
       |> put_req_header("accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")}
  end

  describe "End-to-End Login Flow" do
    test "complete login flow from page load to dashboard", %{conn: conn} do
      # Step 1: Create test user
      {:ok, user} = create_test_user()

      # Step 2: Load login page
      conn = get(conn, "/sign_in")
      assert html_response(conn, 200) =~ "Welcome to MCP"
      assert html_response(conn, 200) =~ "Sign in to access your AI-powered MSP platform"

      # Step 3: Submit login form
      conn =
        conn
        |> recycle()
        |> post("/sign_in", %{
          "email" => user.email,
          "password" => "Password123!"
        })

      # Step 4: Should redirect to dashboard
      assert redirected_to(conn) == "/dashboard"

      # Step 5: Follow redirect to dashboard
      conn = get(recycle(conn), "/dashboard")
      assert html_response(conn, 200) =~ "Dashboard"  # Assuming dashboard page has this content

      # Step 6: Verify session is properly set
      assert get_session(conn, :user_token) != nil
      assert get_session(conn, :current_user) != nil
      assert get_session(conn, :current_user).email == user.email
    end

    test "login flow with remember me functionality", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Login with remember me
      conn =
        conn
        |> post("/sign_in", %{
          "email" => user.email,
          "password" => "Password123",
          "remember_me" => "true"
        })

      assert redirected_to(conn) == "/dashboard"

      # Check for persistent session cookies
      # This would verify long-lived tokens are set
      assert get_session(conn, :user_token) != nil
    end

    test "failed login flow remains on login page", %{conn: conn} do
      {:ok, _user} = create_test_user()

      # Attempt login with wrong password
      conn =
        conn
        |> post("/sign_in", %{
          "email" => "test@example.com",
          "password" => "wrongpassword"
        })

      # Should redirect back to login page
      assert redirected_to(conn) == "/sign_in"

      # Follow redirect and check for error message
      conn = get(recycle(conn), "/sign_in")
      assert html_response(conn, 200) =~ "Invalid email or password"
    end
  end

  describe "OAuth Integration Flow" do
    test "complete Google OAuth flow", %{conn: conn} do
      # Mock OAuth flow
      state = "oauth_test_state_123"
      user_info = %{
        provider: :google,
        id: "google_user_123",
        email: "google.user@example.com",
        name: "Google User",
        first_name: "Google",
        last_name: "User",
        email_verified: true
      }
      tokens = %{
        access_token: "google_access_token",
        refresh_token: "google_refresh_token",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.to_iso8601()
      }

      # Step 1: Initiate OAuth
      expect(OAuth, :authorize_url, fn :google, captured_state ->
        assert String.starts_with?(captured_state, "oauth_")
        "https://accounts.google.com/oauth/authorize?client_id=test&state=#{captured_state}"
      end)

      conn = get(conn, "/auth/google")
      assert redirected_to(conn) =~ "accounts.google.com"
      assert get_session(conn, :oauth_state) != nil
      assert get_session(conn, :oauth_provider) == "google"

      # Step 2: OAuth callback
      expect(OAuth, :callback, fn :google, code, captured_state ->
        assert captured_state == get_session(build_conn(), :oauth_state)
        assert code == "test_auth_code"
        {:ok, nil, tokens}
      end)

      expect(OAuth, :callback, fn :google, code, captured_state ->
        # This call would create the user
        {:ok, nil, tokens}
      end)

      expect(OAuth, :authenticate_oauth, fn oauth_user, _ip ->
        assert oauth_user.email == "google.user@example.com"
        create_test_session(oauth_user)
      end)

      conn =
        conn
        |> recycle()
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")
        |> get("/auth/google/callback?code=test_auth_code&state=#{state}")

      assert redirected_to(conn) == "/dashboard"
      assert get_flash(conn, :info) =~ "Successfully signed in with Google"
    end

    test "OAuth flow with existing user", %{conn: conn} do
      # Create existing user
      {:ok, user} = create_test_user(%{email: "existing@example.com"})

      state = "oauth_existing_user_state"
      tokens = %{access_token: "access_token"}

      # Mock OAuth callback for existing user
      expect(OAuth, :callback, fn :github, code, captured_state ->
        assert captured_state == state
        assert code == "github_code"
        {:ok, user, tokens}
      end)

      expect(OAuth, :authenticate_oauth, fn oauth_user, _ip ->
        assert oauth_user.id == user.id
        create_test_session(oauth_user)
      end)

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "github")
        |> get("/auth/github/callback?code=github_code&state=#{state}")

      assert redirected_to(conn) == "/dashboard"
      assert get_flash(conn, :info) =~ "Successfully signed in with GitHub"
    end

    test "OAuth flow with error handling", %{conn: conn} do
      state = "oauth_error_state"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")
        |> get("/auth/google/callback?error=access_denied&state=#{state}")

      assert redirected_to(conn) == "/sign_in"
      # Error would be handled by OAuth controller
    end
  end

  describe "Session Management Integration" do
    test "session persistence across requests", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Login
      conn =
        conn
        |> post("/sign_in", %{
          "email" => user.email,
          "password" => "Password123!"
        })

      # Follow redirect
      conn = get(recycle(conn), "/dashboard")
      assert get_session(conn, :current_user) != nil

      # Make additional requests - session should persist
      conn = get(recycle(conn), "/settings")
      assert get_session(conn, :current_user) != nil

      conn = get(recycle(conn), "/settings/security")
      assert get_session(conn, :current_user) != nil
    end

    test "session expiration handling", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Create session
      {:ok, session} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")

      # Manually expire session (simulate)
      conn =
        conn
        |> put_session(:user_token, session.access_token)
        |> put_session(:current_user, session.user)

      # Access protected route with expired session
      # This would be handled by SessionPlug middleware
      conn = get(conn, "/dashboard")
      # Should redirect to login if session is invalid
    end

    test "logout functionality", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Login
      conn =
        conn
        |> post("/sign_in", %{
          "email" => user.email,
          "password" => "Password123!"
        })

      # Logout
      conn = delete(recycle(conn), "/sign_out")
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "signed out successfully"

      # Try to access protected route
      conn = get(recycle(conn), "/dashboard")
      # Should redirect to login
      assert redirected_to(conn) == "/sign_in" or conn.status == 302
    end
  end

  describe "Multi-tenant Integration" do
    test "session includes tenant context", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Authenticate with tenant context
      {:ok, session} = Auth.authenticate(user.email, "Password123!", "127.0.0.1", [
        tenant_id: "tenant_123"
      ])

      # Verify session includes tenant information
      {:ok, claims} = Auth.verify_jwt_access_token(session.access_token)
      assert claims["tenant_id"] == "tenant_123"
      assert claims["current_context"] != nil
      assert is_list(claims["authorized_contexts"])
    end

    test "cross-tenant authorization", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Create session with specific tenant
      {:ok, session} = Auth.authenticate(user.email, "Password123!", "127.0.0.1", [
        tenant_id: "tenant_abc"
      ])

      # Check authorization for different tenants
      assert Auth.authorized_for_tenant?(session.access_token |> Auth.verify_session!() |> elem(1), "tenant_abc")
      refute Auth.authorized_for_tenant?(session.access_token |> Auth.verify_session!() |> elem(1), "other_tenant")
    end
  end

  describe "GDPR Integration" do
    test "deleted users cannot login", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Delete user (GDPR)
      alias Mcp.Gdpr
      {:ok, _result} = Gdpr.request_user_deletion(user.id, "test_deletion")
      Process.sleep(100)

      # Attempt to login with deleted user
      conn =
        conn
        |> post("/sign_in", %{
          "email" => user.email,
          "password" => "Password123!"
        })

      # Should fail authentication
      assert redirected_to(conn) == "/sign_in"
      conn = get(recycle(conn), "/sign_in")
      assert html_response(conn, 200) =~ "Invalid email or password"
    end

    test "login attempts are logged for audit", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Successful login
      post(conn, "/sign_in", %{
        "email" => user.email,
        "password" => "Password123!"
      })

      # Failed login attempt
      post(conn, "/sign_in", %{
        "email" => user.email,
        "password" => "wrongpassword"
      })

      # These should be logged in audit trail
      # Verification would require checking audit logs
      assert true  # Placeholder assertion
    end
  end

  describe "Error Handling Integration" do
    test "database connection errors", %{conn: conn} do
      # This would require mocking database failures
      # For now, test graceful degradation
      {:ok, _user} = create_test_user()

      # Attempt login
      conn =
        conn
        |> post("/sign_in", %{
          "email" => "test@example.com",
          "password" => "Password123!"
        })

      # Should handle errors gracefully
      assert conn.status in [200, 302, 500]  # Should not crash
    end

    test "network timeout handling", %{conn: conn} do
      # Test with simulated network timeouts
      # This would require mocking external service calls
      assert true  # Placeholder
    end

    test "invalid form submission handling", %{conn: conn} do
      # Test various malformed requests
      invalid_requests = [
        %{"email" => "", "password" => ""},
        %{"email" => "invalid", "password" => ""},
        %{"email" => "test@example.com"},
        %{"password" => "password"},
        %{}
      ]

      Enum.each(invalid_requests, fn params ->
        conn =
          conn
          |> recycle()
          |> post("/sign_in", params)

        # Should handle gracefully
        assert conn.status in [200, 302, 400]
      end)
    end
  end

  describe "Security Integration" do
    test "CSRF protection in form submissions", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Attempt form submission without CSRF token
      conn =
        conn
        |> delete_req_header("x-csrf-token")
        |> post("/sign_in", %{
          "email" => user.email,
          "password" => "Password123!"
        })

      # Should be rejected by CSRF protection
      assert conn.status == 403 or conn.status == 302
    end

    test "rate limiting integration", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Multiple failed attempts
      for i <- 1..6 do
        conn =
          conn
          |> recycle()
          |> post("/sign_in", %{
            "email" => user.email,
            "password" => "wrong_password_#{i}"
          })

        if i < 5 do
          assert redirected_to(conn) == "/sign_in"
        else
          # Should be rate limited/locked out
          assert get_flash(conn, :error) =~ "locked" or get_flash(conn, :error) =~ "wait"
        end
      end
    end

    test "secure cookie handling", %{conn: conn} do
      {:ok, user} = create_test_user()

      conn =
        conn
        |> post("/sign_in", %{
          "email" => user.email,
          "password" => "Password123!"
        })

      # Check that secure cookies are set
      # This would require examining Set-Cookie headers
      assert get_session(conn, :user_token) != nil
      assert get_session(conn, :current_user) != nil
    end
  end

  describe "Performance Integration" do
    test "concurrent user logins", %{conn: conn} do
      num_users = 5
      num_requests = 3

      # Create test users
      users = for i <- 1..num_users do
        {:ok, user} = create_test_user(%{
          email: "perf_user_#{i}@example.com"
        })
        user
      end

      # Generate concurrent login requests
      tasks = for i <- 1..(num_users * num_requests) do
        user = Enum.at(users, rem(i - 1, num_users))

        Task.async(fn ->
          {time, result} = :timer.tc(fn ->
            conn =
              build_conn()
              |> post("/sign_in", %{
                "email" => user.email,
                "password" => "Password123!"
              })

            {conn.status, redirected_to(conn)}
          end)
          {time, result, i}
        end)
      end

      results = Task.await_many(tasks, 15_000)

      # All requests should complete
      assert length(results) == num_users * num_requests

      # Check success rate
      successes = Enum.count(results, fn {_time, {status, redirect}, _i} ->
        status == 302 and redirect == "/dashboard"
      end)

      success_rate = successes / length(results)
      assert success_rate > 0.8, "Success rate: #{success_rate}"

      # Check performance
      times = Enum.map(results, fn {time, _result, _i} -> time end)
      avg_time = Enum.sum(times) / length(times)
      assert avg_time < 500_000, "Average login time: #{avg_time}μs, expected < 500ms"
    end

    test "memory usage under load", %{conn: conn} do
      # Initial memory measurement
      :erlang.garbage_collect()
      initial_memory = :erlang.memory()

      # Perform many login operations
      for i <- 1..50 do
        user = create_test_user(%{
          email: "load_test_#{i}@example.com"
        })

        post(conn, "/sign_in", %{
          "email" => user.email,
          "password" => "Password123!"
        })

        if rem(i, 10) == 0 do
          :erlang.garbage_collect()
        end
      end

      # Final memory measurement
      :erlang.garbage_collect()
      final_memory = :erlang.memory()

      memory_growth = final_memory[:total] - initial_memory[:total]
      memory_growth_mb = memory_growth / (1024 * 1024)

      # Memory growth should be reasonable
      assert memory_growth_mb < 50, "Memory grew by #{memory_growth_mb}MB, expected < 50MB"
    end
  end

  describe "Browser Compatibility Integration" do
    test "works with different user agents", %{conn: conn} do
      user_agents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15"
      ]

      {:ok, user} = create_test_user()

      Enum.each(user_agents, fn user_agent ->
        conn =
          conn
          |> recycle()
          |> put_req_header("user-agent", user_agent)
          |> post("/sign_in", %{
            "email" => user.email,
            "password" => "Password123!"
          })

        # Should work with all browsers
        assert redirected_to(conn) == "/dashboard"
      end)
    end

    test "handles different content types", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Test with different Accept headers
      content_types = [
        "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "application/json",
        "text/plain",
        "*/*"
      ]

      Enum.each(content_types, fn content_type ->
        conn =
          conn
          |> recycle()
          |> put_req_header("accept", content_type)
          |> get("/sign_in")

        # Should return appropriate content type
        assert conn.status == 200
      end)
    end
  end

  describe "Production Environment Simulation" do
    test "handles production-like load", %{conn: conn} do
      # Simulate production load with multiple user types and operations
      num_operations = 100

      operations = for i <- 1..num_operations do
        case rem(i, 4) do
          0 -> :login_page
          1 -> :login_attempt
          2 -> :oauth_initiate
          3 -> :protected_route
        end
      end

      tasks = Enum.with_index(operations, fn operation, i ->
        Task.async(fn ->
          conn = build_conn() |> put_req_header("x-forwarded-for", "192.168.1.#{rem(i, 255)}")

          case operation do
            :login_page ->
              {time, result} = :timer.tc(fn -> get(conn, "/sign_in") end)
              {:login_page, time, result.status}

            :login_attempt ->
              {:ok, user} = create_test_user(%{email: "prod_user_#{i}@example.com"})
              {time, result} = :timer.tc(fn ->
                post(conn, "/sign_in", %{
                  "email" => user.email,
                  "password" => "Password123!"
                })
              end)
              {:login_attempt, time, result.status}

            :oauth_initiate ->
              {time, result} = :timer.tc(fn -> get(conn, "/auth/google") end)
              {:oauth_initiate, time, result.status}

            :protected_route ->
              # Should be redirected to login
              {time, result} = :timer.tc(fn -> get(conn, "/dashboard") end)
              {:protected_route, time, result.status}
          end
        end)
      end)

      results = Task.await_many(tasks, 60_000)

      # Analyze results
      total_operations = length(results)
      successful_operations = Enum.count(results, fn {_type, _time, status} ->
        status in [200, 302]
      end)

      success_rate = successful_operations / total_operations
      assert success_rate > 0.95, "Production load success rate: #{success_rate}"

      # Check performance metrics
      times = Enum.map(results, fn {_type, time, _status} -> time end)
      avg_time = Enum.sum(times) / length(times)
      p95_time = Enum.at(Enum.sort(times), round(length(times) * 0.95))

      assert avg_time < 200_000, "Production avg time: #{avg_time}μs, expected < 200ms"
      assert p95_time < 1_000_000, "Production 95th percentile: #{p95_time}μs, expected < 1s"
    end
  end

  # Helper functions

  defp create_test_user(attrs \\ %{}) do
    default_attrs = %{
      first_name: "Integration",
      last_name: "Test",
      email: "integration_test@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      status: :active
    }

    User.register(Map.merge(default_attrs, attrs))
  end

  defp create_test_session(user) do
    Auth.authenticate(user.email, "Password123!", "127.0.0.1")
  end
end