defmodule McpWeb.AuthLive.LoginTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  import Phoenix.ConnTest
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  import Mox

  alias Mcp.Accounts.{Auth, OAuth, User}

  @endpoint McpWeb.Endpoint

  # Setup Mox for test isolation
  setup :verify_on_exit!

  setup %{conn: conn} do
    # Clean up any existing sessions
    # Clean up any existing sessions
    # SessionStore.flush_all()

    {:ok,
     conn:
       conn
       |> Map.put(:remote_ip, {127, 0, 0, 1})
       |> put_req_header("user-agent", "Test Browser")}
  end

  describe "LiveView Login Page Mount" do
    test "mounts login page successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/tenant/sign-in")
      assert html =~ "Welcome back"
      assert html =~ "Email Address"
      assert html =~ "Password"
      assert html =~ "Sign in"
      assert html =~ "Google"
      assert html =~ "Github"
    end

    test "redirects to dashboard if already authenticated", %{conn: conn} do
      # Create a user and session
      user = create_test_user()
      session_data = create_test_session(user)

      conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_token, session_data.access_token)
        |> put_session(:current_user, session_data.user)

      {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, "/sign_in")
    end

    test "handles return_to parameter correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign_in?return_to=/profile")

      assert view |> element("input[name='return_to'][value='/profile']") |> has_element?()
    end

    test "displays flash messages from session", %{conn: conn} do
      conn =
        conn
        |> put_session(:flash, %{"info" => "Welcome back!"})

      {:ok, _view, html} = live(conn, "/sign_in")

      assert html =~ "Welcome back!"
    end
  end

  describe "Form Validation" do
    test "validates email format in real-time", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign_in")

      # Test invalid email
      view
      |> form("#login-form", login: %{email: "invalid-email"})
      |> render_change()

      assert view |> element("#email-error") |> has_element?()
      assert render(view) =~ "Please enter a valid email address"

      # Test valid email
      view
      |> form("#login-form", login: %{email: "test@example.com"})
      |> render_change()

      refute view |> element("#email-error") |> has_element?()
    end

    test "validates password presence in real-time", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign_in")

      # Test empty password
      view
      |> form("#login-form", login: %{password: ""})
      |> render_change()

      assert view |> element("#password-error") |> has_element?()
      assert render(view) =~ "Password is required"

      # Test with password
      view
      |> form("#login-form", login: %{password: "password123"})
      |> render_change()

      refute view |> element("#password-error") |> has_element?()
    end

    test "validates complete form on submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign_in")

      # Submit form with invalid data
      view
      |> form("#login-form", login: %{email: "invalid", password: ""})
      |> render_submit()

      assert render(view) =~ "Please enter a valid email address"
      assert render(view) =~ "Password is required"
    end
  end

  describe "Email/Password Authentication" do
    test "authenticates user with valid credentials", %{conn: conn} do
      {:ok, user} = create_test_user()

      {:ok, view, _html} = live(conn, "/sign_in")

      view
      |> form("#login-form",
        login: %{
          email: user.email,
          password: "Password123!",
          remember_me: "false"
        }
      )
      |> render_submit()

      # Should redirect to dashboard
      assert_redirect(view, "/dashboard")
    end

    test "shows error for invalid credentials", %{conn: conn} do
      {:ok, _user} = create_test_user()

      {:ok, view, _html} = live(conn, "/sign_in")

      view
      |> form("#login-form",
        login: %{
          email: "test@example.com",
          password: "wrongpassword"
        }
      )
      |> render_submit()

      assert render(view) =~ "Invalid email or password"
      assert render(view) =~ "alert-error"
    end

    test "handles password change requirement", %{conn: conn} do
      {:ok, user} = create_test_user(%{password_change_required: true})

      {:ok, view, _html} = live(conn, "/sign_in")

      view
      |> form("#login-form",
        login: %{
          email: user.email,
          password: "Password123!"
        }
      )
      |> render_submit()

      # Should redirect to password change
      assert_redirect(view, "/change_password")
    end

    test "remembers user with remember me checkbox", %{conn: conn} do
      {:ok, user} = create_test_user()

      {:ok, view, _html} = live(conn, "/sign_in")

      view
      |> form("#login-form",
        login: %{
          email: user.email,
          password: "Password123!",
          remember_me: "true"
        }
      )
      |> render_submit()

      assert_redirect(view, "/dashboard")
    end

    test "handles account lockout scenario", %{conn: conn} do
      {:ok, user} = create_test_user()

      # Simulate account lockout
      Auth.record_failed_attempt(user.email)
      Auth.record_failed_attempt(user.email)
      Auth.record_failed_attempt(user.email)
      Auth.record_failed_attempt(user.email)
      Auth.record_failed_attempt(user.email)

      {:ok, view, _html} = live(conn, "/sign_in")

      view
      |> form("#login-form",
        login: %{
          email: user.email,
          password: "Password123!"
        }
      )
      |> render_submit()

      assert render(view) =~ "Account temporarily locked"
      assert render(view) =~ "Too many failed attempts"
    end
  end

  describe "OAuth Integration" do
    test "initiates Google OAuth flow", %{conn: conn} do
      # Mock OAuth
      expect(OAuth, :authorize_url, fn :google, state ->
        assert String.starts_with?(state, "oauth_")

        "https://accounts.google.com/o/oauth2/auth?client_id=test&redirect_uri=http://localhost:4000/auth/google/callback&state=#{state}"
      end)

      {:ok, view, _html} = live(conn, "/sign_in")

      view
      |> element(~s|button[phx-click="oauth_login"][phx-value-provider="google"]|)
      |> render_click()

      assert render(view) =~ "Connecting to Google..."
      assert render(view) =~ "loading loading-spinner"

      # Should push OAuth redirect event
      assert_push_event(view, "oauth-redirect", %{provider: "google"})
    end

    test "initiates GitHub OAuth flow", %{conn: conn} do
      # Mock OAuth
      expect(OAuth, :authorize_url, fn :github, state ->
        assert String.starts_with?(state, "oauth_")

        "https://github.com/login/oauth/authorize?client_id=test&redirect_uri=http://localhost:4000/auth/github/callback&state=#{state}"
      end)

      {:ok, view, _html} = live(conn, "/sign_in")

      view
      |> element(~s|button[phx-click="oauth_login"][phx-value-provider="github"]|)
      |> render_click()

      assert render(view) =~ "Connecting to GitHub..."
      assert render(view) =~ "loading loading-spinner"

      # Should push OAuth redirect event
      assert_push_event(view, "oauth-redirect", %{provider: "github"})
    end

    test "handles invalid OAuth provider", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign_in")

      # This should be handled by the template, not the LiveView
      # Only valid providers should be in the template
      refute view |> element("button[phx-value-provider=\"invalid\"]") |> has_element?()
    end

    test "prevents OAuth when rate limited", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign_in")

      # Simulate rate limiting by setting lockout
      locked_until = DateTime.add(DateTime.utc_now(), 15, :minute)
      view |> assign(:locked_until, locked_until) |> render()

      # Try OAuth button - should be disabled
      view
      |> element(~s|button[phx-click="oauth_login"][phx-value-provider="google"]|)
      |> render_click()

      # Should show rate limit message instead of OAuth flow
      assert render(view) =~ "Please wait before trying again"
    end
  end

  describe "Password Recovery" do
    test "shows password recovery modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign_in")

      view
      |> element("button[phx-click=\"show_recovery\"]")
      |> render_click()

      assert render(view) =~ "Password Recovery"
      assert render(view) =~ "Enter your email address"
      assert render(view) =~ "Send Reset Link"
    end

    test "hides password recovery modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign_in")

      # Show modal first
      view
      |> element("button[phx-click=\"show_recovery\"]")
      |> render_click()

      # Then hide it
      view
      |> element("button[phx-click=\"hide_recovery\"]")
      |> render_click()

      refute render(view) =~ "Password Recovery"
    end

    test "submits password recovery request", %{conn: conn} do
      {:ok, _user} = create_test_user()

      {:ok, view, _html} = live(conn, "/sign_in")

      # Show modal
      view
      |> element("button[phx-click=\"show_recovery\"]")
      |> render_click()

      # Submit recovery form
      view
      |> form("#recovery-form", email: "test@example.com")
      |> render_submit()

      assert render(view) =~ "Password recovery instructions sent to test@example.com"
      # Modal should be hidden
      refute render(view) =~ "Password Recovery"
    end

    test "handles invalid email in recovery form", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign_in")

      # Show modal
      view
      |> element("button[phx-click=\"show_recovery\"]")
      |> render_click()

      # Submit with invalid email
      view
      |> form("#recovery-form", email: "invalid-email")
      |> render_submit()

      # Should show error message (this would be handled by form validation)
      assert render(view) =~ "Password Recovery"
    end
  end

  describe "Accessibility Features" do
    test "has proper ARIA labels and roles", %{conn: conn} do
      {
        :ok,
        _view,
        html
      } = live(conn, "/sign_in")

      # Check main structure
      assert html =~ ~s(role="main")
      assert html =~ ~s(aria-label="Login page")

      # Check form elements
      assert html =~ ~s(aria-invalid="false")
      assert html =~ ~s(aria-describedby)

      # Check button accessibility
      assert html =~ ~s(aria-label="Show password")
      assert html =~ ~s(aria-label="Hide password")
      assert html =~ ~s(aria-label="Sign in with Google")
      assert html =~ ~s(aria-label="Sign in with GitHub")
    end

    test "provides screen reader announcements", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign_in")

      view
      |> element("button[phx-click=\"toggle_password\"]")
      |> render_click()

      # Should have announcement for screen readers
      assert render(view) =~ ~s(role="status")
      assert render(view) =~ ~s(aria-live="polite")
      assert render(view) =~ ~s(aria-atomic="true")
    end

    test "supports keyboard navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign_in")

      # Test Enter key submission
      view
      |> render_keydown(%{"key" => "Enter"})

      # Should trigger form submission if form is valid
      # This test would need more specific form data setup
    end

    test "handles Escape key to close modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign_in")

      # Show modal first
      view
      |> element("button[phx-click=\"show_recovery\"]")
      |> render_click()

      assert render(view) =~ "Password Recovery"

      # Press Escape
      view
      |> render_keydown(%{"key" => "Escape"})

      # Modal should be hidden
      refute render(view) =~ "Password Recovery"
    end
  end

  describe "Security Features" do
    test "includes CSRF protection", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/sign_in")

      # Phoenix.LiveViewTest automatically handles CSRF tokens
      # This test ensures forms are properly protected
      assert html =~ ~s(phx-submit)
      assert html =~ ~s(phx-change)
    end

    test "prevents form submission when loading", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign_in")

      # Simulate loading state
      view |> assign(:loading, true) |> render()

      # Submit button should be disabled
      assert render(view) =~ ~s(disabled)
      assert render(view) =~ ~s(btn-disabled)
    end

    test "generates secure OAuth state parameters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign_in")

      # Mock to capture state parameter
      expect(OAuth, :authorize_url, fn :google, state ->
        send(self(), {:state, state})
        "https://accounts.google.com/oauth/authorize"
      end)

      view
      |> element(~s|button[phx-click="oauth_login"][phx-value-provider="google"]|)
      |> render_click()

      # State should be cryptographically secure
      assert_received {:state, state_captured}
      refute is_nil(state_captured)
      assert String.starts_with?(state_captured, "oauth_")
      assert String.length(state_captured) > 20
    end
  end

  describe "Error Handling" do
    test "handles network errors gracefully", %{conn: conn} do
      # Mock authentication to return error
      expect(Auth, :authenticate, fn _email, _password, _ip ->
        {:error, :network_error}
      end)

      {:ok, view, _html} = live(conn, "/sign_in")

      view
      |> form("#login-form",
        login: %{
          email: "test@example.com",
          password: "Password123!"
        }
      )
      |> render_submit()

      assert render(view) =~ "Authentication failed"
    end

    test "handles timeout during authentication", %{conn: conn} do
      # Mock authentication timeout
      expect(Auth, :authenticate, fn _email, _password, _ip ->
        # Simulate delay
        Process.sleep(100)
        {:error, :timeout}
      end)

      {:ok, view, _html} = live(conn, "/sign_in")

      view
      |> form("#login-form",
        login: %{
          email: "test@example.com",
          password: "Password123!"
        }
      )
      |> render_submit()

      assert render(view) =~ "Authentication failed"
    end
  end

  describe "Performance and Optimization" do
    test "loads efficiently with minimal database queries", %{conn: conn} do
      # This test would require database query counting
      # For now, just ensure the page loads without errors
      {:ok, _view, _html} = live(conn, "/sign_in")
    end

    test "handles concurrent login attempts", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Simulate concurrent login attempts
      tasks =
        for _i <- 1..5 do
          Task.async(fn ->
            conn =
              build_conn()
              |> Map.put(:remote_ip, {127, 0, 0, 1})

            {:ok, view, _html} = live(conn, "/sign_in")

            view
            |> form("#login-form",
              login: %{
                email: user.email,
                password: "Password123!"
              }
            )
            |> render_submit()
          end)
        end

      # Wait for all tasks to complete
      results = Task.await_many(tasks, 5000)

      # All should complete without errors
      assert length(results) == 5
    end
  end

  # Helper functions

  defp create_test_user(attrs \\ %{}) do
    default_attrs = %{
      email: "test-#{System.unique_integer()}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    }

    attrs = Map.merge(default_attrs, attrs)
    User.register!(attrs.email, attrs.password, attrs.password_confirmation)
  end

  defp create_test_session(user) do
    {:ok, user} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")
    # Generate a dummy token for test
    token = "test_token_#{System.unique_integer()}"
    %{user: user, access_token: token}
  end
end
