defmodule McpWeb.AuthController do
  @moduledoc """
  Controller for handling authentication actions.

  This controller handles email/password authentication, sign-in form processing,
  and sign-out functionality.
  """

  use McpWeb, :controller

  alias Mcp.Accounts.Auth

  def create(conn, %{"email" => email, "password" => password}) do
    ip_address = get_client_ip(conn)

    case authenticate_user(email, password, ip_address) do
      {:ok, session} ->
        conn
        |> put_session(:user_token, session.access_token)
        |> put_session(:current_user, session.user)
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: get_session(conn, :return_to) || get_redirect_path(conn, session.user))

      {:password_change_required, user} ->
        # Create a temporary token for password change
        temp_token = generate_temp_token(user)

        conn
        |> put_session(:temp_user_token, temp_token)
        |> put_session(:current_user, user)
        |> put_flash(:warning, "You must change your password before continuing.")
        |> redirect(to: ~p"/change_password")

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: ~p"/sign_in")

      {:error, :account_locked} ->
        conn
        |> put_flash(
          :error,
          "Account is locked. Please check your email for unlock instructions."
        )
        |> redirect(to: ~p"/sign_in")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Authentication failed: #{inspect(reason)}")
        |> redirect(to: ~p"/sign_in")
    end
  end

  def delete(conn, _params) do
    current_user = get_session(conn, :current_user)
    user_token = get_session(conn, :user_token)

    # Revoke the session token
    if user_token && current_user do
      Auth.revoke_session(user_token)
    end

    conn
    |> clear_session()
    |> put_flash(:info, "You have been signed out successfully.")
    |> redirect(to: ~p"/sign_in")
  end

  # Private functions

  defp authenticate_user(email, password, ip_address) do
    case find_user_by_email(email) do
      {:ok, user} ->
        with :ok <- validate_user_status(user),
             :ok <- verify_user_password(user, password) do
          reset_failed_attempts_if_needed(user)
          Auth.create_user_session(user, ip_address)
        else
          {:error, :invalid_password} ->
            Auth.record_failed_attempt(user)
            {:error, :invalid_credentials}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, :not_found} ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_user_status(user) do
    cond do
      user.locked_at && user.locked_at > DateTime.add(DateTime.utc_now(), -1800, :second) ->
        {:error, :account_locked}

      user.status == :deleted ->
        {:error, :account_deleted}

      user.status == :suspended ->
        {:error, :account_suspended}

      true ->
        :ok
    end
  end

  defp reset_failed_attempts_if_needed(user) do
    if user.failed_attempts > 0 do
      Ash.update(Mcp.Accounts.User, user, %{failed_attempts: 0})
    end
  end

  defp find_user_by_email(email) when is_binary(email) do
    case Ash.read(Mcp.Accounts.User, action: :by_email, input: %{email: email}) do
      {:ok, [user]} -> {:ok, user}
      {:ok, []} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp verify_user_password(user, password) do
    if Bcrypt.verify_pass(password, user.hashed_password) do
      :ok
    else
      {:error, :invalid_password}
    end
  end

  defp get_client_ip(conn) do
    # Try to get real IP, fallback to remote address
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> get_req_header(conn, "x-real-ip") || to_string(conn.remote_ip)
      nil -> get_req_header(conn, "x-real-ip") || to_string(conn.remote_ip)
    end
  end

  defp generate_temp_token(_user) do
    # Generate a temporary token for password change flow
    :crypto.strong_rand_bytes(32)
    |> Base.encode64()
    |> String.replace(["/", "+", "="], ["_", "-", ""])
    |> then(fn token -> "pwd_change_" <> token end)
  end

  defp get_redirect_path(conn, _user) do
    # Determine redirect path based on tenant context
    # In the future, we can also check user roles here
    case conn.assigns[:current_tenant] do
      nil ->
        # Platform Admin context
        ~p"/admin"

      _tenant ->
        # Tenant/Merchant context
        # Default to tenant portal for now
        ~p"/tenant"
    end
  end
end
