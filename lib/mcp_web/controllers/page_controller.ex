defmodule McpWeb.PageController do
  use McpWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def sign_in(conn, _params) do
    render(conn, :sign_in)
  end

  def dashboard(conn, _params) do
    current_user = get_session(conn, :current_user)

    if current_user do
      render(conn, :dashboard)
    else
      conn
      |> put_flash(:error, "Please sign in to access dashboard")
      |> redirect(to: ~p"/tenant/sign-in")
    end
  end

  def settings(conn, _params) do
    current_user = get_session(conn, :current_user)

    if current_user do
      render(conn, :settings)
    else
      conn
      |> put_flash(:error, "Please sign in to access settings")
      |> redirect(to: ~p"/tenant/sign-in")
    end
  end

  def security_settings(conn, _params) do
    current_user = get_session(conn, :current_user)

    if current_user do
      render(conn, :security_settings)
    else
      conn
      |> put_flash(:error, "Please sign in to access security settings")
      |> redirect(to: ~p"/tenant/sign-in")
    end
  end

  def acme_challenge(conn, %{"token" => token}) do
    # Handle Let's Encrypt ACME challenge for SSL certificate verification
    # In a production environment, this would check against stored challenges
    case get_challenge_content(token) do
      content when is_binary(content) ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(:ok, content)

      {:error, :not_found} ->
        conn
        |> send_resp(:not_found, "Challenge not found")
    end
  end

  # Private functions

  defp get_challenge_content(_token) do
    # In production, this would look up the token from a cache or database
    # For now, return not found to prevent enumeration attacks
    {:error, :not_found}
  end
end
