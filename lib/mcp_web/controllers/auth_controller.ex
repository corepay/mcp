defmodule McpWeb.AuthController do
  @moduledoc """
  Controller for handling authentication actions.

  This controller handles email/password authentication, sign-in form processing,
  and sign-out functionality.
  """

  use McpWeb, :controller

  require Logger

  alias Mcp.Accounts.{Auth, User}
  alias Mcp.Communication.EmailService
  alias McpWeb.Auth.SessionPlug

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
        |> SessionPlug.set_jwt_session(session)
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

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid email or password")
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
    |> SessionPlug.clear_jwt_session()
    |> put_flash(:info, "You have been signed out successfully.")
    |> redirect(to: sign_in_path)
  end

  # Private functions

  defp get_sign_in_path_from_referer(nil), do: ~p"/tenant/sign-in"

  defp get_sign_in_path_from_referer(referer) do
    uri = URI.parse(referer)
    path = uri.path || ""
    resolve_portal_signin_path(path)
  end

  defp get_sign_in_path_from_conn(conn) do
    resolve_portal_signin_path(conn.request_path)
  end

  defp resolve_portal_signin_path(path) do
    path_prefix = get_portal_prefix(path)

    case path_prefix do
      "/admin" -> ~p"/admin/sign-in"
      "/app" -> ~p"/app/sign-in"
      "/developers" -> ~p"/developers/sign-in"
      "/partners" -> ~p"/partners/sign-in"
      "/store/account" -> ~p"/store/account/sign-in"
      "/vendors" -> ~p"/vendors/sign-in"
      "/online-application" -> ~p"/online-application/login"
      _ -> ~p"/tenant/sign-in"
    end
  end

  defp get_redirect_path(conn, _user) do
    # Determine redirect path based on referer to keep user in the same portal
    referer = get_req_header(conn, "referer") |> List.first()
    uri = if referer, do: URI.parse(referer), else: nil
    path = if uri, do: uri.path || "", else: ""
    path_prefix = get_portal_prefix(path)

    portal_dashboard_map()[path_prefix] || ~p"/"
  end

  defp portal_dashboard_map do
    %{
      "/admin" => ~p"/admin/dashboard",
      "/app" => ~p"/app/dashboard",
      "/developers" => ~p"/developers/dashboard",
      "/partners" => ~p"/partners/dashboard",
      "/store/account" => ~p"/store/account/dashboard",
      "/vendors" => ~p"/vendors/dashboard",
      "/tenant" => ~p"/tenant/dashboard",
      "/online-application" => ~p"/online-application/application"
    }
  end

  @portal_prefixes ~w(/admin /app /developers /partners /store/account /vendors /tenant /online-application)

  defp get_portal_prefix(path) do
    Enum.find(@portal_prefixes, fn prefix -> String.starts_with?(path, prefix) end)
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
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
    |> then(fn token -> "pwd_change_" <> token end)
  end

  @doc false
  def find_user_by_reset_token(token) when is_binary(token) do
    require Ash.Query
    # Query users by reset token
    User
    |> Ash.Query.filter(reset_password_token == ^token)
    |> Ash.Query.limit(1)
    |> Ash.read()
    |> case do
      {:ok, [user]} -> {:ok, user}
      {:ok, []} -> {:error, :not_found}
      {:error, _reason} -> {:error, :not_found}
    end
  end

  @doc false
  def send_password_reset_email(user) do
    # Get the reset token from the user
    reset_token = user.reset_password_token

    # Build reset URL - in production this would be from config
    reset_url = build_reset_url(reset_token)

    # Send email with reset link
    email_body = """
    <html>
      <body>
        <h2>Password Reset Request</h2>
        <p>Hello #{user.first_name || user.email},</p>
        <p>You requested a password reset. Click the link below to reset your password:</p>
        <p><a href="#{reset_url}">Reset Password</a></p>
        <p>This link will expire in 1 hour.</p>
        <p>If you didn't request this, please ignore this email.</p>
      </body>
    </html>
    """

    case EmailService.send_email(
           user.email,
           "Password Reset Request",
           email_body,
           from: "noreply@mcp.local"
         ) do
      {:ok, _} ->
        Logger.info("Password reset email sent to #{user.email}")

      {:error, reason} ->
        Logger.error("Failed to send password reset email: #{inspect(reason)}")
    end
  end

  defp build_reset_url(token) do
    # In production, this would come from application config
    # For now, use a simple tenant reset path
    base_url = System.get_env("APP_URL", "http://localhost:4000")
    "#{base_url}/tenant/reset-password?token=#{token}"
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
    case User.register(params) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> json(%{user: user_view(user)})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_register_errors(error)})
    end
  end

  defp format_register_errors(%Ash.Error.Invalid{errors: errors}) do
    Enum.map(errors, fn e ->
      field = Map.get(e, :field) || Map.get(e, :input) || "unknown"
      %{field: field, message: Exception.message(e)}
    end)
  end

  defp format_register_errors(error) do
    [%{message: Exception.message(error)}]
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

  def profile(conn, _params) do
    # If we reached here, we are authenticated via the API pipeline
    # Handle both user sessions and API key authentication
    if conn.assigns[:api_actor] == :api_key do
      handle_api_key_profile(conn)
    else
      handle_session_profile(conn)
    end
  end

  defp handle_api_key_profile(conn) do
    api_key = conn.assigns[:current_api_key]
    profile_data = build_api_key_profile(api_key)

    if profile_data do
      json(conn, %{data: profile_data})
    else
      send_unauthorized(conn)
    end
  end

  defp build_api_key_profile(api_key) do
    case api_key.owner_type do
      :tenant ->
        %{
          type: "api_key",
          owner_type: "tenant",
          owner_id: api_key.owner_id,
          scopes: api_key.scopes
        }

      :user ->
        case load_user_from_id(api_key.owner_id) do
          nil -> nil
          user -> Map.put(user_view(user), :auth_method, "api_key")
        end

      _ ->
        %{type: "api_key", owner_type: to_string(api_key.owner_type)}
    end
  end

  defp handle_session_profile(conn) do
    user = conn.assigns[:current_user] || load_user_from_id(conn.assigns[:current_user_id])

    if user do
      json(conn, %{data: user_view(user)})
    else
      send_unauthorized(conn)
    end
  end

  defp send_unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Unauthorized"})
  end

  defp load_user_from_id(nil), do: nil

  defp load_user_from_id(user_id) do
    User.get_by_id!(user_id)
  rescue
    _ -> nil
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
    if valid_email_format?(email) do
      schedule_password_reset(email)
      send_password_reset_response(conn)
    else
      send_invalid_email_response(conn)
    end
  end

  def forgot_password(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing email"})
  end

  defp valid_email_format?(email), do: email =~ ~r/^[\w+\-.]+@[a-z\d\-.]+\.[a-z]+$/i

  defp schedule_password_reset(email) do
    # In test env, run synchronously; in prod, run async (fire and forget)
    if Application.get_env(:mcp, :env) == :test do
      process_password_reset_request(email)
    else
      Task.start(fn -> process_password_reset_request(email) end)
    end
  end

  defp send_password_reset_response(conn) do
    conn
    |> put_status(:ok)
    |> text("Password reset instructions sent")
  end

  defp send_invalid_email_response(conn) do
    conn
    |> put_status(:bad_request)
    |> json(%{errors: %{email: ["has invalid format"]}})
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
        attempt_password_reset(conn, token, password, confirmation)
    end
  end

  def reset_password(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> text("Invalid request")
  end

  defp process_password_reset_request(email) do
    with {:ok, user} when not is_nil(user) <- User.by_email(email),
         true <- user.status in [:active, :locked] do
      case User.request_password_reset(user) do
        {:ok, updated_user} ->
          try do
            send_password_reset_email(updated_user)
          catch
            :exit, reason ->
              Logger.warning("Failed to send password reset email: #{inspect(reason)}")
          end

        {:error, reason} ->
          Logger.warning("Failed to generate reset token: #{inspect(reason)}")
      end
    else
      _ -> :ok
    end
  end

  defp attempt_password_reset(conn, token, password, confirmation) do
    with {:ok, user} <- find_user_by_reset_token(token),
         {:ok, _updated_user} <-
           User.reset_password_with_token(user, token, password, confirmation) do
      Auth.revoke_user_sessions(user.id)

      conn
      |> put_status(:ok)
      |> text("Password reset successfully")
    else
      {:error, %Ash.Error.Invalid{errors: errors}} ->
        error_map =
          Enum.reduce(errors, %{}, fn error, acc ->
            field = Map.get(error, :field, :base)
            message = Exception.message(error)
            Map.put(acc, field, [message])
          end)

        conn
        |> put_status(:bad_request)
        |> json(%{errors: error_map})

      {:error, _reason} ->
        conn
        |> put_status(:bad_request)
        |> text("Invalid or expired reset token")
    end
  end
end
