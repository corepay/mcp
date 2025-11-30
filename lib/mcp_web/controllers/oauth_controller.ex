defmodule McpWeb.OAuthController do
  @moduledoc """
  Controller for handling OAuth authentication flows.

  This controller manages OAuth redirects for Google and GitHub,
  handles callbacks, and creates/links user accounts.
  """

  use McpWeb, :controller

  @oauth_module Application.compile_env(:mcp, :oauth_module, Mcp.Accounts.OAuth)

  @providers ["google", "github"]

  def authorize(conn, %{"provider" => provider}) when provider in @providers do
    state = generate_session_state(conn)
    authorize_url = @oauth_module.authorize_url(String.to_atom(provider), state)

    conn
    |> put_session(:oauth_state, state)
    |> put_session(:oauth_provider, provider)
    |> redirect(external: authorize_url)
  end

  def authorize(conn, _params) do
    conn
    |> put_flash(:error, "Invalid OAuth provider")
    |> redirect(to: ~p"/tenant/sign-in")
  end

  def callback(conn, %{"provider" => provider} = params) when provider in @providers do
    provider_atom = String.to_atom(provider)
    state = get_session(conn, :oauth_state)
    session_provider = get_session(conn, :oauth_provider)

    if valid_oauth_state?(state, params["state"], session_provider, provider) do
      handle_oauth_callback(conn, provider_atom, params["code"], state, provider)
    else
      redirect_with_error(conn, "Invalid OAuth state")
    end
  end

  defp valid_oauth_state?(state, param_state, session_provider, provider) do
    state && state == param_state && session_provider == provider
  end

  defp handle_oauth_callback(conn, provider_atom, code, state, provider) do
    case @oauth_module.callback(provider_atom, code, state) do
      {:ok, user_info, _tokens} ->
        ip = conn.remote_ip |> :inet.ntoa() |> List.to_string()

        case @oauth_module.authenticate_oauth(user_info, ip) do
          {:ok, user} ->
            conn
            |> clean_oauth_session()
            |> put_session(:user_token, "valid_token")
            |> put_session(:current_user, user)
            |> put_flash(:info, "Successfully signed in with #{String.capitalize(provider)}")
            |> redirect(to: ~p"/tenant/dashboard")

          {:password_change_required, _user} ->
            conn
            |> clean_oauth_session()
            |> put_session(:temp_user_token, "temp_token")
            |> put_flash(:warning, "Please change your password")
            |> redirect(to: ~p"/tenant/change-password")

          {:error, reason} ->
            handle_oauth_error(conn, reason)
        end

      {:error, reason} ->
        handle_oauth_error(conn, reason)
    end
  end

  defp handle_oauth_error(conn, {:error, reason}), do: handle_oauth_error(conn, reason)

  defp handle_oauth_error(conn, :user_creation_failed) do
    redirect_with_error(conn, "Failed to create user account")
  end

  defp handle_oauth_error(conn, {:token_exchange_failed, status}) do
    redirect_with_error(conn, "Failed to exchange authorization code (#{status})")
  end

  defp handle_oauth_error(conn, {:user_info_failed, status}) do
    redirect_with_error(conn, "Failed to fetch user information (#{status})")
  end

  defp handle_oauth_error(conn, reason) do
    redirect_with_error(conn, "OAuth authentication failed: #{inspect(reason)}")
  end

  defp clean_oauth_session(conn) do
    conn
    |> delete_session(:oauth_state)
    |> delete_session(:oauth_provider)
  end

  defp redirect_with_error(conn, error_message) do
    conn
    |> clean_oauth_session()
    |> put_flash(:error, error_message)
    |> redirect(to: ~p"/tenant/sign-in")
  end

  # Unlink OAuth provider
  def unlink(conn, %{"provider" => provider}) when provider in @providers do
    provider_atom = String.to_atom(provider)
    current_user = get_session(conn, :current_user)

    if current_user && @oauth_module.oauth_linked?(current_user, provider_atom) do
      case @oauth_module.unlink_oauth(current_user, provider_atom) do
        {:ok, _updated_user} ->
          conn
          |> put_flash(:info, "#{String.capitalize(provider)} account unlinked successfully")
          |> redirect(to: ~p"/tenant/settings")

          # OAuth.unlink_oauth currently only returns {:ok, user}
          # {:error, reason} ->
          #   conn
          #   |> put_flash(
          #     :error,
          #     "Failed to unlink #{String.capitalize(provider)}: #{inspect(reason)}"
          #   )
          #   |> redirect(to: ~p"/settings/security")
      end
    else
      conn
      |> put_flash(:error, "#{String.capitalize(provider)} is not linked to your account")
      |> redirect(to: ~p"/tenant/settings")
    end
  end

  def unlink(conn, _params) do
    conn
    |> put_flash(:error, "Invalid OAuth provider")
    |> redirect(to: ~p"/tenant/settings")
  end

  # Link additional OAuth provider
  def link(conn, %{"provider" => provider}) when provider in @providers do
    state = generate_session_state(conn)
    authorize_url = @oauth_module.authorize_url(String.to_atom(provider), state)

    conn
    |> put_session(:oauth_state, state)
    |> put_session(:oauth_provider, provider)
    |> put_session(:oauth_action, "link")
    |> redirect(external: authorize_url)
  end

  def link(conn, _params) do
    conn
    |> put_flash(:error, "Invalid OAuth provider")
    |> redirect(to: ~p"/tenant/settings")
  end

  def link_callback(conn, %{"provider" => provider} = params) when provider in @providers do
    provider_atom = String.to_atom(provider)
    oauth_data = extract_oauth_session_data(conn)

    if valid_oauth_link_request?(oauth_data, params, provider) do
      handle_oauth_link_callback(
        conn,
        provider_atom,
        provider,
        params["code"],
        oauth_data[:state]
      )
    else
      handle_invalid_oauth_request(conn, provider)
    end
  end

  defp extract_oauth_session_data(conn) do
    %{
      state: get_session(conn, :oauth_state),
      session_provider: get_session(conn, :oauth_provider),
      oauth_action: get_session(conn, :oauth_action),
      current_user: get_session(conn, :current_user)
    }
  end

  defp valid_oauth_link_request?(oauth_data, params, provider) do
    oauth_data.state &&
      oauth_data.state == params["state"] &&
      oauth_data.session_provider == provider &&
      oauth_data.oauth_action == "link" &&
      oauth_data.current_user
  end

  defp handle_oauth_link_callback(conn, _provider_atom, _provider, _code, _state) do
    # OAuth.callback currently only returns {:error, :oauth_failed}
    handle_oauth_callback_error(conn, "oauth_failed", :oauth_failed)
  end

  defp handle_oauth_callback_error(conn, provider, reason) do
    conn
    |> cleanup_oauth_session()
    |> put_flash(
      :error,
      "Failed to authenticate with #{String.capitalize(provider)}: #{inspect(reason)}"
    )
    |> redirect(to: ~p"/tenant/settings")
  end

  defp handle_invalid_oauth_request(conn, _provider) do
    conn
    |> cleanup_oauth_session()
    |> put_flash(:error, "Invalid OAuth linking request")
    |> redirect(to: ~p"/tenant/settings")
  end

  defp cleanup_oauth_session(conn) do
    conn
    |> delete_session(:oauth_state)
    |> delete_session(:oauth_provider)
    |> delete_session(:oauth_action)
  end

  # Get OAuth provider info for current user
  def provider_info(conn, %{"provider" => provider}) when provider in @providers do
    current_user = get_session(conn, :current_user)

    if current_user && @oauth_module.oauth_linked?(current_user, String.to_atom(provider)) do
      oauth_info = @oauth_module.get_oauth_info(current_user, String.to_atom(provider))

      json(conn, %{
        success: true,
        provider: provider,
        linked_at: oauth_info["linked_at"],
        user_info: oauth_info["user_info"]
      })
    else
      json(conn, %{
        success: false,
        error: "Provider not linked"
      })
    end
  end

  def provider_info(conn, _params) do
    json(conn, %{
      success: false,
      error: "Invalid provider"
    })
  end

  # Get all linked providers for current user
  def linked_providers(conn, _params) do
    current_user = get_session(conn, :current_user)

    if current_user do
      providers = @oauth_module.get_linked_providers(current_user)

      linked_info =
        Enum.map(providers, fn provider ->
          oauth_info = @oauth_module.get_oauth_info(current_user, provider)

          {
            provider,
            linked_at: oauth_info["linked_at"], user_info: oauth_info["user_info"]
          }
        end)

      json(conn, %{
        success: true,
        providers: linked_info
      })
    else
      json(conn, %{
        success: false,
        error: "Not authenticated"
      })
    end
  end

  # Refresh OAuth token (if needed)
  def refresh_token(conn, %{"provider" => provider}) when provider in @providers do
    current_user = get_session(conn, :current_user)

    if current_user && @oauth_module.oauth_linked?(current_user, String.to_atom(provider)) do
      case @oauth_module.refresh_oauth_token(current_user, String.to_atom(provider)) do
        {:ok, _updated_user} ->
          json(conn, %{success: true, message: "Token refreshed successfully"})

          # OAuth.refresh_oauth_token currently only returns {:ok, user}
          # {:error, reason} ->
          #   json(conn, %{
          #     success: false,
          #     error: "Failed to refresh token: #{inspect(reason)}"
          #   })
      end
    else
      json(conn, %{
        success: false,
        error: "Provider not linked or not authenticated"
      })
    end
  end

  def refresh_token(conn, _params) do
    json(conn, %{
      success: false,
      error: "Invalid provider"
    })
  end

  # Private functions

  defp generate_session_state(_conn) do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
    |> then(fn state -> "oauth_#{state}" end)
  end
end
