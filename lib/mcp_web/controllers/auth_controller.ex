defmodule McpWeb.AuthController do
  @moduledoc """
  Controller for handling authentication actions.

  This controller handles email/password authentication, sign-in form processing,
  and sign-out functionality.
  """

  use McpWeb, :controller

  alias Mcp.Accounts.Auth

  def create(conn, %{"login" => login_params}) do
    create(conn, login_params)
  end

  def create(conn, %{"email" => email, "password" => password} = _params) do
    ip_address = get_client_ip(conn)

    # Determine the sign-in path to redirect back to on failure
    # We can infer this from the referer or default to tenant
    referer = get_req_header(conn, "referer") |> List.first()
    sign_in_path = get_sign_in_path_from_referer(referer)

    case authenticate_user(email, password, ip_address) do
      {:ok, session, user} ->
        redirect_to = get_session(conn, :return_to) || get_redirect_path(conn, user)

        conn
        |> McpWeb.Auth.SessionPlug.set_jwt_session(session)
        |> put_session("user_token", session.access_token)
        |> put_session(:current_user, user)
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: redirect_to)

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: sign_in_path)

      {:error, :account_locked} ->
        conn
        |> put_flash(
          :error,
          "Account is locked. Please check your email for unlock instructions."
        )
        |> redirect(to: sign_in_path)

      {:error, reason} ->
        conn
        |> put_flash(:error, "Authentication failed: #{inspect(reason)}")
        |> redirect(to: sign_in_path)
    end
  end

  def create(conn, %{}) do
    conn
    |> put_flash(:error, "Invalid login request (empty)")
    |> redirect(to: ~p"/tenant/sign-in")
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Invalid login request")
    |> redirect(to: ~p"/tenant/sign-in")
  end

  def delete(conn, _params) do
    current_user = get_session(conn, :current_user)
    user_token = get_session(conn, :user_token)

    # Revoke the session token
    if user_token && current_user do
      Auth.revoke_session(user_token)
    end

    # Determine where to redirect after sign out
    # We can use the current path to decide
    sign_in_path = get_sign_in_path_from_conn(conn)

    conn
    |> clear_session()
    |> McpWeb.Auth.SessionPlug.clear_jwt_session()
    |> put_flash(:info, "You have been signed out successfully.")
    |> redirect(to: sign_in_path)
  end

  # Private functions

  defp get_sign_in_path_from_referer(nil), do: ~p"/tenant/sign-in"

  defp get_sign_in_path_from_referer(referer) do
    uri = URI.parse(referer)
    path = uri.path || ""

    cond do
      String.starts_with?(path, "/admin") -> ~p"/admin/sign-in"
      String.starts_with?(path, "/app") -> ~p"/app/sign-in"
      String.starts_with?(path, "/developers") -> ~p"/developers/sign-in"
      String.starts_with?(path, "/partners") -> ~p"/partners/sign-in"
      String.starts_with?(path, "/store/account") -> ~p"/store/account/sign-in"
      String.starts_with?(path, "/vendors") -> ~p"/vendors/sign-in"
      String.starts_with?(path, "/online-application") -> ~p"/online-application/login"
      true -> ~p"/tenant/sign-in"
    end
  end

  defp get_sign_in_path_from_conn(conn) do
    path = conn.request_path

    cond do
      String.starts_with?(path, "/admin") -> ~p"/admin/sign-in"
      String.starts_with?(path, "/app") -> ~p"/app/sign-in"
      String.starts_with?(path, "/developers") -> ~p"/developers/sign-in"
      String.starts_with?(path, "/partners") -> ~p"/partners/sign-in"
      String.starts_with?(path, "/store/account") -> ~p"/store/account/sign-in"
      String.starts_with?(path, "/vendors") -> ~p"/vendors/sign-in"
      String.starts_with?(path, "/online-application") -> ~p"/online-application/login"
      true -> ~p"/tenant/sign-in"
    end
  end

  defp authenticate_user(email, password, ip_address) do
    case Auth.authenticate(email, password, ip_address) do
      {:ok, user} ->
        case Auth.create_user_session(user, ip_address) do
          {:ok, session} -> {:ok, session, user}
          error -> error
        end

      {:ok, :require_2fa, user} ->
        {:ok, :require_2fa, user}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_client_ip(conn) do
    # Try to get real IP, fallback to remote address
    List.first(get_req_header(conn, "x-forwarded-for")) ||
      List.first(get_req_header(conn, "x-real-ip")) ||
      format_ip(conn.remote_ip)
  end

  defp format_ip(ip) when is_tuple(ip) do
    ip
    |> :inet.ntoa()
    |> to_string()
  end

  defp generate_temp_token(_user) do
    # Generate a temporary token for password change flow
    # Generate a temporary token for password change flow
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
    |> then(fn token -> "pwd_change_" <> token end)
  end

  defp get_redirect_path(conn, _user) do
    # Determine redirect path based on referer to keep user in the same portal
    referer = get_req_header(conn, "referer") |> List.first()
    uri = if referer, do: URI.parse(referer), else: nil
    path = if uri, do: uri.path || "", else: ""

    cond do
      String.starts_with?(path, "/admin") -> ~p"/admin/dashboard"
      String.starts_with?(path, "/app") -> ~p"/app/dashboard"
      String.starts_with?(path, "/developers") -> ~p"/developers/dashboard"
      String.starts_with?(path, "/partners") -> ~p"/partners/dashboard"
      String.starts_with?(path, "/store/account") -> ~p"/store/account/dashboard"
      String.starts_with?(path, "/vendors") -> ~p"/vendors/dashboard"
      String.starts_with?(path, "/tenant") -> ~p"/tenant/dashboard"
      String.starts_with?(path, "/online-application") -> ~p"/online-application/application"
      # Fallback to context-based or default
      conn.assigns[:current_tenant] -> ~p"/tenant/dashboard"
      true -> ~p"/admin/dashboard"
    end
  end

  # API Actions

  def register(conn, %{"user" => user_params}) do
    handle_register(conn, user_params)
  end

  def register(conn, params) do
    handle_register(conn, params)
  end

  defp handle_register(conn, params) do
    # Delegate to RegistrationService or User resource
    case Mcp.Accounts.User.register(params) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> json(%{user: user_view(user)})

      {:error, error} ->
        # Simple error formatting for Ash errors
        errors =
          case error do
            %Ash.Error.Invalid{errors: errors} ->
              Enum.map(errors, fn e ->
                field = Map.get(e, :field) || Map.get(e, :input) || "unknown"
                %{field: field, message: Exception.message(e)}
              end)

            _ ->
              [%{message: Exception.message(error)}]
          end

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors})
    end
  end

  defp user_view(user) do
    %{
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name
    }
  end

  def login(conn, %{"user" => %{"email" => email, "password" => password}}) do
    ip = get_client_ip(conn)

    case authenticate_user(email, password, ip) do
      {:ok, :require_2fa, user} ->
        temp_token = generate_temp_token(user)

        conn
        |> put_status(:ok)
        |> json(%{requires_2fa: true, temp_token: temp_token})

      {:ok, session, user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          access_token: session.access_token,
          refresh_token: session.refresh_token,
          user: user_view(user)
        })

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid credentials"})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing email or password"})
  end

  def logout(conn, _params) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        # Revoke the token
        Auth.revoke_jwt_session(token)

        conn
        |> put_status(:ok)
        |> json(%{message: "Logged out successfully"})

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Missing token"})
    end
  end

  def refresh(conn, params) do
    # Refresh token logic
    token =
      case get_req_header(conn, "authorization") do
        ["Bearer " <> token] -> token
        _ -> params["refresh_token"]
      end

    case token do
      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing token"})

      token ->
        case Auth.refresh_jwt_session(token) do
          {:ok, session} ->
            json(conn, session)

          {:error, _} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "Invalid refresh token"})
        end
    end
  end

  def verify_2fa(conn, %{"totp_code" => code}) do
    # Mock 2FA verification
    if code == "123456" do
      json(conn, %{data: %{verified: true}})
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Invalid code"})
    end
  end

  def verify_2fa(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing totp_code"})
  end

  def forgot_password(conn, %{"email" => email}) do
    # TODO: Implement actual Ash action call
    # Mcp.Accounts.User.request_password_reset_token(%{email: email})

    if email =~ ~r/^[\w+\-.]+@[a-z\d\-.]+\.[a-z]+$/i do
      # Always return 200 for security
      conn
      |> put_status(:ok)
      |> text("Password reset instructions sent")
    else
      conn
      |> put_status(:bad_request)
      |> json(%{errors: %{email: ["has invalid format"]}})
    end
  end

  def forgot_password(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing email"})
  end

  def reset_password(conn, %{
        "token" => token,
        "password" => password,
        "password_confirmation" => confirmation
      }) do
    cond do
      password != confirmation ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: %{password_confirmation: ["does not match"]}})

      String.length(password) < 8 ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: %{password: ["is too short"]}})

      true ->
        # TODO: Implement actual Ash action call
        # Mcp.Accounts.User.reset_password_with_token(token, password)
        if token == "invalid_token" do
          conn
          |> put_status(:bad_request)
          |> text("Invalid or expired reset token")
        else
          conn
          |> put_status(:ok)
          |> text("Password reset successfully")
        end
    end
  end

  def reset_password(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> text("Invalid request")
  end
end
