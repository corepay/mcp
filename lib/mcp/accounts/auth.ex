defmodule Mcp.Accounts.Auth do
  @moduledoc """
  Authentication context for user management.
  """

  alias Mcp.Accounts.{AuthToken, JWT, User}
  alias Mcp.Cache.SessionStore
  require Logger

  @doc """
  Authenticates a user with email and password.
  """
  def authenticate(email, password, _ip_address \\ nil)
      when is_binary(email) and is_binary(password) do
    # Use AshAuthentication's generated sign_in_with_password action
    result =
      User
      |> Ash.Query.for_read(:sign_in_with_password, %{email: email, password: password})
      |> Ash.read_one()

    case result do
      {:ok, user} when not is_nil(user) ->
        cond do
          user.status == :suspended ->
            {:error, :account_suspended}

          user.status == :deleted ->
            {:error, :account_deleted}

          true ->
            {:ok, user}
        end

      # Handle nil result (user not found) or error result
      _ ->
        # AshAuthentication handles timing attacks internally
        {:error, :invalid_credentials}
    end
  end

  @doc """
  Creates a user session with JWT tokens.
  """
  def create_user_session(user, ip_address \\ nil) do
    # Update user's sign-in information
    case User.update_sign_in(user, ip_address) do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.warning("Failed to update sign-in info: #{inspect(reason)}")
    end

    # Generate JWT token pair
    context = %{
      "ip" => ip_address,
      "user_agent" => nil
    }

    device_info = %{
      "ip" => ip_address
    }

    # Generate tokens directly using JWT service
    access_claims = %{
      "sub" => user.id,
      "type" => "access",
      "iat" => DateTime.utc_now() |> DateTime.to_unix(),
      "exp" => DateTime.utc_now() |> DateTime.add(24, :hour) |> DateTime.to_unix()
    }

    refresh_claims = %{
      "sub" => user.id,
      "type" => "refresh",
      "iat" => DateTime.utc_now() |> DateTime.to_unix(),
      "exp" => DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.to_unix()
    }

    with {:ok, access_token, _claims} <- JWT.generate_token(access_claims),
         {:ok, refresh_token, _claims} <- JWT.generate_token(refresh_claims) do
      # Store tokens in database
      case store_tokens(user.id, access_token, refresh_token, context, device_info) do
        :ok ->
          {:ok,
           %{
             user_id: user.id,
             session_id: UUID.uuid4(),
             access_token: access_token,
             refresh_token: refresh_token,
             expires_at: DateTime.add(DateTime.utc_now(), 24, :hour)
           }}

        error ->
          Logger.error("Failed to store session tokens: #{inspect(error)}")
          {:error, :session_creation_failed}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to generate session tokens: #{inspect(reason)}")
        {:error, :session_creation_failed}
    end
  end

  @doc """
  Records a failed authentication attempt.
  """
  def record_failed_attempt(user) do
    # Implement failed attempt tracking with account lockout
    case get_failed_attempts_count(user.id) do
      {:ok, count} when count >= 5 ->
        # Lock the account after 5 failed attempts
        lock_account(user.id)
        Logger.warning("Account locked for user #{user.id} after 5 failed attempts")

      {:ok, count} ->
        # Increment failed attempts counter
        increment_failed_attempts(user.id, count + 1)
        Logger.warning("Failed authentication attempt #{count + 1} for user: #{user.id}")
    end

    :ok
  end

  @doc """
  Refreshes a JWT session.
  """
  def refresh_jwt_session(refresh_token, _opts \\ []) do
    case JWT.verify_token(refresh_token) do
      {:ok, claims} ->
        case claims["type"] do
          "refresh" ->
            user_id = claims["sub"]

            # Generate new tokens
            access_claims = %{
              "sub" => user_id,
              "type" => "access",
              "iat" => DateTime.utc_now() |> DateTime.to_unix(),
              "exp" => DateTime.utc_now() |> DateTime.add(24, :hour) |> DateTime.to_unix()
            }

            refresh_claims = %{
              "sub" => user_id,
              "type" => "refresh",
              "iat" => DateTime.utc_now() |> DateTime.to_unix(),
              "exp" => DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.to_unix()
            }

            with {:ok, new_access_token, _claims} <- JWT.generate_token(access_claims),
                 {:ok, new_refresh_token, _claims} <- JWT.generate_token(refresh_claims) do
              {:ok,
               %{
                 user_id: user_id,
                 session_id: UUID.uuid4(),
                 access_token: new_access_token,
                 refresh_token: new_refresh_token,
                 expires_at: DateTime.add(DateTime.utc_now(), 24, :hour)
               }}
            else
              {:error, reason} ->
                Logger.error("Failed to refresh session tokens: #{inspect(reason)}")
                {:error, :token_refresh_failed}
            end

          _ ->
            {:error, :invalid_token}
        end

      {:error, _reason} ->
        {:error, :invalid_token}
    end
  end

  @doc """
  Verifies a JWT access token.
  """
  def verify_jwt_access_token(token) when is_binary(token) do
    case JWT.verify_token(token) do
      {:ok, claims} ->
        # Basic verification - ensure it's an access token
        if claims["type"] == "access" do
          {:ok, claims}
        else
          {:error, :invalid_token}
        end

      {:error, _reason} ->
        {:error, :invalid_token}
    end
  end

  @doc """
  Gets current context from JWT claims.
  """
  def get_current_context(claims) when is_map(claims) do
    %{
      tenant_id: claims["tenant_id"],
      user_id: claims["sub"],
      token_type: claims["type"],
      issued_at: claims["iat"],
      expires_at: claims["exp"]
    }
  end

  @doc """
  Gets authorized contexts from JWT claims.
  """
  def get_authorized_contexts(claims) when is_map(claims) do
    # Implement proper authorization based on user roles
    user_id = claims["sub"]

    # Get user with their role from Ash resource
    case User.by_id(user_id) do
      {:ok, user} ->
        # Determine contexts based on user role and status
        base_contexts = ["user:#{user_id}"]

          role_contexts =
            case user.role do
              :admin -> ["admin", "moderator"]
              :moderator -> ["moderator"]
              _ -> []
            end

        tenant_context =
          if user.tenant_id do
            ["tenant:#{user.tenant_id}"]
          else
            []
          end

        base_contexts ++ role_contexts ++ tenant_context

      {:error, _reason} ->
        # Return minimal context if user not found
        ["user:#{user_id}"]
    end
  end

  @doc """
  Revokes a JWT session by token.
  """
  def revoke_jwt_session(token) when is_binary(token) do
    case AuthToken.by_token(token) do
      {:ok, nil} ->
        :ok

      {:ok, auth_token} ->
        AuthToken.revoke(auth_token)
        :ok

      {:error, _reason} ->
        :ok
    end
  end

  @doc """
  Revokes a session for a user token.
  """
  def revoke_session(user_token) when is_binary(user_token) do
    revoke_jwt_session(user_token)
  end

  @doc """
  Revokes all sessions for a user.
  """
  def revoke_all_user_sessions(user_id) do
    case AuthToken.by_user(user_id) do
      {:ok, tokens} ->
        Enum.each(tokens, fn token ->
          AuthToken.revoke(token)
        end)

        :ok

      {:error, _reason} ->
        :ok
    end
  end

  # Private helper functions

  # For now, skip storing tokens in database and just return success
  # In a full implementation, we would store the actual JWT tokens
  defp store_tokens(user_id, access_token, refresh_token, context, device_info) do
    # Store tokens in database for proper token management
    token_data = %{
      user_id: user_id,
      access_token: access_token,
      refresh_token: refresh_token,
      device_info: device_info,
      ip_address: get_ip_address(context),
      user_agent: get_user_agent(context),
      created_at: DateTime.utc_now()
    }

    # Store token metadata in session store for quick lookup
    session_key = "tokens:#{user_id}:#{access_token}"

    case SessionStore.create_session(session_key, token_data, ttl: 86_400) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to store token metadata: #{inspect(reason)}")
        :ok
    end
  end

  # Additional helper functions for failed attempt tracking

  defp get_failed_attempts_count(user_id) do
    # Get failed attempts from cache or database
    cache_key = "failed_attempts:#{user_id}"

    case SessionStore.get_session(cache_key) do
      {:ok, nil} ->
        {:ok, 0}

      {:ok, %{count: count}} ->
        {:ok, count}

      {:error, _reason} ->
        # Fallback to 0 if cache fails
        {:ok, 0}
    end
  end

  defp increment_failed_attempts(user_id, count) do
    cache_key = "failed_attempts:#{user_id}"
    data = %{count: count, last_attempt: DateTime.utc_now()}

    # 1 hour TTL
    SessionStore.create_session(cache_key, data, ttl: 3_600)
  end

  defp lock_account(user_id) do
    # Mark account as locked in User resource
    case User.by_id(user_id) do
      {:ok, user} ->
        User.update(user, %{status: "locked", locked_at: DateTime.utc_now()})

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_ip_address(context) when is_map(context) do
    Map.get(context, "ip_address") || Map.get(context, :ip_address) || "unknown"
  end

  defp get_user_agent(context) when is_map(context) do
    Map.get(context, "user_agent") || Map.get(context, :user_agent) || "unknown"
  end
end
