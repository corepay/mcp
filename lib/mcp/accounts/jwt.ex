defmodule Mcp.Accounts.JWT do
  @moduledoc """
  JWT token generation and verification using Joken.
  
  Handles signing and verifying JWT tokens for authentication.
  """

  use Joken.Config

  @impl true
  def token_config do
    default_claims(
      default_exp: 24 * 60 * 60,  # 24 hours
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
  def verify_token(token) do
    signer = get_signer()
    
    verify_and_validate(token, signer)
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
end