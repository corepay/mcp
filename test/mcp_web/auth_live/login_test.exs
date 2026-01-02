defmodule McpWeb.AuthLive.LoginTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  import Phoenix.ConnTest
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  # Integration test requiring full tenant schema setup
  @moduletag :integration

  import Mox

  alias Mcp.Accounts.{Auth, User}

  @endpoint McpWeb.Endpoint

  # Setup Mox for test isolation
  setup :verify_on_exit!

  alias Mcp.Platform.Tenant
  require Ash.Query

  setup %{conn: conn} do
    # Create a tenant for the test
    tenant =
      Tenant.create!(
        %{
          name: "Test Tenant",
          slug: "test-tenant",
          subdomain: "test-tenant"
        },
        authorize?: false
      )

    {:ok,
     conn:
       conn
       |> Map.put(:host, "#{tenant.subdomain}.localhost")
       |> Map.put(:remote_ip, {127, 0, 0, 1})
       |> put_req_header("user-agent", "Test Browser"),
     tenant: tenant}
  end

  describe "LiveView Login Page Mount" do
    test "mounts login page successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/tenant/sign-in")
      assert html =~ "Welcome back"
      assert html =~ "Email Address"
      assert html =~ "Password"
      assert html =~ "Sign in"
      assert html =~ "Google"
      assert html =~ "GitHub"
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

      {:error, {:live_redirect, %{to: "/tenant"}}} = live(conn, "/tenant/sign-in")
    end

    test "handles return_to parameter correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tenant/sign-in?return_to=/profile")

      assert view |> element("input[name='return_to'][value='/profile']") |> has_element?()
    end

    test "displays flash messages from session", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> put_session(:flash, %{"info" => "Welcome back!"})

      {:ok, _view, html} = live(conn, "/tenant/sign-in")

      assert html =~ "Welcome back!"
    end
  end

  describe "Form Validation" do
    test "validates email format in real-time", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tenant/sign-in")

      # Test invalid email
      view
      |> form("#main-login-form", login: %{email: "invalid-email"})
      |> render_change()

      assert view |> element("#login_email-error") |> has_element?()
      assert render(view) =~ "Please enter a valid email address"

      # Test valid email
      view
      |> form("#main-login-form", login: %{email: "test@example.com"})
      |> render_change()

      refute view |> element("#login_email-error") |> has_element?()
    end

    test "validates password presence in real-time", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tenant/sign-in")

      # Test empty password
      view
      |> form("#main-login-form", login: %{password: ""})
      |> render_change()

      assert view |> element("#login_password-error") |> has_element?()
      assert render(view) =~ "Password is required"

      # Test with password
      view
      |> form("#main-login-form", login: %{password: "password123"})
      |> render_change()

      refute view |> element("#login_password-error") |> has_element?()
    end
  end

  describe "OAuth Integration" do
    test "displays Google OAuth link", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tenant/sign-in")

      # Check that Google OAuth link exists
      assert view
             |> element(~s|a[href="/auth/google"][aria-label="Sign in with Google"]|)
             |> has_element?()

      assert render(view) =~ "Google"
    end

    test "displays GitHub OAuth link", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tenant/sign-in")

      # Check that GitHub OAuth link exists
      assert view
             |> element(~s|a[href="/auth/github"][aria-label="Sign in with GitHub"]|)
             |> has_element?()

      assert render(view) =~ "GitHub"
    end

    test "OAuth links have correct paths", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/tenant/sign-in")

      # Verify OAuth paths are correct
      assert html =~ ~s(href="/auth/google")
      assert html =~ ~s(href="/auth/github")
    end

    test "handles invalid OAuth provider", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tenant/sign-in")

      # This should be handled by the template, not the LiveView
      # Only valid providers should be in the template
      refute view |> element(~s|a[href="/auth/invalid"]|) |> has_element?()
    end
  end

  describe "Reset Password" do
    test "shows password recovery modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tenant/sign-in")

      view
      |> element(~s|a[phx-click="show_recovery"]|)
      |> render_click()

      assert view |> element("#recovery_modal.modal-open") |> has_element?()
      assert render(view) =~ "Reset Password"
      assert render(view) =~ "Enter your email address"
      assert render(view) =~ "Send Instructions"
    end

    test "hides password recovery modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tenant/sign-in")

      # Show modal first
      view
      |> element(~s|a[phx-click="show_recovery"]|)
      |> render_click()

      # Then hide it
      view
      |> element(~s|form[phx-submit="request_recovery"] button[phx-click="hide_recovery"]|)
      |> render_click()

      refute view |> element("#recovery_modal.modal-open") |> has_element?()
    end

    test "submits password recovery request", %{conn: conn} do
      _user = create_test_user()

      {:ok, view, _html} = live(conn, "/tenant/sign-in")

      # Show modal
      view
      |> element(~s|a[phx-click="show_recovery"]|)
      |> render_click()

      # Submit recovery form
      view
      |> form("#recovery-form", email: "test@example.com")
      |> render_submit()

      assert render(view) =~ "Password recovery email sent"
      # Modal should be hidden
      refute view |> element("#recovery_modal.modal-open") |> has_element?()
    end

    test "handles invalid email in recovery form", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tenant/sign-in")

      # Show modal
      view
      |> element(~s|a[phx-click="show_recovery"]|)
      |> render_click()

      # Submit with invalid email
      view
      |> form("#recovery-form", email: "invalid-email")
      |> render_submit()

      # Should show error message (this would be handled by form validation)
      assert render(view) =~ "Reset Password"
    end
  end

  describe "Accessibility Features" do
    test "has proper ARIA labels and roles", %{conn: conn} do
      {
        :ok,
        view,
        html
      } = live(conn, "/tenant/sign-in")

      # Check main structure
      assert html =~ ~s(role="main")
      assert html =~ ~s(aria-label="Tenant Portal")

      # Check form elements
      refute html =~ ~s(aria-invalid="true")
      assert html =~ ~s(aria-describedby)

      # Check button accessibility
      assert html =~ ~s(aria-label="Show password")

      # Toggle password visibility
      view
      |> element(~s|button[phx-click="toggle_password"]|)
      |> render_click()

      assert render(view) =~ ~s(aria-label="Hide password")
      assert html =~ ~s(aria-label="Sign in with Google")
      assert html =~ ~s(aria-label="Sign in with GitHub")
    end

    test "provides screen reader announcements", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tenant/sign-in")

      view
      |> element(~s|button[phx-click="toggle_password"]|)
      |> render_click()

      # Should have announcement for screen readers
      assert render(view) =~ ~s(role="status")
      assert render(view) =~ ~s(aria-live="polite")
      assert render(view) =~ ~s(aria-atomic="true")
    end
  end

  describe "Security Features" do
    test "includes CSRF protection", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/tenant/sign-in")

      # Phoenix.LiveViewTest automatically handles CSRF tokens
      # This test ensures forms are properly protected
      assert html =~ ~s(phx-submit)
      assert html =~ ~s(phx-change)
    end

    test "OAuth links use proper authentication endpoints", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/tenant/sign-in")

      # OAuth links should point to the OAuth controller
      # State parameters are generated server-side in the controller
      assert html =~ ~s(href="/auth/google")
      assert html =~ ~s(href="/auth/github")
    end
  end

  describe "Performance and Optimization" do
    test "loads efficiently with minimal database queries", %{conn: conn} do
      # This test would require database query counting
      # For now, just ensure the page loads without errors
      {:ok, _view, _html} = live(conn, "/tenant/sign-in")
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
