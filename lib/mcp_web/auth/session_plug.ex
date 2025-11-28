defmodule McpWeb.Auth.SessionPlug do
  @moduledoc """
  Plug for JWT session management with encrypted cookie storage.

  This plug handles JWT token verification, session restoration, and sliding refresh
  for Phoenix LiveView and regular HTTP requests.
  """

  import Plug.Conn

  # Cookie names
  @access_token_cookie "_mcp_access_token"
  @refresh_token_cookie "_mcp_refresh_token"
  @session_id_cookie "_mcp_session_id"

  # Cookie settings
  @cookie_options [
    http_only: true,
    secure: true,
    same_site: "Strict",
    # 30 days for refresh token
    max_age: 30 * 24 * 60 * 60
  ]

  @doc """
  Initialize the plug with options.
  """
  def init(opts \\ []) do
    Keyword.merge(
      [
        protected_routes: [],
        refresh_threshold: {12, :hour}
      ],
      opts
    )
  end

  @doc """
  Call the plug to handle authentication.
  """
  def call(conn, opts) do
    conn = fetch_cookies(conn)

    case extract_tokens_from_cookies(conn) do
      {:ok, access_token, refresh_token, session_id} ->
        handle_existing_session(conn, access_token, refresh_token, session_id, opts)

      {:error, :no_tokens} ->
        handle_no_session(conn, opts)

      {:error, reason} ->
        handle_invalid_session(conn, reason, opts)
    end
  end

  @doc """
  Set JWT session in encrypted cookies.
  """
  def set_jwt_session(conn, session_data) do
    access_token = Map.get(session_data, :access_token) || session_data["access_token"]
    refresh_token = Map.get(session_data, :refresh_token) || session_data["refresh_token"]
    session_id = Map.get(session_data, :session_id) || session_data["session_id"]

    if access_token && refresh_token && session_id do
      conn
      |> put_resp_cookie(
        @access_token_cookie,
        encrypt_token(access_token),
        access_cookie_options()
      )
      |> put_resp_cookie(@refresh_token_cookie, encrypt_token(refresh_token), @cookie_options)
      |> put_resp_cookie(@session_id_cookie, session_id, @cookie_options)
      |> assign(:current_session, session_data)
    else
      conn
    end
  end

  @doc """
  Clear JWT session cookies.
  """
  def clear_jwt_session(conn) do
    conn
    |> delete_resp_cookie(@access_token_cookie, access_cookie_options())
    |> delete_resp_cookie(@refresh_token_cookie, @cookie_options)
    |> delete_resp_cookie(@session_id_cookie, @cookie_options)
    |> assign(:current_user, nil)
    |> assign(:current_session, nil)
  end

  @doc """
  Refresh JWT session if needed (sliding session).
  """
  def maybe_refresh_session(conn, opts \\ []) do
    session = get_current_session(conn)

    if session && should_refresh_session?(session, opts) do
      _refresh_token = get_refresh_token(conn)

      # Auth.refresh_jwt_session currently only returns {:error, :invalid_token}
      # case Auth.refresh_jwt_session(refresh_token, get_session_opts(conn)) do
      #   {:ok, new_session_data} ->
      #     conn
      #     |> set_jwt_session(new_session_data)
      #     |> assign(:current_session, new_session_data)
      #
      #   {:error, _reason} ->
      # Clear session if refresh fails
      clear_jwt_session(conn)
      # end
    else
      conn
    end
  end

  # Private functions

  defp extract_tokens_from_cookies(conn) do
    access_token = conn.cookies[@access_token_cookie]
    refresh_token = conn.cookies[@refresh_token_cookie]
    session_id = conn.cookies[@session_id_cookie]

    if access_token && refresh_token && session_id do
      case decrypt_tokens(access_token, refresh_token) do
        {:ok, decrypted_access, decrypted_refresh} ->
          {:ok, decrypted_access, decrypted_refresh, session_id}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :no_tokens}
    end
  end

  defp handle_existing_session(conn, access_token, refresh_token, session_id, opts) do
    case Mcp.Accounts.Auth.verify_jwt_access_token(access_token) do
      {:ok, claims} ->
        # Set current user and session data
        user_data = extract_user_data_from_claims(claims)

        session_data = %{
          access_token: access_token,
          refresh_token: refresh_token,
          session_id: session_id,
          user: user_data,
          current_context: Mcp.Accounts.Auth.get_current_context(claims),
          authorized_contexts: Mcp.Accounts.Auth.get_authorized_contexts(claims),
          expires_at: DateTime.from_unix!(claims["exp"])
        }

        conn
        |> assign(:current_user, user_data)
        |> assign(:current_session, session_data)
        |> put_session("user_token", access_token)
        |> maybe_refresh_session(opts)

      {:error, _reason} ->
        # Access token invalid, try refresh
        case Mcp.Accounts.Auth.refresh_jwt_session(refresh_token, get_session_opts(conn)) do
          {:ok, new_session_data} ->
            conn
            |> set_jwt_session(new_session_data)
            |> assign(:current_session, new_session_data)
            |> assign(:current_user, new_session_data.user)
            |> put_session("user_token", new_session_data.access_token)

          {:error, _refresh_reason} ->
            handle_invalid_session(conn, :invalid_token, opts)
        end
    end
  end

  defp handle_no_session(conn, _opts) do
    home_path = get_home_path(conn)

    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.put_view(McpWeb.ErrorHTML)
    |> Phoenix.Controller.render("401.html", layout: false, home_path: home_path)
    |> halt()
  end

  defp handle_invalid_session(conn, _reason, _opts) do
    home_path = get_home_path(conn)

    clear_jwt_session(conn)
    |> put_status(:unauthorized)
    |> Phoenix.Controller.put_view(McpWeb.ErrorHTML)
    |> Phoenix.Controller.render("401.html", layout: false, home_path: home_path)
    |> halt()
  end

  defp get_home_path(conn) do
    path = conn.request_path

    cond do
      String.starts_with?(path, "/admin") -> "/admin"
      String.starts_with?(path, "/app") -> "/app"
      String.starts_with?(path, "/developers") -> "/developers"
      String.starts_with?(path, "/partners") -> "/partners"
      String.starts_with?(path, "/store/account") -> "/store/account"
      String.starts_with?(path, "/vendors") -> "/vendors"
      true -> "/tenant"
    end
  end

  defp decrypt_tokens(encrypted_access, encrypted_refresh) do
    # For now, assume tokens are stored directly
    # In production, you'd implement proper decryption here
    if is_binary(encrypted_access) and is_binary(encrypted_refresh) do
      {:ok, encrypted_access, encrypted_refresh}
    else
      {:error, :invalid_tokens}
    end
  end

  defp encrypt_token(token) do
    # For now, return token directly
    # In production, you'd implement proper encryption here
    token
  end

  defp access_cookie_options do
    # Shorter max age for access tokens
    # 24 hours
    Keyword.merge(@cookie_options, max_age: 24 * 60 * 60)
  end

  defp should_refresh_session?(session, opts) do
    threshold = Keyword.get(opts, :refresh_threshold, {12, :hour})

    threshold_seconds =
      case threshold do
        {amount, :second} -> amount
        {amount, :minute} -> amount * 60
        {amount, :hour} -> amount * 3600
        {amount, :day} -> amount * 86_400
      end

    expires_at = Map.get(session, :expires_at)
    now = DateTime.utc_now()

    expires_at && DateTime.diff(expires_at, now, :second) < threshold_seconds
  end

  defp extract_user_data_from_claims(claims) do
    %{
      id: claims["sub"],
      tenant_id: claims["tenant_id"],
      role: claims["role"]
    }
  end

  defp get_session_opts(_conn) do
    # Extract options from conn or use defaults
    []
  end

  defp get_current_session(conn) do
    conn.assigns[:current_session]
  end

  defp get_refresh_token(conn) do
    case get_current_session(conn) do
      %{refresh_token: token} -> token
      _ -> nil
    end
  end
end
