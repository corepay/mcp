defmodule Mcp.Accounts.AuthTokenTest do
  use Mcp.DataCase, async: false

  alias Mcp.Accounts.{AuthToken, JWT, User}

  describe "token generation" do
    setup do
      {:ok, user} = User.register("token@example.com", "Password123!", "Password123!")
      {:ok, user: user}
    end

    test "generates access token with correct attributes", %{user: user} do
      context = %{"device" => "web"}
      device_info = %{"user_agent" => "Mozilla/5.0"}

      assert {:ok, token} = AuthToken.generate_access_token(user.id, context, device_info)
      assert token.user_id == user.id
      assert token.type == :access
      assert token.context == context
      assert token.device_info == device_info
      assert DateTime.compare(token.expires_at, DateTime.utc_now()) == :gt
      assert token.revoked_at == nil
      assert token.used_at == nil
    end

    test "generates refresh token with correct attributes", %{user: user} do
      context = %{"device" => "mobile"}
      device_info = %{"app_version" => "1.0.0"}

      assert {:ok, token} = AuthToken.generate_refresh_token(user.id, context, device_info)
      assert token.user_id == user.id
      assert token.type == :refresh
      assert token.context == context
      assert token.device_info == device_info
      assert DateTime.compare(token.expires_at, DateTime.utc_now()) == :gt
      assert token.revoked_at == nil
      assert token.used_at == nil
    end

    test "generates token pair successfully", %{user: user} do
      context = %{"session" => "login"}
      device_info = %{"ip" => "192.168.1.1"}

      assert {:ok, tokens} = AuthToken.generate_token_pair(user.id, context, device_info)
      assert Map.has_key?(tokens, :access_token)
      assert Map.has_key?(tokens, :refresh_token)
      assert tokens.access_token.user_id == user.id
      assert tokens.access_token.type == :access
      assert tokens.refresh_token.user_id == user.id
      assert tokens.refresh_token.type == :refresh
    end
  end

  describe "token verification" do
    setup do
      {:ok, user} = User.register("verify@example.com", "Password123!", "Password123!")
      {:ok, access_token} = AuthToken.generate_access_token(user.id, %{}, %{})
      {:ok, refresh_token} = AuthToken.generate_refresh_token(user.id, %{}, %{})
      {:ok, user: user, access_token: access_token, refresh_token: refresh_token}
    end

    test "verifies valid access token", %{access_token: token} do
      assert {:ok, found_token} = AuthToken.by_token(token.token)
      assert found_token.id == token.id
      assert found_token.type == :access
    end

    test "verifies valid refresh token", %{refresh_token: token} do
      assert {:ok, found_token} = AuthToken.by_token(token.token)
      assert found_token.id == token.id
      assert found_token.type == :refresh
    end

    test "rejects revoked token", %{access_token: token} do
      assert {:ok, revoked_token} = AuthToken.revoke(token)
      assert revoked_token.revoked_at != nil

      assert {:error, _} = AuthToken.by_token(token.token)
    end

    test "rejects expired token" do
      {:ok, user} = User.register("expired@example.com", "Password123!", "Password123!")

      # Create a token that expires immediately
      claims = %{
        "sub" => user.id,
        "type" => "access",
        "iat" => DateTime.utc_now() |> DateTime.to_unix(),
        "exp" => DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.to_unix()
      }

      {:ok, expired_token, _claims} = JWT.generate_token(claims)

      assert {:error, _} = AuthToken.by_token(expired_token)
    end

    test "marks token as used when verified", %{access_token: token} do
      {:ok, _user} = AuthToken.verify_and_get_user(token.token)

      # Reload token to check it was marked as used
      {:ok, updated_token} = AuthToken.by_token(token.token)
      assert updated_token.used_at != nil
    end

    test "verifies token and returns associated user", %{access_token: token, user: user} do
      assert {:ok, found_user} = AuthToken.verify_and_get_user(token.token)
      assert found_user.id == user.id
      assert found_user.email == user.email
    end
  end

  describe "token management" do
    setup do
      {:ok, user} = User.register("manage@example.com", "Password123!", "Password123!")
      {:ok, user: user}
    end

    test "finds all active tokens for a user", %{user: user} do
      # Create multiple tokens
      {:ok, _token1} = AuthToken.generate_access_token(user.id, %{}, %{})
      {:ok, _token2} = AuthToken.generate_refresh_token(user.id, %{}, %{})
      {:ok, _token3} = AuthToken.generate_access_token(user.id, %{}, %{})

      # Revoke one token
      {:ok, revoked_token} = AuthToken.generate_access_token(user.id, %{}, %{})
      AuthToken.revoke(revoked_token)

      {:ok, tokens} = AuthToken.by_user(user.id)
      active_count = length(tokens)

      # Should have 3 active tokens (not including the revoked one)
      assert active_count == 3
    end

    test "finds only active tokens across all users" do
      {:ok, user1} = User.register("user1@example.com", "Password123!", "Password123!")
      {:ok, user2} = User.register("user2@example.com", "Password123!", "Password123!")

      # Create tokens
      {:ok, _token1} = AuthToken.generate_access_token(user1.id, %{}, %{})
      {:ok, _token2} = AuthToken.generate_access_token(user2.id, %{}, %{})

      # Create and revoke a token
      {:ok, token_to_revoke} = AuthToken.generate_access_token(user1.id, %{}, %{})
      AuthToken.revoke(token_to_revoke)

      {:ok, tokens} = AuthToken.active_tokens()

      # Should have 2 active tokens
      assert length(tokens) == 2
    end

    test "revoke_all_for_user destroys all user tokens", %{user: user} do
      # Create multiple tokens
      {:ok, _token1} = AuthToken.generate_access_token(user.id, %{}, %{})
      {:ok, _token2} = AuthToken.generate_refresh_token(user.id, %{}, %{})
      {:ok, _token3} = AuthToken.generate_access_token(user.id, %{}, %{})

      # Revoke all tokens
      AuthToken.destroy(AuthToken.revoke_all_for_user(user.id))

      {:ok, tokens} = AuthToken.by_user(user.id)
      assert Enum.empty?(tokens)
    end
  end

  describe "token lifecycle" do
    setup do
      {:ok, user} = User.register("lifecycle@example.com", "Password123!", "Password123!")
      {:ok, user: user}
    end

    test "marks token as used", %{user: user} do
      {:ok, token} = AuthToken.generate_access_token(user.id, %{}, %{})
      assert token.used_at == nil

      {:ok, used_token} = AuthToken.mark_used(token)
      assert used_token.used_at != nil
    end

    test "revokes token with timestamp", %{user: user} do
      {:ok, token} = AuthToken.generate_access_token(user.id, %{}, %{})
      assert token.revoked_at == nil

      {:ok, revoked_token} = AuthToken.revoke(token)
      assert revoked_token.revoked_at != nil
    end
  end

  describe "token context and device info" do
    setup do
      {:ok, user} = User.register("context@example.com", "Password123!", "Password123!")
      {:ok, user: user}
    end

    test "stores context information", %{user: user} do
      context = %{
        "login_method" => "password",
        "mfa_verified" => true,
        "session_type" => "web"
      }

      {:ok, token} = AuthToken.generate_access_token(user.id, context, %{})
      assert token.context == context
    end

    test "stores device information", %{user: user} do
      device_info = %{
        "user_agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
        "ip_address" => "192.168.1.100",
        "device_id" => "device-123"
      }

      {:ok, token} = AuthToken.generate_access_token(user.id, %{}, device_info)
      assert token.device_info == device_info
    end

    test "handles empty context and device info", %{user: user} do
      {:ok, token} = AuthToken.generate_access_token(user.id, nil, nil)
      assert token.context == %{}
      assert token.device_info == %{}
    end
  end

  describe "token types" do
    setup do
      {:ok, user} = User.register("types@example.com", "Password123!", "Password123!")
      {:ok, user: user}
    end

    test "supports multiple token types", %{user: user} do
      # Test that we can create tokens of different types through the interface
      context = %{}
      device_info = %{}

      {:ok, access_token} = AuthToken.generate_access_token(user.id, context, device_info)
      {:ok, refresh_token} = AuthToken.generate_refresh_token(user.id, context, device_info)

      assert access_token.type == :access
      assert refresh_token.type == :refresh
    end
  end

  describe "pagination and filtering" do
    setup do
      {:ok, user} = User.register("paginate@example.com", "Password123!", "Password123!")

      # Create multiple tokens for pagination testing
      for i <- 1..10 do
        AuthToken.generate_access_token(user.id, %{"index" => i}, %{})
      end

      {:ok, user: user}
    end

    test "read action returns results" do
      {:ok, results} = AuthToken.read()
      assert is_list(results)
      assert length(results) >= 10
    end

    test "active_users filter excludes revoked tokens", %{user: user} do
      # Create and revoke a token
      {:ok, token_to_revoke} = AuthToken.generate_access_token(user.id, %{}, %{})
      AuthToken.revoke(token_to_revoke)

      {:ok, active_result} = AuthToken.active_tokens()
      {:ok, result} = AuthToken.read()

      # Active tokens should be fewer than all tokens
      assert length(active_result) < length(result)
    end

    test "by_user filter only returns tokens for specific user", %{user: user} do
      {:ok, other_user} = User.register("other@example.com", "Password123!", "Password123!")
      {:ok, _other_token} = AuthToken.generate_access_token(other_user.id, %{}, %{})

      {:ok, tokens} = AuthToken.by_user(user.id)

      # All tokens should belong to our user
      Enum.each(tokens, fn token ->
        assert token.user_id == user.id
      end)
    end
  end
end
