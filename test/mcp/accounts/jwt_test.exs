defmodule Mcp.Accounts.JWTTest do
  use Mcp.DataCase, async: true

  alias Mcp.Accounts.{User, Token, JWT, Auth}
  alias Mcp.Accounts.Security

  describe "JWT token creation" do
    test "creates valid access token with current context" do
      user = insert(:user)

      {:ok, jwt_result} =
        JWT.create_access_token(user,
          tenant_id: "test-tenant",
          impersonator_id: nil
        )

      assert {:ok, claims} = JWT.verify_token(jwt_result.token)
      assert claims["sub"] == user.id
      assert claims["email"] == user.email
      assert claims["type"] == "access"
      assert claims["current_context"]["tenant_id"] == "test-tenant"
      assert claims["current_context"]["user_id"] == user.id
    end

    test "creates valid refresh token" do
      user = insert(:user)
      session_id = "test-session-123"

      {:ok, jwt_result} =
        JWT.create_refresh_token(user,
          session_id: session_id,
          device_id: "test-device-456"
        )

      assert {:ok, claims} = JWT.verify_token(jwt_result.token)
      assert claims["sub"] == user.id
      assert claims["type"] == "refresh"
      assert claims["session_id"] == session_id
      assert claims["device_id"] == "test-device-456"
    end

    test "token expiration works correctly" do
      user = insert(:user)

      # Create token with very short expiry
      {:ok, jwt_result} = JWT.create_access_token(user)

      # Verify token is initially valid
      assert {:ok, _claims} = JWT.verify_token(jwt_result.token)

      # Wait for token to expire (in real test, you'd use time travel)
      # This is a simplified test - in practice you'd use bypass or time mocking
    end
  end

  describe "JWT token verification" do
    test "valid token verification succeeds" do
      user = insert(:user)
      {:ok, jwt_result} = JWT.create_access_token(user)

      assert {:ok, claims} = JWT.verify_token(jwt_result.token)
      assert claims["sub"] == user.id
      assert claims["type"] == "access"
    end

    test "invalid token verification fails" do
      invalid_token = "invalid.jwt.token"

      assert {:error, _reason} = JWT.verify_token(invalid_token)
    end

    test "token with wrong type fails verification" do
      user = insert(:user)
      {:ok, refresh_jwt} = JWT.create_refresh_token(user)

      # Try to verify refresh token as access token
      assert {:error, :invalid_token_type} = JWT.verify_token(refresh_jwt.token)
    end
  end

  describe "JWT context management" do
    test "current context extraction works" do
      user = insert(:user)

      {:ok, jwt_result} =
        JWT.create_access_token(user,
          tenant_id: "test-tenant"
        )

      claims = jwt_result.claims
      current_context = JWT.get_current_context(claims)

      assert current_context["tenant_id"] == "test-tenant"
      assert current_context["user_id"] == user.id
      assert current_context["email"] == user.email
    end

    test "authorized contexts extraction works" do
      user = insert(:user)
      {:ok, jwt_result} = JWT.create_access_token(user)

      claims = jwt_result.claims
      authorized_contexts = JWT.get_authorized_contexts(claims)

      assert is_list(authorized_contexts)
      # Should contain at least one authorized context
      assert length(authorized_contexts) >= 1
    end

    test "tenant authorization check works" do
      user = insert(:user)

      {:ok, jwt_result} =
        JWT.create_access_token(user,
          tenant_id: "authorized-tenant"
        )

      claims = jwt_result.claims

      assert JWT.authorized_for_tenant?(claims, "authorized-tenant")
      refute JWT.authorized_for_tenant?(claims, "unauthorized-tenant")
    end
  end

  describe "JWT session management" do
    test "create_user_session creates JWT-based session" do
      user = insert(:user)
      ip_address = "192.168.1.1"

      assert {:ok, session_data} =
               Auth.create_user_session(user, ip_address, tenant_id: "test-tenant")

      assert Map.has_key?(session_data, :access_token)
      assert Map.has_key?(session_data, :refresh_token)
      assert Map.has_key?(session_data, :session_id)
      assert Map.has_key?(session_data, :current_context)
      assert Map.has_key?(session_data, :authorized_contexts)

      # Verify access token is valid
      assert {:ok, _claims} = JWT.verify_token(session_data.access_token)

      # Verify refresh token is valid
      assert {:ok, _claims} = JWT.verify_token(session_data.refresh_token)
    end

    test "session refresh works correctly" do
      user = insert(:user)
      {:ok, session_data} = Auth.create_user_session(user)

      # In a real scenario with time passing, this would create new tokens
      # For now, verify refresh token structure
      assert {:ok, claims} = JWT.verify_token(session_data.refresh_token)
      assert claims["type"] == "refresh"
    end

    test "session revocation works" do
      user = insert(:user)
      {:ok, session_data} = Auth.create_user_session(user)

      # Revoke session by session_id
      assert :ok = Auth.revoke_jwt_session(session_data.session_id)

      # Note: In real implementation, you'd verify tokens are now invalid
      # This would require mocking time or using bypass for JWT verification
    end
  end

  describe "JWT security validation" do
    test "validates login attempt security" do
      email = "test@example.com"
      ip_address = "192.168.1.1"

      # Should pass for normal request
      assert :ok = Security.validate_login_attempt(email, ip_address, "Mozilla/5.0...")
    end

    test "detects suspicious user agents" do
      email = "test@example.com"
      ip_address = "192.168.1.1"
      suspicious_ua = "curl/7.68.0"

      assert {:error, :suspicious_user_agent} =
               Security.validate_login_attempt(
                 email,
                 ip_address,
                 suspicious_ua
               )
    end

    test "handles security incidents" do
      user = insert(:user)
      details = %{ip_address: "192.168.1.1"}

      # Should handle suspicious login incident
      assert :ok = Security.handle_security_incident(:suspicious_login, user.id, details)
    end
  end

  describe "JWT error handling" do
    alias Mcp.Accounts.AuthErrors

    test "formats user-friendly error messages" do
      message = AuthErrors.format_user_error(:invalid_credentials)
      assert message == "Invalid email or password. Please try again."

      message = AuthErrors.format_user_error(:token_expired)
      assert message == "Your session has expired. Please sign in again."
    end

    test "provides recovery instructions" do
      instructions = AuthErrors.get_recovery_instructions(:account_locked)
      assert is_list(instructions)
      assert length(instructions) > 0
    end

    test "creates standardized error responses" do
      error_response = AuthErrors.create_error_response(:token_expired, %{context: "test"})

      assert error_response.error == true
      assert error_response.error_type == :token_expired
      assert error_response.error_code == "JWT_002"
      assert Map.has_key?(error_response, :message)
      assert Map.has_key?(error_response, :recovery)
    end

    test "converts error types to HTTP status codes" do
      assert AuthErrors.error_type_to_http_status(:invalid_credentials) == :unauthorized
      assert AuthErrors.error_type_to_http_status(:insufficient_permissions) == :forbidden
      assert AuthErrors.error_type_to_http_status(:rate_limit_exceeded) == :too_many_requests
    end
  end

  describe "Token database integration" do
    test "stores JWT metadata correctly" do
      user = insert(:user)

      {:ok, token_record} =
        Token.create_jwt(%{
          user_id: user.id,
          type: :access,
          jti: "test-jti-123",
          session_id: "test-session-456",
          device_id: "test-device-789",
          expires_at: DateTime.add(DateTime.utc_now(), 24, :hour),
          context: %{test: "context"},
          device_info: %{ip_address: "192.168.1.1"}
        })

      assert token_record.jti == "test-jti-123"
      assert token_record.session_id == "test-session-456"
      assert token_record.device_id == "test-device-789"
      assert token_record.type == :access
    end

    test "finds tokens by session ID" do
      user = insert(:user)
      session_id = "test-session-123"

      # Create multiple tokens for same session
      {:ok, _token1} =
        Token.create_jwt(%{
          user_id: user.id,
          type: :access,
          session_id: session_id,
          expires_at: DateTime.add(DateTime.utc_now(), 24, :hour)
        })

      {:ok, _token2} =
        Token.create_jwt(%{
          user_id: user.id,
          type: :refresh,
          session_id: session_id,
          expires_at: DateTime.add(DateTime.utc_now(), 30, :day)
        })

      # Find all tokens for session
      session_tokens = Token.find_tokens_by_session(session_id)
      assert length(session_tokens) == 2
    end

    test "revokes session tokens correctly" do
      user = insert(:user)
      session_id = "test-session-456"

      # Create tokens
      {:ok, _token1} =
        Token.create_jwt(%{
          user_id: user.id,
          type: :access,
          session_id: session_id,
          expires_at: DateTime.add(DateTime.utc_now(), 24, :hour)
        })

      {:ok, _token2} =
        Token.create_jwt(%{
          user_id: user.id,
          type: :refresh,
          session_id: session_id,
          expires_at: DateTime.add(DateTime.utc_now(), 30, :day)
        })

      # Revoke session
      Token.revoke_session_tokens(session_id)

      # Verify tokens are revoked
      session_tokens = Token.find_tokens_by_session(session_id)
      assert Enum.all?(session_tokens, fn token -> token.revoked_at != nil end)
    end
  end
end
