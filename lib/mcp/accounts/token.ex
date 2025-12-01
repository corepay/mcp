defmodule Mcp.Accounts.Token do
  @moduledoc """
  Token management helper for tests.
  Wraps AuthToken resource or provides mock implementation.
  """

  alias Mcp.Accounts.AuthToken

  def revoke_user_tokens(user) do
    AuthToken.revoke_all_for_user(user)
  end

  def create_jwt_token(user, type, opts \\ []) do
    # Mock JWT creation or use AuthToken to generate one
    # The test expects {:ok, token}
    # type is :access or :refresh
    # opts has expires_in

    expires_in = opts[:expires_in] || {1, :hour}
    expires_at = calculate_expires_at(expires_in)
    jti = "jti_#{System.unique_integer([:positive])}"

    attrs = %{
      user_id: user.id,
      token: Mcp.Accounts.JWT.generate_random_token(),
      expires_at: expires_at,
      jti: jti,
      context: %{},
      device_info: %{}
    }

    case type do
      :access -> AuthToken.create_access_token(attrs)
      :refresh -> AuthToken.create_refresh_token(attrs)
    end
  end

  defp calculate_expires_at({amount, unit}) do
    seconds =
      case unit do
        :second -> amount
        :minute -> amount * 60
        :hour -> amount * 3600
        :day -> amount * 86400
      end

    DateTime.utc_now() |> DateTime.add(seconds, :second)
  end

  def cleanup_expired_tokens do
    # Mock cleanup
    :ok
  end

  def create_jwt(params) do
    # Delegate to AuthToken resource
    action =
      case params[:type] do
        :refresh -> :create_refresh_token
        _ -> :create_access_token
      end

    # Map params to what AuthToken expects
    attrs = %{
      user_id: params[:user_id],
      token: params[:token] || Mcp.Accounts.JWT.generate_random_token(),
      expires_at: params[:expires_at],
      session_id: params[:session_id],
      device_id: params[:device_id],
      jti: params[:jti],
      context: params[:context] || %{},
      device_info: params[:device_info] || %{}
    }

    # Use Ash to create the token
    Mcp.Accounts.AuthToken
    |> Ash.Changeset.for_create(action, attrs)
    |> Ash.create()
  end

  def find_token_by_jti(jti) do
    AuthToken.by_jti(jti)
  end

  def find_tokens_by_session(session_id) do
    case AuthToken.by_session(session_id) do
      {:ok, tokens} -> tokens
      _ -> []
    end
  end

  def revoke_session_tokens(session_id) do
    case AuthToken.by_session(session_id) do
      {:ok, tokens} ->
        Enum.each(tokens, &AuthToken.revoke/1)
        :ok

      _ ->
        :error
    end
  end

  def generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
