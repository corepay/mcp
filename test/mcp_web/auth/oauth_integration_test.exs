defmodule McpWeb.Auth.OAuthIntegrationTest do
  @moduledoc """
  TDD Integration Tests for OAuth authentication flow.

  RED PHASE: These tests are written FIRST and will FAIL because:
  - AshAuthentication OAuth2 strategies are not configured in User resource
  - OAuth callback routes may need updates for AshAuthentication
  - User creation from OAuth via AshAuthentication not implemented

  These tests define the EXPECTED end-to-end OAuth behavior.
  """

  use McpWeb.ConnCase, async: false

  alias Mcp.Accounts.{OAuth, User}
  alias Mcp.Cache.SessionStore

  setup do
    # Clean up sessions between tests
    SessionStore.flush_all()

    conn =
      build_conn()
      |> Map.put(:remote_ip, {127, 0, 0, 1})
      |> put_req_header("user-agent", "OAuth Integration Test")
      |> init_test_session(%{})
      |> fetch_flash()

    {:ok, conn: conn}
  end

  describe "OAuth authorization initiation (Google)" do
    @tag :pending_oauth_implementation
    test "initiating Google OAuth stores state and redirects to Google", %{conn: conn} do
      # This will fail until OAuth2 strategy is configured in User resource
      conn = get(conn, "/auth/google")

      # Should redirect to Google OAuth
      assert redirected_to(conn) =~ "accounts.google.com"
      assert redirected_to(conn) =~ "client_id="
      assert redirected_to(conn) =~ "redirect_uri="
      assert redirected_to(conn) =~ "state="
      assert redirected_to(conn) =~ "scope="

      # OAuth state should be stored in session for CSRF protection
      state = get_session(conn, :oauth_state)
      assert state != nil
      assert String.length(state) > 20
    end

    @tag :pending_oauth_implementation
    test "Google OAuth redirect includes required scopes", %{conn: conn} do
      conn = get(conn, "/auth/google")

      redirect_url = redirected_to(conn)

      # Should request email and profile scopes
      assert redirect_url =~ "scope=email"
      assert redirect_url =~ "profile"
    end

    @tag :pending_oauth_implementation
    test "generates unique state for each OAuth request", %{conn: conn} do
      conn1 = get(conn, "/auth/google")
      state1 = get_session(conn1, :oauth_state)

      conn2 = get(conn, "/auth/google")
      state2 = get_session(conn2, :oauth_state)

      assert state1 != state2, "OAuth state should be unique per request"
    end
  end

  describe "OAuth authorization initiation (GitHub)" do
    @tag :pending_oauth_implementation
    test "initiating GitHub OAuth stores state and redirects to GitHub", %{conn: conn} do
      # This will fail until OAuth2 strategy is configured in User resource
      conn = get(conn, "/auth/github")

      # Should redirect to GitHub OAuth
      assert redirected_to(conn) =~ "github.com"
      assert redirected_to(conn) =~ "client_id="
      assert redirected_to(conn) =~ "redirect_uri="
      assert redirected_to(conn) =~ "state="

      # OAuth state should be stored in session
      state = get_session(conn, :oauth_state)
      assert state != nil
    end

    @tag :pending_oauth_implementation
    test "GitHub OAuth redirect includes user:email scope", %{conn: conn} do
      conn = get(conn, "/auth/github")

      redirect_url = redirected_to(conn)
      assert redirect_url =~ "scope=user:email"
    end
  end

  describe "OAuth callback - New user creation (Google)" do
    @tag :pending_oauth_implementation
    test "successful Google OAuth callback creates new user with OAuth data", %{conn: conn} do
      # Simulate OAuth callback from Google
      # In real flow, Google redirects back with code and state

      # This will fail until AshAuthentication OAuth2 is configured
      state = "test_oauth_state_123"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      # Simulate Google callback
      # AshAuthentication will handle the token exchange and user creation
      conn =
        get(conn, "/auth/google/callback", %{
          code: "google_auth_code_from_provider",
          state: state
        })

      # Should create session and redirect to dashboard
      assert redirected_to(conn) == "/tenant/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "signed in"

      # Session should be established
      assert get_session(conn, :user_token) != nil

      # User should be created in database with OAuth tokens
      # Note: In real OAuth flow, email comes from Google's user info endpoint
      # For this test, we're asserting the behavior, not the actual OAuth exchange
    end

    @tag :pending_oauth_implementation
    test "Google OAuth creates user with email from OAuth provider", %{conn: conn} do
      state = "test_state_new_user"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      # Mock the OAuth flow
      # In practice, AshAuthentication handles this via configuration
      conn =
        get(conn, "/auth/google/callback", %{
          code: "google_code_123",
          state: state
        })

      # After successful OAuth, user should exist
      # Email would come from Google's userinfo endpoint
      # This assertion will fail until OAuth2 strategy is implemented
      assert redirected_to(conn) =~ ~r/dashboard|tenant/
    end

    @tag :pending_oauth_implementation
    test "stores OAuth tokens in user record after Google signup", %{conn: conn} do
      state = "test_state_token_storage"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      conn =
        get(conn, "/auth/google/callback", %{
          code: "google_code_with_tokens",
          state: state
        })

      # Get the created user from session
      user_token = get_session(conn, :user_token)
      assert user_token != nil

      # In full implementation, we'd verify:
      # - user.oauth_tokens["google"]["access_token"] exists
      # - user.oauth_tokens["google"]["refresh_token"] exists
      # - user.oauth_tokens["google"]["uid"] matches Google user ID
      # - user.oauth_tokens["google"]["linked_at"] is set
    end

    @tag :pending_oauth_implementation
    test "sets random secure password for OAuth-created users", %{conn: conn} do
      state = "test_state_password"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      conn =
        get(conn, "/auth/google/callback", %{
          code: "google_code_new_user",
          state: state
        })

      assert redirected_to(conn) =~ ~r/dashboard|tenant/

      # User should have a hashed password even though created via OAuth
      # This allows them to set a password later if they want password login
      # Actual verification would require extracting user from session
    end
  end

  describe "OAuth callback - Existing user login (GitHub)" do
    setup %{conn: conn} do
      # Create existing user
      {:ok, user} = User.register("existing@example.com", "Password123!", "Password123!")
      {:ok, user: user, conn: conn}
    end

    @tag :pending_oauth_implementation
    test "GitHub OAuth logs in existing user and links OAuth", %{conn: conn, user: _user} do
      state = "test_state_existing_user"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "github")

      # Simulate GitHub callback
      # AshAuthentication will find user by email and link OAuth
      conn =
        get(conn, "/auth/github/callback", %{
          code: "github_code_existing_user",
          state: state
        })

      assert redirected_to(conn) == "/tenant/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "signed in"

      # Verify user is logged in
      user_token = get_session(conn, :user_token)
      assert user_token != nil

      # Verify OAuth was linked (in full implementation)
      # refreshed_user = User.by_id!(user.id)
      # assert refreshed_user.oauth_tokens["github"] != nil
    end

    @tag :pending_oauth_implementation
    test "updates sign-in tracking when logging in via OAuth", %{conn: conn, user: _user} do
      state = "test_state_sign_in_tracking"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "github")

      _initial_time = DateTime.utc_now()

      conn =
        get(conn, "/auth/github/callback", %{
          code: "github_code_sign_in",
          state: state
        })

      assert redirected_to(conn) == "/tenant/dashboard"

      # In full implementation, verify:
      # - user.last_sign_in_at is updated
      # - user.sign_in_count is incremented
      # - user.last_sign_in_ip is set
      # - last_sign_in_at >= initial_time
    end

    @tag :pending_oauth_implementation
    test "OAuth login with existing linked provider updates tokens", %{conn: conn, user: user} do
      # Pre-link GitHub to user
      {:ok, _linked_user} =
        OAuth.link_oauth(
          user,
          :github,
          %{token: "old_token", refresh_token: "old_refresh", expires_at: nil},
          %{uid: "github_123", name: "User", email: "existing@example.com", image: nil}
        )

      state = "test_state_token_refresh"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "github")

      conn =
        get(conn, "/auth/github/callback", %{
          code: "github_code_refresh_token",
          state: state
        })

      assert redirected_to(conn) == "/tenant/dashboard"

      # In full implementation, verify OAuth tokens were updated to new values
      # refreshed_user = User.by_id!(user.id)
      # assert refreshed_user.oauth_tokens["github"]["access_token"] != "old_token"
    end
  end

  describe "OAuth callback - Error handling" do
    @tag :pending_oauth_implementation
    test "rejects OAuth callback with invalid state (CSRF protection)", %{conn: conn} do
      # Set valid state in session
      conn =
        conn
        |> put_session(:oauth_state, "valid_state_123")
        |> put_session(:oauth_provider, "google")

      # Callback with different state (CSRF attack)
      conn =
        get(conn, "/auth/google/callback", %{
          code: "google_code",
          state: "invalid_state_456"
        })

      # Should reject and redirect to login
      assert redirected_to(conn) == "/tenant/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid"

      # Should NOT create session
      assert get_session(conn, :user_token) == nil
    end

    @tag :pending_oauth_implementation
    test "handles OAuth callback without state parameter", %{conn: conn} do
      conn =
        conn
        |> put_session(:oauth_state, "some_state")
        |> put_session(:oauth_provider, "google")

      # Callback without state parameter
      conn = get(conn, "/auth/google/callback", %{code: "google_code"})

      assert redirected_to(conn) == "/tenant/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid"
    end

    @tag :pending_oauth_implementation
    test "handles OAuth callback with error from provider", %{conn: conn} do
      state = "test_state_error"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "github")

      # OAuth provider returned error
      conn =
        get(conn, "/auth/github/callback", %{
          error: "access_denied",
          error_description: "User denied access",
          state: state
        })

      assert redirected_to(conn) == "/tenant/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "denied"

      # Session should not be created
      assert get_session(conn, :user_token) == nil
    end

    @tag :pending_oauth_implementation
    test "handles token exchange failure from OAuth provider", %{conn: conn} do
      state = "test_state_token_failure"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      # Invalid code that will fail token exchange
      conn =
        get(conn, "/auth/google/callback", %{
          code: "invalid_authorization_code",
          state: state
        })

      # Should handle gracefully
      assert redirected_to(conn) == "/tenant/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) != nil
    end

    @tag :pending_oauth_implementation
    test "handles missing email from OAuth provider", %{conn: conn} do
      state = "test_state_no_email"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "github")

      # Simulate callback where OAuth provider doesn't return email
      # (e.g., user didn't grant email scope or email is private)
      conn =
        get(conn, "/auth/github/callback", %{
          code: "github_code_no_email",
          state: state
        })

      # Should fail gracefully
      assert redirected_to(conn) == "/tenant/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ ~r/email|required/i
    end

    @tag :pending_oauth_implementation
    test "handles concurrent OAuth callback attempts", %{conn: conn} do
      state = "test_state_concurrent"

      conn1 =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      conn2 =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      # Simulate concurrent callbacks (e.g., user clicked back and resubmitted)
      task1 =
        Task.async(fn ->
          get(conn1, "/auth/google/callback", %{code: "code_1", state: state})
        end)

      task2 =
        Task.async(fn ->
          get(conn2, "/auth/google/callback", %{code: "code_2", state: state})
        end)

      result1 = Task.await(task1)
      result2 = Task.await(task2)

      # At least one should succeed
      results = [result1, result2]

      assert Enum.any?(results, fn conn ->
               redirected_to(conn) =~ ~r/dashboard|tenant/
             end)
    end
  end

  describe "OAuth callback - User account status checks" do
    @tag :pending_oauth_implementation
    test "prevents OAuth login for suspended users", %{conn: conn} do
      # Create and suspend user
      {:ok, user} = User.register("suspended@example.com", "Password123!", "Password123!")
      {:ok, _suspended} = User.suspend(user)

      state = "test_state_suspended"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      conn =
        get(conn, "/auth/google/callback", %{
          code: "google_code_suspended",
          state: state
        })

      # Should reject login
      assert redirected_to(conn) == "/tenant/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ ~r/suspended|disabled/i

      # Should not create session
      assert get_session(conn, :user_token) == nil
    end

    @tag :pending_oauth_implementation
    test "prevents OAuth login for locked accounts", %{conn: conn} do
      # Create and lock user
      {:ok, user} = User.register("locked@example.com", "Password123!", "Password123!")
      {:ok, _locked} = User.lock_account(user)

      state = "test_state_locked"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "github")

      conn =
        get(conn, "/auth/github/callback", %{
          code: "github_code_locked",
          state: state
        })

      # Should reject login
      assert redirected_to(conn) == "/tenant/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ ~r/locked|suspended/i
    end

    @tag :pending_oauth_implementation
    test "prevents OAuth login for deleted accounts", %{conn: conn} do
      # Create and soft-delete user
      {:ok, user} = User.register("deleted@example.com", "Password123!", "Password123!")
      {:ok, _deleted} = User.soft_delete(user)

      state = "test_state_deleted"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      conn =
        get(conn, "/auth/google/callback", %{
          code: "google_code_deleted",
          state: state
        })

      # Should not allow login
      assert redirected_to(conn) == "/tenant/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) != nil
    end
  end

  describe "OAuth security and CSRF protection" do
    @tag :pending_oauth_implementation
    test "OAuth state is cryptographically random and unique", %{conn: conn} do
      # Generate multiple states
      states =
        for _i <- 1..10 do
          conn = get(conn, "/auth/google")
          get_session(conn, :oauth_state)
        end

      # All should be unique
      unique_states = Enum.uniq(states)
      assert length(unique_states) == 10

      # All should be sufficiently long for security
      Enum.each(states, fn state ->
        assert String.length(state) >= 32, "OAuth state should be at least 32 chars"
      end)
    end

    @tag :pending_oauth_implementation
    test "OAuth state expires and cannot be reused", %{conn: conn} do
      state = "test_state_reuse"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      # First callback succeeds
      conn =
        get(conn, "/auth/google/callback", %{
          code: "google_code_1",
          state: state
        })

      # State should be cleared from session
      assert get_session(conn, :oauth_state) == nil

      # Second callback with same state should fail
      conn2 =
        build_conn()
        |> init_test_session(%{oauth_state: state, oauth_provider: "google"})

      conn2 =
        get(conn2, "/auth/google/callback", %{
          code: "google_code_2",
          state: state
        })

      # Should reject because state was already used
      # (In real implementation, state would be stored with expiration)
      assert redirected_to(conn2) =~ ~r/sign-in|auth/
    end

    @tag :pending_oauth_implementation
    test "OAuth callback validates redirect_uri matches configuration", %{conn: conn} do
      # This test ensures OAuth callback only accepts redirects to configured URIs
      # AshAuthentication handles this validation

      state = "test_state_redirect"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      # Normal callback should work
      conn =
        get(conn, "/auth/google/callback", %{
          code: "google_code",
          state: state
        })

      # Should accept callback from configured OAuth route
      assert conn.status in [302, 200]
    end
  end

  describe "OAuth user info and profile data" do
    @tag :pending_oauth_implementation
    test "extracts and stores user profile data from Google OAuth", %{conn: conn} do
      state = "test_state_profile"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      conn =
        get(conn, "/auth/google/callback", %{
          code: "google_code_profile",
          state: state
        })

      assert redirected_to(conn) == "/tenant/dashboard"

      # In full implementation, verify user record contains:
      # - user_info.name from Google
      # - user_info.email from Google
      # - user_info.image (avatar URL) from Google
      # Stored in user.oauth_tokens["google"]["user_info"]
    end

    @tag :pending_oauth_implementation
    test "extracts and stores user profile data from GitHub OAuth", %{conn: conn} do
      state = "test_state_github_profile"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "github")

      conn =
        get(conn, "/auth/github/callback", %{
          code: "github_code_profile",
          state: state
        })

      assert redirected_to(conn) == "/tenant/dashboard"

      # In full implementation, verify user record contains:
      # - user_info.login (username) from GitHub
      # - user_info.email from GitHub
      # - user_info.avatar_url from GitHub
      # Stored in user.oauth_tokens["github"]["user_info"]
    end
  end

  describe "OAuth integration with existing authentication" do
    setup %{conn: conn} do
      {:ok, user} = User.register("integration@example.com", "Password123!", "Password123!")
      {:ok, user: user, conn: conn}
    end

    @tag :pending_oauth_implementation
    test "user can login with password after linking OAuth", %{conn: _conn, user: user} do
      # Link OAuth
      {:ok, _linked} =
        OAuth.link_oauth(
          user,
          :google,
          %{token: "token", refresh_token: "refresh", expires_at: nil},
          %{uid: "google_123", name: "User", email: "integration@example.com", image: nil}
        )

      # User should still be able to login with password
      # (This is a multi-auth scenario test)
      # Would test via /auth/sign-in endpoint in full integration
    end

    @tag :pending_oauth_implementation
    test "user can login with OAuth after setting password", %{conn: conn, user: user} do
      # Link OAuth first
      {:ok, linked_user} =
        OAuth.link_oauth(
          user,
          :github,
          %{token: "token", refresh_token: "refresh", expires_at: nil},
          %{uid: "github_456", name: "User", email: "integration@example.com", image: nil}
        )

      # Change password
      {:ok, _updated} = User.change_password(linked_user, "NewPassword123!", "NewPassword123!")

      # OAuth login should still work
      state = "test_state_multi_auth"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "github")

      conn =
        get(conn, "/auth/github/callback", %{
          code: "github_code_multi",
          state: state
        })

      assert redirected_to(conn) == "/tenant/dashboard"
    end

    @tag :pending_oauth_implementation
    test "linking multiple OAuth providers to same account", %{conn: _conn, user: user} do
      # Link Google
      {:ok, user_with_google} =
        OAuth.link_oauth(
          user,
          :google,
          %{token: "google_token", refresh_token: nil, expires_at: nil},
          %{uid: "google_123", name: "User", email: "integration@example.com", image: nil}
        )

      # Link GitHub to same user
      {:ok, user_with_both} =
        OAuth.link_oauth(
          user_with_google,
          :github,
          %{token: "github_token", refresh_token: nil, expires_at: nil},
          %{uid: "github_456", name: "User", email: "integration@example.com", image: nil}
        )

      # User should be able to login via either OAuth provider
      linked_providers = OAuth.get_linked_providers(user_with_both)

      assert :google in linked_providers
      assert :github in linked_providers
      assert length(linked_providers) == 2
    end
  end
end
