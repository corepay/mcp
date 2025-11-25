defmodule McpWeb.AuthLive.ChangePassword do
  @moduledoc """
  LiveView for forced password change on first login.

  This LiveView handles the password change form that users are redirected to
  when they have password_change_required: true set on their account.
  """

  use McpWeb, :live_view
  # import Phoenix.HTML.Form  # Unused
  # alias Mcp.Accounts.User    # Unused
  alias Mcp.Accounts.Auth

  @impl true
  def mount(_params, %{"current_user" => current_user, "temp_user_token" => temp_token}, socket) do
    # Handle temporary token from forced password change
    if current_user && current_user.password_change_required &&
         (String.starts_with?(temp_token, "pwd_change_") ||
            String.starts_with?(temp_token, "oauth_pwd_")) do
      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:page_title, "Change Password Required")
       |> assign(:form_changed, false)
       |> assign_form_changeset()}
    else
      # Invalid temporary token or user doesn't need password change
      {:ok, push_navigate(socket, to: ~p"/sign_in")}
    end
  end

  def mount(_params, %{"current_user" => current_user}, socket) do
    # Handle regular user session (for password changes from settings, etc.)
    if current_user do
      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:page_title, "Change Password")
       |> assign(:form_changed, false)
       |> assign_form_changeset()}
    else
      # No valid session, redirect to sign in
      {:ok, push_navigate(socket, to: ~p"/sign_in")}
    end
  end

  def mount(_params, _session, socket) do
    # No valid session, redirect to sign in
    {:ok, push_navigate(socket, to: ~p"/sign_in")}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      Ash.Changeset.for_action(socket.assigns.current_user, :change_password, user_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form_changed, true)
     |> assign_form_changeset(changeset)}
  end

  def handle_event("change_password", %{"user" => user_params}, socket) do
    current_user = socket.assigns.current_user

    case Ash.update(current_user, :change_password, user_params) do
      {:ok, updated_user} ->
        # Password changed successfully, create session and redirect
        case create_session_after_password_change(updated_user) do
          {:ok, _session} ->
            {:noreply,
             socket
             |> put_flash(:info, "Password changed successfully!")
             |> push_navigate(to: "/dashboard", replace: true)}

          {:password_change_required, _user} ->
            {:noreply,
             socket
             |> put_flash(:error, "Password change still required")
             |> push_navigate(to: ~p"/sign_in")}
        end

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign_form_changeset(changeset)
         |> put_flash(:error, "Failed to change password. Please check the form for errors.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 flex items-center justify-center px-4">
      <div class="max-w-md w-full space-y-8">
        <div class="text-center">
          <.icon name="hero-lock-closed" class="mx-auto h-12 w-12 text-primary" />
          <h2 class="mt-6 text-3xl font-bold tracking-tight text-base-content">
            Password Change Required
          </h2>
          <p class="mt-2 text-sm text-base-content/70">
            For security reasons, you must change your password before continuing.
          </p>
        </div>

        <div class="bg-base-100 shadow-xl rounded-lg p-8">
          <form id="change_password_form" phx-submit="change_password" phx-change="validate">
            <div class="form-control mb-4">
              <label class="label">
                <span class="label-text">Current Password</span>
              </label>
              <input
                type="password"
                name="user[current_password]"
                placeholder="Enter your current password"
                class="input input-bordered w-full"
                required
              />
            </div>

            <div class="form-control mb-4">
              <label class="label">
                <span class="label-text">New Password</span>
              </label>
              <input
                type="password"
                name="user[password]"
                placeholder="Enter your new password"
                class="input input-bordered w-full"
                required
              />
            </div>

            <div class="form-control mb-4">
              <label class="label">
                <span class="label-text">Confirm New Password</span>
              </label>
              <input
                type="password"
                name="user[password_confirmation]"
                placeholder="Confirm your new password"
                class="input input-bordered w-full"
                required
              />
            </div>

            <div class="bg-base-200 border border-base-300 rounded-md p-4 mb-6">
              <h3 class="text-sm font-medium text-base-content mb-2">Password Requirements:</h3>
              <ul class="text-xs text-base-content/70 space-y-1">
                <li>• At least 8 characters long</li>
                <li>• Contains uppercase and lowercase letters</li>
                <li>• Contains at least one number</li>
                <li>• Contains at least one special character</li>
              </ul>
            </div>

            <button
              type="submit"
              phx-disable-with="Changing..."
              class={"btn w-full #{if @form_changed, do: "btn-primary", else: "btn-disabled"}"}
              disabled={!@form_changed}
            >
              Change Password
            </button>
          </form>
        </div>

        <div class="text-center text-sm text-base-content/60">
          <p>Need help? Contact your system administrator.</p>
        </div>
      </div>
    </div>
    """
  end

  # Private functions

  defp assign_form_changeset(socket, changeset \\ nil) do
    changeset =
      changeset ||
        Ash.Changeset.for_action(socket.assigns.current_user, :change_password, %{})
        |> Map.put(:action, :validate)

    assign(socket, :form, to_form(changeset))
  end

  # defp verify_user_token(user_token) do  # Unused function
  #   case Mcp.Accounts.Auth.verify_session(user_token) do
  #     {:ok, %{user: user}} -> {:ok, user}
  #     {:error, reason} -> {:error, reason}
  #   end
  # rescue
  #   _ -> {:error, :invalid_token}
  # end

  defp create_session_after_password_change(user) do
    # Create a new session after password change
    Auth.create_user_session(user, nil)
  end
end
