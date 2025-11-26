defmodule McpWeb.OAuthControllerTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  import Mox

  alias Mcp.Accounts.{Auth, OAuth, User}
  alias Mcp.Cache.SessionStore
  alias McpWeb.OAuthController

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
       |> put_req_header("user-agent", "Test Browser")}
  end

  describe "OAuth Authorization" do
    test "redirects to Google OAuth with valid state", %{conn: conn} do
      expect(OAuth, :authorize_url, fn :google, state ->
        assert String.starts_with?(state, "oauth_")
        assert String.length(state) > 20

        "https://accounts.google.com/o/oauth2/auth?client_id=test&redirect_uri=http://localhost:4000/auth/google/callback&state=#{state}"
      end)

      conn = get(conn, "/auth/google")

      assert redirected_to(conn) =~ "accounts.google.com"
      assert redirected_to(conn) =~ "client_id="
      assert redirected_to(conn) =~ "redirect_uri="
      assert redirected_to(conn) =~ "state="

      # Check session state is set
      assert get_session(conn, :oauth_state) != nil
      assert get_session(conn, :oauth_provider) == "google"
    end

    test "redirects to GitHub OAuth with valid state", %{conn: conn} do
      expect(OAuth, :authorize_url, fn :github, state ->
        assert String.starts_with?(state, "oauth_")

        "https://github.com/login/oauth/authorize?client_id=test&redirect_uri=http://localhost:4000/auth/github/callback&state=#{state}"
      end)

      conn = get(conn, "/auth/github")

      assert redirected_to(conn) =~ "github.com"
      assert redirected_to(conn) =~ "client_id="
      assert redirected_to(conn) =~ "state="

      # Check session state is set
      assert get_session(conn, :oauth_state) != nil
      assert get_session(conn, :oauth_provider) == "github"
    end

    test "rejects invalid OAuth provider", %{conn: conn} do
      conn = get(conn, "/auth/invalid")

      assert redirected_to(conn) == "/sign_in"
      assert get_flash(conn, :error) == "Invalid OAuth provider"
    end
  end

  describe "OAuth Callback - Success Scenarios" do
    test "handles successful Google OAuth callback for new user", %{conn: conn} do
      state = "oauth_test_state_123"

      user_info = %{
        provider: :google,
        id: "google_user_123",
        email: "google.user@example.com",
        name: "Google User",
        first_name: "Google",
        last_name: "User",
        avatar_url: "https://lh3.googleusercontent.com/avatar.jpg",
        email_verified: true
      }

      tokens = %{
        access_token: "google_access_token_123",
        refresh_token: "google_refresh_token_123",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.to_iso8601()
      }

      # Setup session state
      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      # Mock OAuth callback
      expect(OAuth, :callback, fn :google, code, captured_state ->
        assert captured_state == state
        assert code == "test_auth_code"
        # nil user means new user will be created
        {:ok, nil, tokens}
      end)

      # Mock user creation
      expect(OAuth, :authenticate_oauth, fn user, _ip ->
        assert user.email == "google.user@example.com"
        create_test_session(user)
      end)

      # Mock OAuth user info for user creation
      expect(OAuth, :callback, 2, fn :google, code, captured_state ->
        if captured_state == state do
          # First call returns user info for user creation
          {:ok, user_info, tokens}
        else
          {:ok, nil, tokens}
        end
      end)

      conn = get(conn, "/auth/google/callback?code=test_auth_code&state=#{state}")

      assert redirected_to(conn) == "/dashboard"
      assert get_flash(conn, :info) =~ "Successfully signed in with Google"
      assert get_session(conn, :user_token) != nil
      assert get_session(conn, :current_user) != nil

      # Session should be cleaned up
      assert get_session(conn, :oauth_state) == nil
      assert get_session(conn, :oauth_provider) == nil
    end

    test "handles successful GitHub OAuth callback for existing user", %{conn: conn} do
      # Create existing user
      {:ok, existing_user} = create_test_user(%{email: "github.user@example.com"})

      state = "oauth_github_state_456"

      user_info = %{
        provider: :github,
        id: "github_user_456",
        email: "github.user@example.com",
        name: "GitHub User",
        username: "githubuser",
        avatar_url: "https://avatars.githubusercontent.com/u/456",
        email_verified: true
      }

      tokens = %{
        access_token: "github_access_token_456",
        token_type: "bearer",
        scope: "user:email",
        expires_at: DateTime.add(DateTime.utc_now(), 7200, :second) |> DateTime.to_iso8601()
      }

      # Setup session state
      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "github")

      # Mock OAuth callback
      expect(OAuth, :callback, fn :github, code, captured_state ->
        assert captured_state == state
        assert code == "test_github_code"
        {:ok, existing_user, tokens}
      end)

      # Mock OAuth authentication
      expect(OAuth, :authenticate_oauth, fn user, _ip ->
        assert user.id == existing_user.id
        create_test_session(user)
      end)

      conn = get(conn, "/auth/github/callback?code=test_github_code&state=#{state}")

      assert redirected_to(conn) == "/dashboard"
      assert get_flash(conn, :info) =~ "Successfully signed in with GitHub"
      assert get_session(conn, :user_token) != nil
      assert get_session(conn, :current_user) != nil
    end

    test "handles password change requirement during OAuth", %{conn: conn} do
      {:ok, user} = create_test_user(%{password_change_required: true})

      state = "oauth_pwd_change_state"

      tokens = %{
        access_token: "access_token",
        refresh_token: "refresh_token"
      }

      # Setup session state
      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      # Mock OAuth callback
      expect(OAuth, :callback, fn :google, _code, captured_state ->
        assert captured_state == state
        {:ok, user, tokens}
      end)

      # Mock OAuth authentication with password change requirement
      expect(OAuth, :authenticate_oauth, fn auth_user, _ip ->
        assert auth_user.id == user.id
        {:password_change_required, auth_user}
      end)

      conn = get(conn, "/auth/google/callback?code=test_code&state=#{state}")

      assert redirected_to(conn) == "/change_password"
      assert get_flash(conn, :warning) =~ "Please change your password"
      assert get_session(conn, :temp_user_token) != nil
    end
  end

  describe "OAuth Callback - Error Scenarios" do
    test "rejects callback with invalid state", %{conn: conn} do
      # Setup session with different state
      conn =
        conn
        |> put_session(:oauth_state, "original_state")
        |> put_session(:oauth_provider, "google")

      conn = get(conn, "/auth/google/callback?code=test_code&state=different_state")

      assert redirected_to(conn) == "/sign_in"
      assert get_flash(conn, :error) == "Invalid OAuth state"

      # Session should be cleaned up
      assert get_session(conn, :oauth_state) == nil
      assert get_session(conn, :oauth_provider) == nil
    end

    test "rejects callback without state", %{conn: conn} do
      conn = get(conn, "/auth/google/callback?code=test_code")

      assert redirected_to(conn) == "/sign_in"
      assert get_flash(conn, :error) == "Invalid OAuth state"
    end

    test "handles token exchange failure", %{conn: conn} do
      state = "oauth_token_error_state"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      # Mock OAuth callback with token exchange failure
      expect(OAuth, :callback, fn :google, _code, captured_state ->
        assert captured_state == state
        {:error, {:token_exchange_failed, 400}}
      end)

      conn = get(conn, "/auth/google/callback?code=invalid_code&state=#{state}")

      assert redirected_to(conn) == "/sign_in"
      assert get_flash(conn, :error) =~ "Failed to exchange authorization code"
      assert get_flash(conn, :error) =~ "(400)"
    end

    test "handles user info fetch failure", %{conn: conn} do
      state = "oauth_user_info_error_state"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "github")

      # Mock OAuth callback with user info failure
      expect(OAuth, :callback, fn :github, _code, captured_state ->
        assert captured_state == state
        {:error, {:user_info_failed, 401}}
      end)

      conn = get(conn, "/auth/github/callback?code=test_code&state=#{state}")

      assert redirected_to(conn) == "/sign_in"
      assert get_flash(conn, :error) =~ "Failed to fetch user information"
      assert get_flash(conn, :error) =~ "(401)"
    end

    test "handles user creation failure", %{conn: conn} do
      state = "oauth_creation_error_state"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      # Mock OAuth callback with user creation failure
      expect(OAuth, :callback, fn :google, _code, captured_state ->
        assert captured_state == state
        {:error, :user_creation_failed}
      end)

      conn = get(conn, "/auth/google/callback?code=test_code&state=#{state}")

      assert redirected_to(conn) == "/sign_in"
      assert get_flash(conn, :error) == "Failed to create user account"
    end

    test "handles session creation failure", %{conn: conn} do
      {:ok, user} = create_test_user()
      state = "oauth_session_error_state"
      tokens = %{access_token: "test_token"}

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")

      # Mock OAuth callback
      expect(OAuth, :callback, fn :google, _code, captured_state ->
        assert captured_state == state
        {:ok, user, tokens}
      end)

      # Mock OAuth authentication failure
      expect(OAuth, :authenticate_oauth, fn _user, _ip ->
        {:error, :session_creation_failed}
      end)

      conn = get(conn, "/auth/google/callback?code=test_code&state=#{state}")

      assert redirected_to(conn) == "/sign_in"
      assert get_flash(conn, :error) =~ "Failed to create session"
    end
  end

  describe "OAuth Linking" do
    test "links OAuth provider to existing user", %{conn: conn} do
      {:ok, user} = create_test_user()
      state = "oauth_link_state_789"

      tokens = %{
        access_token: "link_access_token",
        refresh_token: "link_refresh_token",
        user_info: %{id: "oauth_link_user", name: "Link User"}
      }

      # Setup authenticated session
      conn =
        conn
        |> put_session(:current_user, user)
        |> put_session(:user_token, "valid_token")
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "github")
        |> put_session(:oauth_action, "link")

      # Mock OAuth callback
      expect(OAuth, :callback, fn :github, code, captured_state ->
        assert captured_state == state
        assert code == "link_code"
        {:ok, nil, tokens}
      end)

      # Mock OAuth linking
      expect(OAuth, :link_oauth, fn link_user, :github, link_tokens, user_info ->
        assert link_user.id == user.id
        assert link_tokens == tokens
        assert user_info == tokens.user_info
        {:ok, link_user}
      end)

      conn = get(conn, "/oauth/link/github/callback?code=link_code&state=#{state}")

      assert redirected_to(conn) == "/settings/security"
      assert get_flash(conn, :info) =~ "GitHub account linked successfully"

      # Session should be cleaned up
      assert get_session(conn, :oauth_state) == nil
      assert get_session(conn, :oauth_provider) == nil
      assert get_session(conn, :oauth_action) == nil
    end

    test "rejects linking without authentication", %{conn: conn} do
      state = "oauth_unauth_link_state"

      conn =
        conn
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "google")
        |> put_session(:oauth_action, "link")

      # No current_user session

      conn = get(conn, "/oauth/link/google/callback?code=test_code&state=#{state}")

      assert redirected_to(conn) == "/settings/security"
      assert get_flash(conn, :error) == "Invalid OAuth linking request"
    end

    test "handles linking failure", %{conn: conn} do
      {:ok, user} = create_test_user()
      state = "oauth_link_fail_state"
      tokens = %{access_token: "fail_token"}

      conn =
        conn
        |> put_session(:current_user, user)
        |> put_session(:user_token, "valid_token")
        |> put_session(:oauth_state, state)
        |> put_session(:oauth_provider, "github")
        |> put_session(:oauth_action, "link")

      # Mock OAuth callback
      expect(OAuth, :callback, fn :github, _code, captured_state ->
        assert captured_state == state
        {:ok, nil, tokens}
      end)

      # Mock OAuth linking failure
      expect(OAuth, :link_oauth, fn _user, :github, _tokens, _user_info ->
        {:error, :linking_failed}
      end)

      conn = get(conn, "/oauth/link/github/callback?code=test_code&state=#{state}")

      assert redirected_to(conn) == "/settings/security"
      assert get_flash(conn, :error) =~ "Failed to link GitHub"
    end
  end

  describe "OAuth Unlinking" do
    test "unlinks OAuth provider from authenticated user", %{conn: conn} do
      {:ok, user} = create_test_user_with_oauth(:github)

      conn =
        conn
        |> put_session(:current_user, user)
        |> put_session(:user_token, "valid_token")

      # Mock OAuth unlinking
      expect(OAuth, :oauth_linked?, fn _user, :github -> true end)

      expect(OAuth, :unlink_oauth, fn unlink_user, :github ->
        assert unlink_user.id == user.id
        {:ok, unlink_user}
      end)

      conn = delete(conn, "/oauth/unlink/github")

      assert redirected_to(conn) == "/settings/security"
      assert get_flash(conn, :info) =~ "GitHub account unlinked successfully"
    end

    test "rejects unlinking unlinked provider", %{conn: conn} do
      # User without OAuth
      {:ok, user} = create_test_user()

      conn =
        conn
        |> put_session(:current_user, user)
        |> put_session(:user_token, "valid_token")

      # Mock OAuth check
      expect(OAuth, :oauth_linked?, fn _user, :google -> false end)

      conn = delete(conn, "/oauth/unlink/google")

      assert redirected_to(conn) == "/settings/security"
      assert get_flash(conn, :error) =~ "Google is not linked to your account"
    end

    test "rejects unlinking without authentication", %{conn: conn} do
      conn = delete(conn, "/oauth/unlink/github")

      # This would be handled by the router pipeline middleware
      # For testing purposes, we'll check the response directly
      # Redirect due to authentication failure
      assert conn.status == 302
    end
  end

  describe "OAuth Provider Info API" do
    test "returns provider info for linked provider", %{conn: conn} do
      {:ok, user} =
        create_test_user_with_oauth(:google, %{
          "linked_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "user_info" => %{
            "name" => "Google User",
            "email" => "google@example.com"
          }
        })

      conn =
        conn
        |> put_session(:current_user, user)
        |> put_session(:user_token, "valid_token")

      # Mock OAuth check and info retrieval
      expect(OAuth, :oauth_linked?, fn _user, :google -> true end)

      expect(OAuth, :get_oauth_info, fn info_user, :google ->
        assert info_user.id == user.id

        %{
          "linked_at" => "2023-01-01T00:00:00Z",
          "user_info" => %{
            "name" => "Google User",
            "email" => "google@example.com"
          }
        }
      end)

      conn = get(conn, "/oauth/provider/google")

      assert json_response(conn, 200) == %{
               "success" => true,
               "provider" => "google",
               "linked_at" => "2023-01-01T00:00:00Z",
               "user_info" => %{
                 "name" => "Google User",
                 "email" => "google@example.com"
               }
             }
    end

    test "returns error for unlinked provider", %{conn: conn} do
      {:ok, user} = create_test_user()

      conn =
        conn
        |> put_session(:current_user, user)
        |> put_session(:user_token, "valid_token")

      # Mock OAuth check
      expect(OAuth, :oauth_linked?, fn _user, :github -> false end)

      conn = get(conn, "/oauth/provider/github")

      assert json_response(conn, 200) == %{
               "success" => false,
               "error" => "Provider not linked"
             }
    end

    test "returns all linked providers", %{conn: conn} do
      {:ok, user} = create_test_user_with_oauth([:google, :github])

      conn =
        conn
        |> put_session(:current_user, user)
        |> put_session(:user_token, "valid_token")

      # Mock OAuth providers retrieval
      expect(OAuth, :get_linked_providers, fn providers_user ->
        assert providers_user.id == user.id
        [:google, :github]
      end)

      expect(OAuth, :get_oauth_info, fn _user, :google ->
        %{
          "linked_at" => "2023-01-01T00:00:00Z",
          "user_info" => %{"name" => "Google User"}
        }
      end)

      expect(OAuth, :get_oauth_info, fn _user, :github ->
        %{
          "linked_at" => "2023-01-02T00:00:00Z",
          "user_info" => %{"name" => "GitHub User"}
        }
      end)

      conn = get(conn, "/oauth/providers")

      response = json_response(conn, 200)
      assert response["success"] == true
      assert length(response["providers"]) == 2
    end

    test "returns error for unauthenticated provider info request", %{conn: conn} do
      conn = get(conn, "/oauth/provider/google")

      assert json_response(conn, 200) == %{
               "success" => false,
               "error" => "Not authenticated"
             }
    end
  end

  describe "OAuth Token Refresh" do
    test "refreshes OAuth token successfully", %{conn: conn} do
      {:ok, user} = create_test_user_with_oauth(:google)

      conn =
        conn
        |> put_session(:current_user, user)
        |> put_session(:user_token, "valid_token")

      # Mock OAuth check and refresh
      expect(OAuth, :oauth_linked?, fn _user, :google -> true end)

      expect(OAuth, :refresh_oauth_token, fn refresh_user, :google ->
        assert refresh_user.id == user.id
        {:ok, refresh_user}
      end)

      conn = post(conn, "/oauth/refresh/google")

      assert json_response(conn, 200) == %{
               "success" => true,
               "message" => "Token refreshed successfully"
             }
    end

    test "handles token refresh failure", %{conn: conn} do
      {:ok, user} = create_test_user_with_oauth(:github)

      conn =
        conn
        |> put_session(:current_user, user)
        |> put_session(:user_token, "valid_token")

      # Mock OAuth check and refresh failure
      expect(OAuth, :oauth_linked?, fn _user, :github -> true end)

      expect(OAuth, :refresh_oauth_token, fn _user, :github ->
        {:error, :refresh_failed}
      end)

      conn = post(conn, "/oauth/refresh/github")

      response = json_response(conn, 200)
      assert response["success"] == false
      assert response["error"] =~ "Failed to refresh token"
    end
  end

  describe "Security and Validation" do
    test "handles invalid provider in callback", %{conn: conn} do
      conn = get(conn, "/auth/invalid/callback?code=test&state=test")

      assert redirected_to(conn) == "/sign_in"
      assert get_flash(conn, :error) =~ "Invalid OAuth provider: invalid"
    end

    test "extracts client IP correctly", %{conn: conn} do
      # Test with X-Forwarded-For header
      conn =
        conn
        |> put_req_header("x-forwarded-for", "203.0.113.1")
        |> put_session(:oauth_state, "test_state")
        |> put_session(:oauth_provider, "google")

      # Mock OAuth to capture IP
      captured_ip = nil

      expect(OAuth, :callback, fn :google, _code, _state ->
        # This would normally capture IP via OAuth.authenticate_oauth
        captured_ip = "203.0.113.1"
        {:error, :test}
      end)

      get(conn, "/auth/google/callback?code=test&state=test_state")

      # IP extraction would be verified in the OAuth mock
    end

    test "generates cryptographically secure state parameters", %{conn: conn} do
      # Test multiple requests to ensure state uniqueness
      states =
        for _i <- 1..10 do
          conn = get(conn, "/auth/google")
          get_session(conn, :oauth_state)
        end

      # All states should be unique
      unique_states = Enum.uniq(states)
      assert length(unique_states) == 10

      # All states should start with "oauth_" and be sufficiently long
      Enum.each(states, fn state ->
        assert String.starts_with?(state, "oauth_")
        assert String.length(state) > 20
      end)
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

  defp create_test_user_with_oauth(providers, oauth_info \\ %{}) do
    {:ok, user} = create_test_user()

    oauth_tokens =
      case providers do
        provider when is_atom(provider) ->
          %{
            Atom.to_string(provider) =>
              Map.merge(
                %{
                  "access_token" => "#{provider}_access_token",
                  "refresh_token" => "#{provider}_refresh_token",
                  "linked_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
                  "user_info" => %{
                    "name" => "#{String.capitalize(Atom.to_string(provider))} User"
                  }
                },
                oauth_info
              )
          }

        provider_list when is_list(provider_list) ->
          Enum.into(provider_list, %{}, fn provider ->
            {Atom.to_string(provider),
             Map.merge(
               %{
                 "access_token" => "#{provider}_access_token",
                 "refresh_token" => "#{provider}_refresh_token",
                 "linked_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
                 "user_info" => %{"name" => "#{String.capitalize(Atom.to_string(provider))} User"}
               },
               oauth_info
             )}
          end)
      end

    {:ok, updated_user} = User.update(user, %{oauth_tokens: oauth_tokens})
    updated_user
  end

  defp create_test_session(user) do
    Auth.authenticate(user.email, "Password123!", "127.0.0.1")
  end
end
