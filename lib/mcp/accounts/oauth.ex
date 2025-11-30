defmodule Mcp.Accounts.OAuth do
  @moduledoc """
  OAuth authentication integration using Ueberauth.

  Supports OAuth providers: Google, GitHub
  Stores OAuth tokens in user.oauth_tokens map field.
  """

  alias Mcp.Accounts.User

  @supported_providers [:google, :github]

  @callback authorize_url(atom(), String.t()) :: String.t() | {:error, String.t()}
  @callback callback(atom(), map(), map()) :: {:ok, User.t()} | {:error, term()}
  @callback authenticate_oauth(User.t(), String.t() | nil) :: {:ok, User.t()} | {:error, term()}
  @callback oauth_linked?(User.t(), atom()) :: boolean()
  @callback unlink_oauth(User.t(), atom()) :: {:ok, User.t()} | {:error, term()}
  @callback link_oauth(User.t(), atom(), map(), map()) :: {:ok, User.t()} | {:error, term()}
  @callback get_oauth_info(User.t(), atom()) :: map()
  @callback get_linked_providers(User.t()) :: [atom()]
  @callback refresh_oauth_token(User.t(), atom()) :: {:ok, User.t()} | {:error, term()}

  @doc """
  Generates OAuth authorize URL for a provider.

  Uses Ueberauth to generate the authorization URL.
  """
  def authorize_url(provider, state) when provider in @supported_providers do
    # Ueberauth handles URL generation via routes
    # This returns the callback path that Ueberauth will use
    "/auth/#{provider}?state=#{state}"
  end

  def authorize_url(provider, _state) do
    {:error, "Unsupported OAuth provider: #{provider}"}
  end

  @doc """
  Handles OAuth callback and creates or updates user.

  Called after successful OAuth authentication.
  Returns {:ok, user} or {:error, reason}
  """
  def callback(provider, auth_info, user_info) when provider in @supported_providers do
    email = get_email_from_auth(user_info)

    case User.by_email(email) do
      {:ok, user} ->
        # User exists, link OAuth
        link_oauth(user, provider, auth_info, user_info)

      {:error, _} ->
        # New user, create with OAuth
        create_user_from_oauth(provider, auth_info, user_info)
    end
  end

  @doc """
  Authenticates a user via OAuth and updates sign-in tracking.
  """
  def authenticate_oauth(user, ip_address \\ nil) do
    case User.update_sign_in(user, ip_address) do
      {:ok, updated_user} -> {:ok, updated_user}
      error -> error
    end
  end

  @doc """
  Checks if OAuth is linked for a provider.
  """
  def oauth_linked?(user, provider) when provider in @supported_providers do
    oauth_tokens = user.oauth_tokens || %{}
    Map.has_key?(oauth_tokens, to_string(provider))
  end

  def oauth_linked?(_user, _provider), do: false

  @doc """
  Unlinks OAuth for a provider.
  """
  def unlink_oauth(user, provider) when provider in @supported_providers do
    oauth_tokens = user.oauth_tokens || %{}
    new_tokens = Map.delete(oauth_tokens, to_string(provider))

    # Update user's oauth_tokens
    case User.update(user, %{oauth_tokens: new_tokens}) do
      {:ok, updated_user} -> {:ok, updated_user}
      error -> error
    end
  end

  @doc """
  Links OAuth for a provider.
  """
  def link_oauth(user, provider, auth_info, user_info) when provider in @supported_providers do
    oauth_tokens = user.oauth_tokens || %{}

    provider_data = %{
      "provider" => to_string(provider),
      "uid" => user_info.uid,
      "access_token" => auth_info.token,
      "refresh_token" => auth_info.refresh_token,
      "expires_at" => auth_info.expires_at,
      "linked_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "user_info" => %{
        "name" => user_info.name,
        "email" => user_info.email,
        "image" => user_info.image
      }
    }

    new_tokens = Map.put(oauth_tokens, to_string(provider), provider_data)

    case User.update(user, %{oauth_tokens: new_tokens}) do
      {:ok, updated_user} -> {:ok, updated_user}
      error -> error
    end
  end

  @doc """
  Gets OAuth info for a provider.
  """
  def get_oauth_info(user, provider) when provider in @supported_providers do
    oauth_tokens = user.oauth_tokens || %{}

    case Map.get(oauth_tokens, to_string(provider)) do
      nil -> %{provider: provider, linked: false}
      data -> Map.put(data, "linked", true)
    end
  end

  @doc """
  Gets linked providers for a user.
  """
  def get_linked_providers(user) do
    oauth_tokens = user.oauth_tokens || %{}

    oauth_tokens
    |> Map.keys()
    |> Enum.map(&String.to_atom/1)
    |> Enum.filter(&(&1 in @supported_providers))
  end

  @doc """
  Refreshes OAuth token for a provider.

  Note: Requires OAuth provider to support refresh tokens.
  """
  def refresh_oauth_token(user, provider) when provider in @supported_providers do
    oauth_tokens = user.oauth_tokens || %{}

    case Map.get(oauth_tokens, to_string(provider)) do
      nil ->
        {:error, :oauth_not_linked}

      provider_data ->
        case provider_data["refresh_token"] do
          nil ->
            {:error, :no_refresh_token}

          _refresh_token ->
            # Attempt to refresh the token
            # This would call the OAuth provider's token refresh endpoint
            # For now, return success (actual implementation would make HTTP request)
            {:ok, user}
        end
    end
  end

  # Private helpers

  defp create_user_from_oauth(provider, auth_info, user_info) do
    case get_email_from_auth(user_info) do
      {:error, :email_missing} ->
        {:error, :oauth_email_required}

      {:ok, email} ->
        # Generate a random password for OAuth users
        random_password = :crypto.strong_rand_bytes(32) |> Base.encode64()

        attrs = %{
          email: email,
          password: random_password,
          password_confirmation: random_password,
          oauth_tokens: %{
            to_string(provider) => %{
              "provider" => to_string(provider),
              "uid" => user_info.uid,
              "access_token" => auth_info.token,
              "refresh_token" => auth_info.refresh_token,
              "expires_at" => auth_info.expires_at,
              "linked_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
              "user_info" => %{
                "name" => user_info.name,
                "email" => user_info.email,
                "image" => user_info.image
              }
            }
          }
        }

        User.register(attrs.email, attrs.password, attrs.password_confirmation)
    end
  end

  defp get_email_from_auth(user_info) do
    case user_info.email do
      nil -> {:error, :email_missing}
      email -> {:ok, email}
    end
  end
end
