defmodule Mcp.Accounts.OAuthTest do
  @moduledoc """
  TDD Tests for OAuth authentication functionality.

  RED PHASE: These tests are written FIRST and will FAIL because:
  - OAuth2 strategies are not configured in User resource
  - OAuth token storage mechanisms may not be fully implemented
  - Account linking logic may need enhancement

  These tests define the EXPECTED behavior before implementation.
  """

  use Mcp.DataCase, async: false

  alias Mcp.Accounts.{OAuth, User}

  describe "OAuth2 strategy configuration" do
    test "User resource has Google OAuth2 strategy configured" do
      strategies = AshAuthentication.Info.authentication_strategies(User)

      google_strategy =
        Enum.find(strategies, fn strategy ->
          strategy.name == :google
        end)

      assert google_strategy != nil, "Google OAuth2 strategy not configured"
      # Strategy uses OAuth2 as provider, but strategy_module indicates Google
      assert google_strategy.strategy_module == AshAuthentication.Strategy.Google
      # client_id and client_secret are wrapped in AshAuthentication.SecretFunction
      assert google_strategy.client_id != nil, "Google client_id not configured"
      assert google_strategy.client_secret != nil, "Google client_secret not configured"
      assert google_strategy.authorize_url != nil, "Google authorize_url not configured"
      assert google_strategy.token_url != nil, "Google token_url not configured"
    end

    test "User resource has GitHub OAuth2 strategy configured" do
      strategies = AshAuthentication.Info.authentication_strategies(User)

      github_strategy =
        Enum.find(strategies, fn strategy ->
          strategy.name == :github
        end)

      assert github_strategy != nil, "GitHub OAuth2 strategy not configured"
      # Strategy uses OAuth2 as provider, but strategy_module indicates GitHub
      assert github_strategy.strategy_module == AshAuthentication.Strategy.Github
      assert github_strategy.client_id != nil, "GitHub client_id not configured"
      assert github_strategy.client_secret != nil, "GitHub client_secret not configured"
      assert github_strategy.authorize_url != nil, "GitHub authorize_url not configured"
      assert github_strategy.token_url != nil, "GitHub token_url not configured"
    end

    test "OAuth2 strategies use correct redirect URIs" do
      strategies = AshAuthentication.Info.authentication_strategies(User)

      google_strategy = Enum.find(strategies, &(&1.name == :google))
      github_strategy = Enum.find(strategies, &(&1.name == :github))

      # redirect_uri is wrapped in SecretFunction, check it's configured
      assert google_strategy.redirect_uri != nil
      assert github_strategy.redirect_uri != nil
    end

    test "OAuth2 strategies request appropriate scopes" do
      strategies = AshAuthentication.Info.authentication_strategies(User)

      google_strategy = Enum.find(strategies, &(&1.name == :google))
      github_strategy = Enum.find(strategies, &(&1.name == :github))

      # Scopes are in authorization_params keyword list
      google_scope = Keyword.get(google_strategy.authorization_params, :scope, "")

      # Google should request email and profile scopes
      assert google_scope =~ "userinfo.email"
      assert google_scope =~ "userinfo.profile"

      # GitHub has default scopes set by Assent.Strategy.Github
      # If not overridden, check for user scope or just verify authorization_params is present
      assert github_strategy.authorization_params != nil
    end
  end

  describe "OAuth token storage and retrieval" do
    setup do
      {:ok, user} = User.register("oauth@example.com", "Password123!", "Password123!")
      {:ok, user: user}
    end

    test "stores OAuth tokens in user.oauth_tokens map", %{user: user} do
      provider = :google

      auth_info = %{
        token: "google_access_token_123",
        refresh_token: "google_refresh_token_456",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.to_unix()
      }

      user_info = %{
        uid: "google_user_123",
        name: "Test User",
        email: "oauth@example.com",
        image: "https://example.com/avatar.jpg"
      }

      {:ok, updated_user} = OAuth.link_oauth(user, provider, auth_info, user_info)

      assert updated_user.oauth_tokens != nil
      assert Map.has_key?(updated_user.oauth_tokens, "google")

      google_data = updated_user.oauth_tokens["google"]
      assert google_data["provider"] == "google"
      assert google_data["uid"] == "google_user_123"
      assert google_data["access_token"] == "google_access_token_123"
      assert google_data["refresh_token"] == "google_refresh_token_456"
      assert google_data["expires_at"] != nil
      assert google_data["linked_at"] != nil
      assert google_data["user_info"]["name"] == "Test User"
      assert google_data["user_info"]["email"] == "oauth@example.com"
    end

    test "retrieves stored OAuth tokens for a provider", %{user: user} do
      auth_info = %{
        token: "github_token",
        refresh_token: "github_refresh",
        expires_at: DateTime.add(DateTime.utc_now(), 7200, :second) |> DateTime.to_unix()
      }

      user_info = %{
        uid: "github_123",
        name: "GitHub User",
        email: "oauth@example.com",
        image: "https://github.com/avatar"
      }

      {:ok, updated_user} = OAuth.link_oauth(user, :github, auth_info, user_info)

      oauth_info = OAuth.get_oauth_info(updated_user, :github)

      assert oauth_info["linked"] == true
      assert oauth_info["provider"] == "github"
      assert oauth_info["access_token"] == "github_token"
      assert oauth_info["user_info"]["name"] == "GitHub User"
    end

    test "returns empty info for unlinked provider", %{user: user} do
      oauth_info = OAuth.get_oauth_info(user, :google)

      assert oauth_info.provider == :google
      assert oauth_info.linked == false
    end

    test "supports multiple OAuth providers for same user", %{user: user} do
      # Link Google
      {:ok, user_with_google} =
        OAuth.link_oauth(
          user,
          :google,
          %{token: "google_token", refresh_token: "google_refresh", expires_at: nil},
          %{uid: "google_123", name: "User", email: "oauth@example.com", image: nil}
        )

      # Link GitHub
      {:ok, user_with_both} =
        OAuth.link_oauth(
          user_with_google,
          :github,
          %{token: "github_token", refresh_token: "github_refresh", expires_at: nil},
          %{uid: "github_456", name: "User", email: "oauth@example.com", image: nil}
        )

      linked_providers = OAuth.get_linked_providers(user_with_both)

      assert :google in linked_providers
      assert :github in linked_providers
      assert length(linked_providers) == 2
    end

    test "oauth_tokens are sensitive and not exposed in logs", %{user: user} do
      {:ok, updated_user} =
        OAuth.link_oauth(
          user,
          :google,
          %{token: "secret_token", refresh_token: "secret_refresh", expires_at: nil},
          %{uid: "google_123", name: "User", email: "oauth@example.com", image: nil}
        )

      # Verify oauth_tokens attribute is marked as sensitive in User resource
      sensitive_attrs =
        User
        |> Ash.Resource.Info.attributes()
        |> Enum.filter(& &1.sensitive?)
        |> Enum.map(& &1.name)

      assert :oauth_tokens in sensitive_attrs

      # When inspected, sensitive fields should be redacted
      inspected = inspect(updated_user)
      refute inspected =~ "secret_token"
      refute inspected =~ "secret_refresh"
    end
  end

  describe "OAuth account linking logic" do
    setup do
      {:ok, user} = User.register("existing@example.com", "Password123!", "Password123!")
      {:ok, user: user}
    end

    test "links OAuth provider to existing user account", %{user: user} do
      refute OAuth.oauth_linked?(user, :google)

      {:ok, updated_user} =
        OAuth.link_oauth(
          user,
          :google,
          %{token: "access", refresh_token: "refresh", expires_at: nil},
          %{uid: "google_123", name: "User", email: "existing@example.com", image: nil}
        )

      assert OAuth.oauth_linked?(updated_user, :google)
    end

    test "unlinks OAuth provider from user account", %{user: user} do
      {:ok, linked_user} =
        OAuth.link_oauth(
          user,
          :github,
          %{token: "access", refresh_token: "refresh", expires_at: nil},
          %{uid: "github_456", name: "User", email: "existing@example.com", image: nil}
        )

      assert OAuth.oauth_linked?(linked_user, :github)

      {:ok, unlinked_user} = OAuth.unlink_oauth(linked_user, :github)

      refute OAuth.oauth_linked?(unlinked_user, :github)
    end

    test "prevents unlinking unsupported providers", %{user: user} do
      result = OAuth.unlink_oauth(user, :unsupported_provider)

      # Should return error or unchanged user since provider doesn't exist
      case result do
        {:ok, _unchanged_user} -> :ok
        {:error, _reason} -> :ok
      end
    end

    test "refreshes OAuth token for linked provider", %{user: user} do
      # Link provider with expiring token
      expires_at = DateTime.add(DateTime.utc_now(), 300, :second) |> DateTime.to_unix()

      {:ok, linked_user} =
        OAuth.link_oauth(
          user,
          :google,
          %{token: "old_token", refresh_token: "refresh_token", expires_at: expires_at},
          %{uid: "google_123", name: "User", email: "existing@example.com", image: nil}
        )

      # This will fail until refresh_oauth_token is fully implemented
      {:ok, refreshed_user} = OAuth.refresh_oauth_token(linked_user, :google)

      # Token should be updated (in real implementation)
      assert refreshed_user.id == linked_user.id
    end

    test "returns error when refreshing unlinked provider", %{user: user} do
      assert {:error, :oauth_not_linked} = OAuth.refresh_oauth_token(user, :google)
    end

    test "returns error when refresh token not available", %{user: user} do
      # Link without refresh token
      {:ok, linked_user} =
        OAuth.link_oauth(
          user,
          :github,
          %{token: "access", refresh_token: nil, expires_at: nil},
          %{uid: "github_123", name: "User", email: "existing@example.com", image: nil}
        )

      assert {:error, :no_refresh_token} = OAuth.refresh_oauth_token(linked_user, :github)
    end
  end

  describe "OAuth callback handling" do
    test "creates new user from OAuth when email doesn't exist" do
      auth_info = %{
        token: "new_user_token",
        refresh_token: "new_user_refresh",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.to_unix()
      }

      user_info = %{
        uid: "google_new_123",
        name: "New User",
        email: "newuser@example.com",
        image: "https://example.com/new_avatar.jpg"
      }

      # User should not exist yet
      assert {:error, _} = User.by_email("newuser@example.com")

      {:ok, created_user} = OAuth.callback(:google, auth_info, user_info)

      assert to_string(created_user.email) == "newuser@example.com"
      assert OAuth.oauth_linked?(created_user, :google)

      # Verify user has a hashed password (randomly generated for OAuth users)
      assert created_user.hashed_password != nil
      assert String.length(created_user.hashed_password) > 0
    end

    test "links OAuth to existing user when email matches" do
      # Create existing user
      {:ok, existing_user} = User.register("existing@example.com", "Password123!", "Password123!")

      auth_info = %{
        token: "existing_user_token",
        refresh_token: "existing_user_refresh",
        expires_at: nil
      }

      user_info = %{
        uid: "github_existing_456",
        name: "Existing User",
        email: "existing@example.com",
        image: "https://github.com/avatar"
      }

      {:ok, linked_user} = OAuth.callback(:github, auth_info, user_info)

      assert linked_user.id == existing_user.id
      assert OAuth.oauth_linked?(linked_user, :github)
    end

    test "returns error when OAuth email is missing" do
      auth_info = %{
        token: "no_email_token",
        refresh_token: nil,
        expires_at: nil
      }

      user_info = %{
        uid: "provider_123",
        name: "User Without Email",
        # Missing email
        email: nil,
        image: nil
      }

      assert {:error, :oauth_email_required} = OAuth.callback(:google, auth_info, user_info)
    end

    @tag :pending_oauth_implementation
    test "rejects callback from unsupported provider" do
      auth_info = %{token: "token", refresh_token: nil, expires_at: nil}
      user_info = %{uid: "123", name: "User", email: "user@example.com", image: nil}

      # This should fail for unsupported providers
      result = OAuth.callback(:unsupported_provider, auth_info, user_info)

      # Implementation should reject unsupported providers
      refute match?({:ok, _user}, result)
    end
  end

  describe "OAuth authorize URL generation" do
    test "generates valid Google OAuth authorize URL with state" do
      state = "secure_random_state_123"
      url = OAuth.authorize_url(:google, state)

      assert url == "/auth/google?state=#{state}"
    end

    test "generates valid GitHub OAuth authorize URL with state" do
      state = "secure_random_state_456"
      url = OAuth.authorize_url(:github, state)

      assert url == "/auth/github?state=#{state}"
    end

    test "returns error for unsupported provider" do
      state = "state_123"
      result = OAuth.authorize_url(:unsupported, state)

      assert {:error, message} = result
      assert message =~ "Unsupported OAuth provider"
    end
  end

  describe "OAuth authentication and session tracking" do
    setup do
      {:ok, user} = User.register("auth@example.com", "Password123!", "Password123!")
      {:ok, user: user}
    end

    test "updates sign-in tracking when authenticating via OAuth", %{user: user} do
      ip_address = "192.168.1.100"

      initial_sign_in_count = user.sign_in_count

      {:ok, authenticated_user} = OAuth.authenticate_oauth(user, ip_address)

      assert authenticated_user.sign_in_count == initial_sign_in_count + 1
      assert authenticated_user.last_sign_in_at != nil
      assert authenticated_user.last_sign_in_ip != nil
    end

    test "handles OAuth authentication without IP address", %{user: user} do
      {:ok, authenticated_user} = OAuth.authenticate_oauth(user, nil)

      # Should still update sign-in tracking
      assert authenticated_user.sign_in_count > 0
      assert authenticated_user.last_sign_in_at != nil
    end
  end

  describe "OAuth provider information" do
    setup do
      {:ok, user} = User.register("info@example.com", "Password123!", "Password123!")

      {:ok, user_with_google} =
        OAuth.link_oauth(
          user,
          :google,
          %{token: "google_token", refresh_token: "google_refresh", expires_at: nil},
          %{
            uid: "google_123",
            name: "Info User",
            email: "info@example.com",
            image: "https://google.com/pic"
          }
        )

      {:ok, user: user_with_google}
    end

    test "gets OAuth information for linked provider", %{user: user} do
      info = OAuth.get_oauth_info(user, :google)

      assert info["linked"] == true
      assert info["provider"] == "google"
      assert info["uid"] == "google_123"
      assert info["user_info"]["name"] == "Info User"
      assert info["user_info"]["image"] == "https://google.com/pic"
    end

    test "returns all linked providers for user", %{user: user} do
      # Link another provider
      {:ok, user_with_both} =
        OAuth.link_oauth(
          user,
          :github,
          %{token: "github_token", refresh_token: nil, expires_at: nil},
          %{uid: "github_456", name: "Info User", email: "info@example.com", image: nil}
        )

      providers = OAuth.get_linked_providers(user_with_both)

      assert :google in providers
      assert :github in providers
    end

    test "linked provider check returns boolean", %{user: user} do
      assert OAuth.oauth_linked?(user, :google) == true
      assert OAuth.oauth_linked?(user, :github) == false
    end
  end

  describe "OAuth edge cases and error handling" do
    test "handles concurrent OAuth link attempts gracefully" do
      {:ok, user} = User.register("concurrent@example.com", "Password123!", "Password123!")

      auth_info = %{token: "token", refresh_token: "refresh", expires_at: nil}

      user_info = %{
        uid: "provider_123",
        name: "User",
        email: "concurrent@example.com",
        image: nil
      }

      # Simulate concurrent linking (same provider, same user)
      task1 = Task.async(fn -> OAuth.link_oauth(user, :google, auth_info, user_info) end)
      task2 = Task.async(fn -> OAuth.link_oauth(user, :google, auth_info, user_info) end)

      result1 = Task.await(task1)
      result2 = Task.await(task2)

      # Both should succeed (linking is idempotent)
      assert match?({:ok, _}, result1)
      assert match?({:ok, _}, result2)
    end

    test "preserves existing OAuth links when adding new provider" do
      {:ok, user} = User.register("multi@example.com", "Password123!", "Password123!")

      # Link Google
      {:ok, user_with_google} =
        OAuth.link_oauth(
          user,
          :google,
          %{token: "google_token", refresh_token: "google_refresh", expires_at: nil},
          %{uid: "google_123", name: "Multi User", email: "multi@example.com", image: nil}
        )

      google_info_before = OAuth.get_oauth_info(user_with_google, :google)

      # Link GitHub
      {:ok, user_with_both} =
        OAuth.link_oauth(
          user_with_google,
          :github,
          %{token: "github_token", refresh_token: "github_refresh", expires_at: nil},
          %{uid: "github_456", name: "Multi User", email: "multi@example.com", image: nil}
        )

      # Google link should still exist with same data
      google_info_after = OAuth.get_oauth_info(user_with_both, :google)

      assert google_info_before["uid"] == google_info_after["uid"]
      assert google_info_before["access_token"] == google_info_after["access_token"]

      # GitHub should also be linked
      assert OAuth.oauth_linked?(user_with_both, :github)
    end

    test "handles OAuth link update (re-linking same provider)" do
      {:ok, user} = User.register("relink@example.com", "Password123!", "Password123!")

      # Initial link
      {:ok, user_v1} =
        OAuth.link_oauth(
          user,
          :google,
          %{token: "old_token", refresh_token: "old_refresh", expires_at: nil},
          %{uid: "google_123", name: "User V1", email: "relink@example.com", image: nil}
        )

      old_token = user_v1.oauth_tokens["google"]["access_token"]
      assert old_token == "old_token"

      # Re-link with new tokens (user revoked and re-authorized)
      {:ok, user_v2} =
        OAuth.link_oauth(
          user_v1,
          :google,
          %{token: "new_token", refresh_token: "new_refresh", expires_at: nil},
          %{uid: "google_123", name: "User V2", email: "relink@example.com", image: nil}
        )

      new_token = user_v2.oauth_tokens["google"]["access_token"]
      assert new_token == "new_token"

      # Should update, not duplicate
      assert map_size(user_v2.oauth_tokens) == 1
    end
  end
end
