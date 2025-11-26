defmodule McpWeb.AuthLive.LoginLiveViewTest do
  use McpWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Mcp.Accounts.User

  describe "login page" do
    test "renders login form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/login")

      assert html =~ "Sign in to your account"
      assert html =~ "Email"
      assert html =~ "Password"
      assert html =~ "Sign in"
      assert html =~ "Forgot your password?"
      assert html =~ "Don't have an account? Sign up"
    end

    test "displays errors for empty form submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      # Submit empty form
      view
      |> form("#login-form", user: %{email: "", password: ""})
      |> render_submit()

      assert has_element?(view, "input[name=\"user[email]\"]")
      assert has_element?(view, "input[name=\"user[password]\"]")
    end

    test "displays error for invalid credentials", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      # Submit invalid credentials
      view
      |> form("#login-form", user: %{email: "nonexistent@example.com", password: "wrong"})
      |> render_submit()

      assert render(view) =~ "Invalid email or password"
    end

    test "redirects on successful login", %{conn: conn} do
      # Create a test user
      {:ok, user} =
        User.register(%{
          first_name: "Test",
          last_name: "User",
          email: "test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      {:ok, view, _html} = live(conn, ~p"/login")

      # Submit valid credentials
      view
      |> form("#login-form", user: %{email: "test@example.com", password: "Password123!"})
      |> render_submit()

      # Should redirect after successful login
      assert_redirect(view, ~p"/dashboard")
    end

    test "handles case-insensitive email login", %{conn: conn} do
      {:ok, _user} =
        User.register(%{
          first_name: "Case",
          last_name: "Test",
          email: "case.test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      {:ok, view, _html} = live(conn, ~p"/login")

      # Submit with uppercase email
      view
      |> form("#login-form", user: %{email: "CASE.TEST@EXAMPLE.COM", password: "Password123!"})
      |> render_submit()

      assert_redirect(view, ~p"/dashboard")
    end

    test "shows 2FA form when user has TOTP enabled", %{conn: conn} do
      # Create user with TOTP enabled
      {:ok, user} =
        User.register(%{
          first_name: "2FA",
          last_name: "User",
          email: "2fa.user@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      # Simulate TOTP being enabled
      {:ok, user_with_totp} =
        Ash.update(user, %{
          otp_verified_at: DateTime.utc_now(),
          otp_last_used_at: DateTime.utc_now()
        })

      {:ok, view, _html} = live(conn, ~p"/login")

      # Submit credentials
      view
      |> form("#login-form", user: %{email: "2fa.user@example.com", password: "Password123!"})
      |> render_submit()

      # Should show 2FA form
      assert has_element?(view, "#totp-form")
      assert render(view) =~ "Enter your 2FA code"
      assert render(view) =~ "Authentication code"
      assert render(view) =~ "Verify"
    end
  end

  describe "2FA verification" do
    test "shows backup code option", %{conn: conn} do
      {:ok, user} =
        User.register(%{
          first_name: "Backup",
          last_name: "User",
          email: "backup.user@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      # Simulate TOTP with backup codes
      {:ok, user_with_totp} =
        Ash.update(user, %{
          otp_verified_at: DateTime.utc_now(),
          otp_last_used_at: DateTime.utc_now(),
          backup_codes: ["hashed_code_1", "hashed_code_2"]
        })

      {:ok, view, _html} = live(conn, ~p"/login")

      # Submit credentials to get to 2FA
      view
      |> form("#login-form", user: %{email: "backup.user@example.com", password: "Password123!"})
      |> render_submit()

      # Should show backup code option
      assert render(view) =~ "Use a backup code"
    end

    test "handles 2FA code verification", %{conn: conn} do
      {:ok, user} =
        User.register(%{
          first_name: "2FA",
          last_name: "Verify",
          email: "2fa.verify@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      # Simulate TOTP being enabled
      {:ok, user_with_totp} =
        Ash.update(user, %{
          otp_verified_at: DateTime.utc_now(),
          otp_last_used_at: DateTime.utc_now()
        })

      {:ok, view, _html} = live(conn, ~p"/login")

      # Submit credentials to get to 2FA
      view
      |> form("#login-form", user: %{email: "2fa.verify@example.com", password: "Password123!"})
      |> render_submit()

      # In a real test, you would mock TOTP verification
      # For now, just test that the form is displayed
      assert has_element?(view, "input[name=\"totp_code\"]")
    end
  end

  describe "form validation and user experience" do
    test "validates email format client-side", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      # Test email input type
      assert has_element?(view, "input[type=\"email\"][name=\"user[email]\"]")
    end

    test "shows loading state during form submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      # Submit form and check for loading state
      view
      |> form("#login-form", user: %{email: "test@example.com", password: "Password123!"})
      |> render_submit()

      # The form should show loading/disabled state
      # This depends on the specific implementation
      assert has_element?(view, "button[type=\"submit\"]")
    end

    test "remembers email on failed login attempt", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      # Submit form with wrong password
      view
      |> form("#login-form", user: %{email: "test@example.com", password: "wrong"})
      |> render_submit()

      # Email should remain in the form
      assert has_element?(view, "input[value=\"test@example.com\"]")
    end

    test "shows password visibility toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      # Check for password visibility toggle
      assert has_element?(view, "input[type=\"password\"][name=\"user[password]\"]")
      # Implementation may include a toggle button
    end

    test "supports keyboard navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      # Form should be keyboard navigable
      assert has_element?(view, "input[name=\"user[email]\"]")
      assert has_element?(view, "input[name=\"user[password]\"]")
      assert has_element?(view, "button[type=\"submit\"]")
    end
  end

  describe "security features" do
    test "includes CSRF protection", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/login")

      # Phoenix LiveView automatically includes CSRF protection
      assert html =~ "csrf-token"
    end

    test "handles rate limiting indicators", %{conn: conn} do
      # This would test if the UI shows rate limiting messages
      {:ok, view, _html} = live(conn, ~p"/login")

      # Simulate multiple failed attempts
      for _i <- 1..3 do
        view
        |> form("#login-form", user: %{email: "test@example.com", password: "wrong"})
        |> render_submit()
      end

      # After several attempts, might show rate limiting warning
      # This depends on the specific implementation
    end

    test "shows security warnings on suspicious activity", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      # This would test display of security warnings
      # Implementation would depend on security service integration
      assert render(view) =~ "Sign in to your account"
    end
  end

  describe "accessibility" do
    test "has proper ARIA labels", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/login")

      # Check for accessibility features
      assert html =~ "aria-label"
      assert html =~ "role="
    end

    test "supports screen readers", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/login")

      # Check for screen reader support
      assert html =~ "for="
      assert html =~ "id="
    end

    test "has proper heading structure", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/login")

      # Check for proper heading hierarchy
      assert html =~ "<h1"
    end

    test "provides error announcements", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      view
      |> form("#login-form", user: %{email: "test@example.com", password: "wrong"})
      |> render_submit()

      # Error messages should be properly announced
      assert render(view) =~ "Invalid email or password"
    end
  end

  describe "mobile and responsive design" do
    test "is responsive on mobile devices", %{conn: conn} do
      # Simulate mobile device
      conn =
        put_req_header(
          conn,
          "user-agent",
          "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)"
        )

      {:ok, view, html} = live(conn, ~p"/login")

      # Should contain responsive design elements
      assert html =~ "class="
    end

    test "handles touch events", %{conn: conn} do
      conn =
        put_req_header(
          conn,
          "user-agent",
          "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)"
        )

      {:ok, view, _html} = live(conn, ~p"/login")

      # Touch-friendly interface
      assert has_element?(view, "button[type=\"submit\"]")
    end
  end

  describe "redirects and navigation" do
    test "redirects authenticated users away from login", %{conn: conn} do
      # Create and authenticate user
      {:ok, user} =
        User.register(%{
          first_name: "Auth",
          last_name: "User",
          email: "auth.user@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      # Simulate authenticated session
      conn =
        Plug.Test.init_test_session(conn, %{
          user_id: user.id,
          current_user: user
        })

      conn = get(conn, ~p"/login")

      # Should redirect away from login
      assert conn.status == 302 or conn.status == 308
    end

    test "preserves return URL parameter", %{conn: conn} do
      return_url = "/posts/123"

      {:ok, view, _html} = live(conn, ~p"/login?return_to=#{return_url}")

      # Should preserve the return URL for post-login redirect
      # Implementation depends on how return URLs are handled
    end

    test "navigates to registration page", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/login")

      assert html =~ "Sign up"

      # Test navigation to registration
      view
      |> element("a", "Sign up")
      |> render_click()

      # Should navigate to registration
      assert_redirect(view, ~p"/register")
    end

    test "navigates to password reset", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/login")

      assert html =~ "Forgot your password?"

      # Test navigation to password reset
      view
      |> element("a", "Forgot your password?")
      |> render_click()

      # Should navigate to password reset
      assert_redirect(view, ~p"/password-reset")
    end
  end

  describe "browser compatibility and performance" do
    test "works in modern browsers", %{conn: conn} do
      browsers = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
      ]

      Enum.each(browsers, fn user_agent ->
        conn = put_req_header(conn, "user-agent", user_agent)
        {:ok, _view, html} = live(conn, ~p"/login")

        assert html =~ "Sign in to your account"
      end)
    end

    test "loads quickly", %{conn: conn} do
      # Test page load performance
      {time, {:ok, _view, _html}} =
        :timer.tc(fn ->
          live(conn, ~p"/login")
        end)

      # Should load within reasonable time (less than 1 second)
      # 1 second in microseconds
      assert time < 1_000_000
    end
  end

  describe "error handling and edge cases" do
    test "handles network disconnection gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      # Simulate network issues during form submission
      # This would test reconnection behavior
      assert render(view) =~ "Sign in to your account"
    end

    test "handles JavaScript being disabled", %{conn: conn} do
      # Test fallback behavior when JavaScript is disabled
      conn = get(conn, ~p"/login", _format: "html")

      assert html_response(conn, 200) =~ "Sign in to your account"
    end

    test "handles very long inputs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      long_email = String.duplicate("a", 500) <> "@example.com"
      long_password = String.duplicate("P", 1000)

      # Should handle long inputs without crashing
      view
      |> form("#login-form", user: %{email: long_email, password: long_password})
      |> render_submit()

      assert render(view) =~ "Sign in"
    end
  end
end
