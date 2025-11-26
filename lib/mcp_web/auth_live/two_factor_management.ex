defmodule McpWeb.AuthLive.TwoFactorManagement do
  @moduledoc """
  LiveComponent for managing existing 2FA settings.

  This component provides:
  - 2FA status display and management
  - Backup codes viewing and regeneration
  - 2FA testing functionality
  - 2FA disable confirmation
  - Security settings management
  """

  use McpWeb, :live_component

  alias Mcp.Accounts.TOTP

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(:current_user, assigns.current_user)
      |> assign(:backup_codes, assigns.backup_codes || [])
      |> assign(:test_code, "")
      |> assign(:show_backup_codes, false)
      |> assign(:show_disable_confirmation, false)
      |> assign(:disable_confirmation, "")
      |> assign(:loading, false)
      |> assign(:errors, %{})

    {:ok, socket}
  end

  @impl true
  def handle_event("test_2fa", %{"test_code" => code}, socket) do
    case TOTP.verify_totp_code(socket.assigns.current_user, code) do
      :ok ->
        socket =
          socket
          |> put_flash(
            :success,
            "2FA test successful! Your authenticator app is working correctly."
          )
          |> assign(:test_code, "")
          |> push_patch(to: "/settings/security")

        {:noreply, socket}

      {:error, reason} ->
        error_message = translate_totp_error(reason)

        socket =
          socket
          |> put_flash(:error, "2FA test failed: #{error_message}")
          |> push_patch(to: "/settings/security")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_backup_codes", _params, socket) do
    socket =
      socket
      |> assign(:show_backup_codes, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_backup_codes", _params, socket) do
    socket =
      socket
      |> assign(:show_backup_codes, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("regenerate_backup_codes", _params, socket) do
    socket = assign(socket, :loading, true)

    case TOTP.regenerate_backup_codes(socket.assigns.current_user) do
      {:ok, updated_user, new_backup_codes} ->
        send(self(), {:backup_codes_regenerated, updated_user, new_backup_codes})

        socket =
          socket
          |> assign(:loading, false)
          |> put_flash(:success, "New backup codes generated. Please save them securely.")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:loading, false)
          |> put_flash(:error, "Failed to regenerate backup codes: #{reason}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_disable_confirmation", _params, socket) do
    socket =
      socket
      |> assign(:show_disable_confirmation, true)
      |> assign(:disable_confirmation, "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_disable_confirmation", _params, socket) do
    socket =
      socket
      |> assign(:show_disable_confirmation, false)
      |> assign(:disable_confirmation, "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("disable_2fa", %{"confirmation" => confirmation}, socket) do
    if confirmation != "DISABLE" do
      socket =
        socket
        |> put_flash(:error, "Please type 'DISABLE' to confirm 2FA removal.")

      {:noreply, socket}
    else
      socket = assign(socket, :loading, true)

      case TOTP.disable_totp(socket.assigns.current_user) do
        {:ok, updated_user} ->
          send(self(), {:two_factor_disabled, updated_user})

          socket =
            socket
            |> assign(:loading, false)
            |> put_flash(:info, "2FA has been disabled on your account.")

          {:noreply, socket}

        {:error, reason} ->
          socket =
            socket
            |> assign(:loading, false)
            |> put_flash(:error, "Failed to disable 2FA: #{reason}")

          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("copy_to_clipboard", %{"text" => text}, socket) do
    socket =
      socket
      |> push_event("copy-to-clipboard", %{text: text})

    {:noreply, socket}
  end

  # Handle async operations
  def handle_info({:backup_codes_regenerated, updated_user, new_backup_codes}, socket) do
    socket =
      socket
      |> assign(:current_user, updated_user)
      |> assign(:backup_codes, new_backup_codes)
      |> assign(:show_backup_codes, true)

    {:noreply, socket}
  end

  def handle_info({:two_factor_disabled, updated_user}, socket) do
    socket =
      socket
      |> assign(:current_user, updated_user)
      |> assign(:show_disable_confirmation, false)
      |> push_patch(to: "/settings/security")

    {:noreply, socket}
  end

  # Private helper functions
  defp translate_totp_error(:invalid_code), do: "Invalid verification code. Please try again."

  # defp translate_totp_error(:code_already_used), do: "This code has already been used. Please wait for a new one."
  # defp translate_totp_error(:totp_not_enabled), do: "2FA is not enabled for this account."
  defp translate_totp_error(reason), do: "Verification failed: #{inspect(reason)}"

  defp format_otp_date(nil), do: "Unknown"

  defp format_otp_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end
end
