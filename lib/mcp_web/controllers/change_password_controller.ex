defmodule McpWeb.ChangePasswordController do
  @moduledoc """
  Controller for handling password change redirects with session data.
  """

  use McpWeb, :controller
  import Phoenix.LiveView.Controller

  def show(conn, _params) do
    current_user = get_session(conn, :current_user)
    temp_token = get_session(conn, :temp_user_token)

    if current_user && current_user.password_change_required && temp_token do
      # Pass session data to LiveView using the proper Phoenix LiveView method
      session = %{
        "current_user" => current_user,
        "temp_user_token" => temp_token
      }

      conn
      |> live_render(McpWeb.AuthLive.ChangePassword, session: session)
    else
      conn
      |> put_flash(:error, "Invalid password change request")
      |> redirect(to: ~p"/sign_in")
    end
  end
end
