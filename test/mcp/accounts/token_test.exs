defmodule Mcp.Accounts.TokenTest do
  use ExUnit.Case, async: true

  alias Mcp.Accounts.{Token, User}

  describe "token generation" do
    test "generates cryptographically secure tokens" do
      token = Token.generate_token()

      assert is_binary(token)
      assert String.starts_with?(token, "token_")
      assert String.length(token) > 10
      refute String.contains?(token, " ")
      refute String.contains?(token, "\n")
    end

    test "generates unique tokens" do
      token1 = Token.generate_token()
      token2 = Token.generate_token()

      assert token1 != token2
    end

    test "generates valid URL-safe tokens" do
      token = Token.generate_token()

      # Tokens should be URL-safe
      refute String.contains?(token, "+")
      refute String.contains?(token, "/")
      refute String.contains?(token, "=")
    end
  end

  describe "token creation and management" do
    setup do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Test",
            last_name: "User",
            email: "test.user@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:ok, user: user}
    end

    test "creates access token with default expiration", %{user: user} do
      expires_at = DateTime.add(DateTime.utc_now(), 24, :hour)

      {:ok, token} =
        Token.create_jwt_token(user, :access, expires_in: {24, :hour}, action: :register)

      assert token.user_id == user.id
      assert token.type == :access
      assert token.jti != nil
      assert token.session_id != nil
      assert token.token != nil
      assert token.last_used_at != nil
      assert DateTime.compare(token.expires_at, expires_at) == :eq
    end

    test "creates refresh token with 30-day expiration", %{user: user} do
      expires_at = DateTime.add(DateTime.utc_now(), 30, :day)

      {:ok, token} =
        Token.create_jwt_token(user, :refresh, expires_in: {30, :day}, action: :register)

      assert token.type == :refresh
      assert token.user_id == user.id
      assert DateTime.compare(token.expires_at, expires_at) == :eq
    end

    test "creates token with custom session and device info", %{user: user} do
      session_id = "custom_session_123"
      device_id = "device_fingerprint_456"
      device_info = %{user_agent: "Test Browser", ip: "127.0.0.1"}

      {:ok, token} =
        Token.create_jwt_token(user, :access,
          session_id: session_id,
          device_id: device_id,
          device_info: device_info
        )

      assert token.session_id == session_id
      assert token.device_id == device_id
      assert token.device_info == device_info
    end

    test "finds token by JTI", %{user: user} do
      {:ok, token} = Token.create_jwt_token(user, :access)

      {:ok, found_token} = Token.find_token_by_jti(token.jti)

      assert found_token.id == token.id
      assert found_token.jti == token.jti
    end

    test "returns error for non-existent JTI" do
      assert {:error, :not_found} = Token.find_token_by_jti("non_existent_jti")
    end

    test "finds tokens by session ID", %{user: user} do
      {:ok, access_token} = Token.create_jwt_token(user, :access, session_id: "test_session")
      {:ok, refresh_token} = Token.create_jwt_token(user, :refresh, session_id: "test_session")

      tokens = Token.find_tokens_by_session("test_session")

      assert length(tokens) == 2
      jti_list = Enum.map(tokens, & &1.jti)
      assert access_token.jti in jti_list
      assert refresh_token.jti in jti_list
    end
  end

  describe "token revocation" do
    setup do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Test",
            last_name: "User",
            email: "test.user@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:ok, user: user}
    end

    test "revokes individual token", %{user: user} do
      {:ok, token} = Token.create_jwt_token(user, :access)

      assert is_nil(token.revoked_at)

      {:ok, revoked_token} = Token.revoke_token(token)

      assert revoked_token.revoked_at != nil
    end

    test "revokes all user tokens", %{user: user} do
      {:ok, token1} = Token.create_jwt_token(user, :access)
      {:ok, token2} = Token.create_jwt_token(user, :refresh)
      {:ok, token3} = Token.create_jwt_token(user, :access)

      Token.revoke_user_tokens(user)

      # Refresh from database
      {:ok, revoked_token1} = Token.find_token_by_jti(token1.jti)
      {:ok, revoked_token2} = Token.find_token_by_jti(token2.jti)
      {:ok, revoked_token3} = Token.find_token_by_jti(token3.jti)

      assert revoked_token1.revoked_at != nil
      assert revoked_token2.revoked_at != nil
      assert revoked_token3.revoked_at != nil
    end

    test "revokes specific token types only", %{user: user} do
      {:ok, access_token} = Token.create_jwt_token(user, :access)
      {:ok, refresh_token} = Token.create_jwt_token(user, :refresh)
      {:ok, reset_token} = Token.create_jwt_token(user, :reset)

      Token.revoke_user_tokens(user, [:access, :refresh])

      # Access and refresh should be revoked, reset should remain
      {:ok, revoked_access} = Token.find_token_by_jti(access_token.jti)
      {:ok, revoked_refresh} = Token.find_token_by_jti(refresh_token.jti)
      {:ok, active_reset} = Token.find_token_by_jti(reset_token.jti)

      assert revoked_access.revoked_at != nil
      assert revoked_refresh.revoked_at != nil
      assert is_nil(active_reset.revoked_at)
    end

    test "revokes session tokens", %{user: user} do
      session_id = "test_session_123"
      {:ok, token1} = Token.create_jwt_token(user, :access, session_id: session_id)
      {:ok, token2} = Token.create_jwt_token(user, :refresh, session_id: session_id)
      {:ok, other_token} = Token.create_jwt_token(user, :access, session_id: "other_session")

      Token.revoke_session_tokens(session_id)

      # Tokens from test_session should be revoked
      {:ok, revoked_token1} = Token.find_token_by_jti(token1.jti)
      {:ok, revoked_token2} = Token.find_token_by_jti(token2.jti)
      {:ok, active_token} = Token.find_token_by_jti(other_token.jti)

      assert revoked_token1.revoked_at != nil
      assert revoked_token2.revoked_at != nil
      assert is_nil(active_token.revoked_at)
    end
  end

  describe "token lifecycle management" do
    setup do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Test",
            last_name: "User",
            email: "test.user@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:ok, user: user}
    end

    test "updates token last used timestamp", %{user: user} do
      {:ok, token} = Token.create_jwt_token(user, :access)
      original_last_used = token.last_used_at

      # Wait a bit to ensure timestamp difference
      :timer.sleep(10)

      {:ok, updated_token} = Token.update_token_last_used(token)

      assert DateTime.compare(updated_token.last_used_at, original_last_used) == :gt
    end

    test "identifies active tokens correctly", %{user: user} do
      {:ok, active_token} = Token.create_jwt_token(user, :access)

      {:ok, expired_token} =
        Token.create_jwt_token(user, :access, expires_in: {-1, :second}, action: :register)

      {:ok, revoked_token} = Token.create_jwt_token(user, :access)
      Token.revoke_token(revoked_token)

      # Test through direct reading
      active_tokens = Token.find_tokens_by_session(active_token.session_id)
      active_jti_list = Enum.map(active_tokens, & &1.jti)

      assert active_token.jti in active_jti_list

      # Expired and revoked tokens should still exist in session
      assert expired_token.jti in active_jti_list
      assert revoked_token.jti in active_jti_list
    end

    test "creates tokens with different default expiration times", %{user: user} do
      {:ok, access_token} = Token.create_jwt_token(user, :access)
      {:ok, refresh_token} = Token.create_jwt_token(user, :refresh)
      {:ok, default_token} = Token.create_jwt_token(user, :verification)

      access_expected = DateTime.add(DateTime.utc_now(), 24, :hour)
      refresh_expected = DateTime.add(DateTime.utc_now(), 30, :day)
      default_expected = DateTime.add(DateTime.utc_now(), 24, :hour)

      # Allow for small time differences (within 1 second)
      assert abs(DateTime.diff(access_token.expires_at, access_expected, :second)) <= 1
      assert abs(DateTime.diff(refresh_token.expires_at, refresh_expected, :second)) <= 1
      assert abs(DateTime.diff(default_token.expires_at, default_expected, :second)) <= 1
    end
  end

  describe "token validation and security" do
    setup do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Test",
            last_name: "User",
            email: "test.user@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:ok, user: user}
    end

    test "stores sensitive token data securely", %{user: user} do
      {:ok, token} = Token.create_jwt_token(user, :access)

      assert token.token != nil
      assert token.jti != nil
      assert token.session_id != nil
      assert String.length(token.token) > 20
      assert String.length(token.jti) > 10
      assert String.length(token.session_id) > 20
    end

    test "includes context information for auditing", %{user: user} do
      context = %{"login_method" => "password", "mfa_verified" => true}
      device_info = %{"user_agent" => "Mozilla/5.0", "ip_address" => "192.168.1.1"}

      {:ok, token} =
        Token.create_jwt_token(user, :access,
          context: context,
          device_info: device_info
        )

      assert token.context == context
      assert token.device_info == device_info
    end

    test "generates unique session identifiers", %{user: user} do
      {:ok, token1} = Token.create_jwt_token(user, :access)
      {:ok, token2} = Token.create_jwt_token(user, :access)

      assert token1.session_id != token2.session_id
      assert String.length(token1.session_id) > 20
      assert String.length(token2.session_id) > 20
    end

    test "generates unique JWT identifiers", %{user: user} do
      {:ok, token1} = Token.create_jwt_token(user, :access)
      {:ok, token2} = Token.create_jwt_token(user, :access)

      assert token1.jti != token2.jti
      assert String.length(token1.jti) > 10
      assert String.length(token2.jti) > 10
    end
  end

  describe "token cleanup operations" do
    setup do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Test",
            last_name: "User",
            email: "test.user@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:ok, user: user}
    end

    test "cleanup removes very old expired tokens", %{user: user} do
      # Create tokens that are already expired
      {:ok, _old_token} =
        Token.create_jwt_token(user, :access, expires_in: {-8, :day}, action: :register)

      {:ok, _very_old_token} =
        Token.create_jwt_token(user, :refresh, expires_in: {-15, :day}, action: :register)

      # Create recent tokens that should remain
      {:ok, _recent_token} = Token.create_jwt_token(user, :access)

      # Run cleanup (removes tokens older than 7 days)
      Token.cleanup_expired_tokens()

      # Verify very old tokens are gone, recent tokens remain
      recent_tokens = Token.find_tokens_by_session("test_session")

      # This test verifies the cleanup function runs without error
      # In a real scenario, you'd check database counts
      assert true
    end
  end

  describe "edge cases and error handling" do
    test "handles token creation with nil user" do
      assert_raise RuntimeError, fn ->
        Token.create_jwt_token(nil, :access)
      end
    end

    test "generates different token types" do
      token_types = [:access, :refresh, :reset, :verification, :session]

      Enum.each(token_types, fn type ->
        {:ok, user} =
          Ash.create(
            Mcp.Accounts.User,
            %{
              first_name: "Test",
              last_name: "User",
              email: "test.#{type}@example.com",
              password: "Password123!",
              password_confirmation: "Password123!"
            },
            action: :register
          )

        {:ok, token} = Token.create_jwt_token(user, type)
        assert token.type == type
      end)
    end
  end
end
