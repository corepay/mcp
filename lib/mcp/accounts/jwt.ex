defmodule Mcp.Accounts.JWT do
  @moduledoc """
  JWT token generation and verification using Joken.

  Handles signing and verifying JWT tokens for authentication.
  """

  use Joken.Config

  @impl true
  def token_config do
    default_claims(
      # 24 hours
      default_exp: 24 * 60 * 60,
      iss: "mcp-platform",
      aud: "mcp-users"
    )
  end

  @doc """
  Generates a JWT token with the given claims.

  ## Examples

      iex> claims = %{"sub" => user_id, "type" => "access"}
      iex> Mcp.Accounts.JWT.generate_token(claims)
      {:ok, "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."}
  """
  def generate_token(claims) do
    signer = get_signer()

    generate_and_sign(claims, signer)
  end

  @doc """
  Verifies a JWT token and returns the claims.

  ## Examples

      iex> Mcp.Accounts.JWT.verify_token(token)
      {:ok, %{"sub" => "user-id", "type" => "access"}}
  """
  def verify_token(token, type \\ "access") do
    signer = get_signer()

    case verify_and_validate(token, signer) do
      {:ok, claims} ->
        if claims["type"] == type do
          {:ok, claims}
        else
          {:error, :invalid_token_type}
        end
      error -> error
    end
  end

  @doc """
  Verifies a token and returns the user_id from the "sub" claim.
  """
  def verify_and_get_user_id(token) do
    case verify_token(token) do
      {:ok, claims} -> {:ok, claims["sub"]}
      error -> error
    end
  end

  def create_access_token(user, opts \\ []) do
    tenant_id = Keyword.get(opts, :tenant_id, user.tenant_id)
    
    claims = %{
      "sub" => user.id,
      "email" => to_string(user.email),
      "type" => "access",
      "tenant_id" => tenant_id,
      "role" => Map.get(user, :role, :user),
      "current_context" => %{
        "tenant_id" => tenant_id,
        "user_id" => user.id,
        "email" => to_string(user.email)
      }
    }
    case generate_token(claims) do
      {:ok, token, claims} -> {:ok, %{token: token, claims: claims}}
      error -> error
    end
  end

  def create_refresh_token(user, opts \\ []) do
    claims = %{
      "sub" => user.id,
      "type" => "refresh",
      "tenant_id" => user.tenant_id,
      "session_id" => Keyword.get(opts, :session_id),
      "device_id" => Keyword.get(opts, :device_id)
    }
    # Refresh tokens last longer (e.g., 30 days)
    case generate_token(claims) do
      {:ok, token, claims} -> {:ok, %{token: token, claims: claims}}
      error -> error
    end
  end

  def authorized_for_tenant?(claims, tenant_id) do
    claims["tenant_id"] == tenant_id
  end

  def get_current_context(claims) do
    %{
      "user_id" => claims["sub"],
      "tenant_id" => claims["tenant_id"],
      "role" => claims["role"],
      "email" => claims["email"]
    }
  end

  def get_authorized_contexts(claims) do
    contexts = ["user:#{claims["sub"]}"]
    
    if claims["tenant_id"] do
      contexts ++ ["tenant:#{claims["tenant_id"]}"]
    else
      contexts
    end
  end

  # Private functions

  defp get_signer do
    secret = get_signing_secret()
    Joken.Signer.create("HS256", secret)
  end

  defp get_signing_secret do
    Application.get_env(:mcp, :token_signing_secret) ||
      Application.get_env(:mcp, Mcp.Accounts.JWT)[:signing_secret] ||
      raise """
      JWT signing secret not configured!

      Add to config/runtime.exs:
      config :mcp, :token_signing_secret, System.get_env("JWT_SECRET")

      Or for development, add to config/dev.exs:
      config :mcp, :token_signing_secret, "dev-secret-change-in-production"
      """
  end
  def generate_random_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
