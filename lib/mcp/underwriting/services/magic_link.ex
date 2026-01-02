defmodule Mcp.Underwriting.Services.MagicLink do
  @moduledoc """
  Generates and verifies magic links for OLA save & resume.
  Uses Phoenix.Token for secure, expiring tokens.
  """

  @token_salt "ola_resume_v1"
  @default_ttl_hours 72

  @doc """
  Generates a magic link token for an application.

  Options:
  - ttl: Time to live in seconds (default: 72 hours)
  """
  def generate(application_id, email, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl_hours * 3600)

    payload = %{
      application_id: application_id,
      email: email,
      generated_at: DateTime.utc_now() |> DateTime.to_unix()
    }

    token =
      Phoenix.Token.sign(
        McpWeb.Endpoint,
        @token_salt,
        payload,
        max_age: ttl
      )

    {:ok, token}
  end

  @doc """
  Verifies a magic link token and returns the payload.
  """
  def verify(token) do
    case Phoenix.Token.verify(McpWeb.Endpoint, @token_salt, token) do
      {:ok, payload} ->
        {:ok,
         %{
           application_id: payload.application_id,
           email: payload.email
         }}

      {:error, :expired} ->
        {:error, :expired}

      {:error, _} ->
        {:error, :invalid}
    end
  end

  @doc """
  Generates the full resume URL for an application.
  """
  def resume_url(application_id, email) do
    {:ok, token} = generate(application_id, email)
    McpWeb.Endpoint.url() <> "/online-application/resume/#{token}"
  end
end
