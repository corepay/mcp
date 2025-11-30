defmodule McpWeb.AuthLive.TwoFactorSetup do
  @moduledoc """
  LiveView for TOTP 2FA setup and management.

  This LiveView provides a comprehensive 2FA setup experience with:
  - Step-by-step TOTP setup wizard
  - QR code generation for authenticator apps
  - Backup codes generation and display
  - 2FA management (enable/disable)
  - Test verification functionality
  - Recovery options and security guidance
  - Accessibility compliance and mobile-responsive design
  """

  use McpWeb, :live_view
  import Phoenix.Component

  alias Mcp.Accounts.TOTP

  # Setup states for the wizard

  @impl true
  def mount(_params, _session, socket) do
    # Check if user is authenticated
    current_user = get_connect_info(socket, :user_data)

    if current_user do
      # Check current 2FA status
      totp_enabled = TOTP.totp_enabled?(current_user)

      socket =
        socket
        |> assign(:page_title, if(totp_enabled, do: "Manage 2FA", else: "Setup 2FA"))
        |> assign(:current_user, current_user)
        |> assign(:totp_enabled, totp_enabled)
        |> assign(:setup_state, if(totp_enabled, do: :manage, else: :intro))
        |> assign(:step_index, 0)
        |> assign(:totp_secret, nil)
        |> assign(:qr_code, nil)
        |> assign(:backup_codes, [])
        |> assign(:verification_code, "")
        |> assign(:test_code, "")
        |> assign(:show_backup_codes, false)
        |> assign(:backup_codes_downloaded, false)
        |> assign(:loading, false)
        |> assign(:errors, %{})
        |> assign(:flash_messages, %{})
        |> assign(:announcements, [])
        |> assign(:copied_to_clipboard, false)
        |> assign(:form_data, %{})

      {:ok, socket}
    else
      # Redirect to login if not authenticated
      {:ok, push_navigate(socket, to: "/sign_in?return_to=/2fa/setup")}
    end
  end

  @impl true
  def handle_event("start_setup", _params, socket) do
    socket = assign(socket, :loading, true)

    case TOTP.setup_totp(socket.assigns.current_user) do
      {:ok, setup_data} ->
        socket =
          socket
          |> assign(:loading, false)
          |> assign(:setup_state, :qr_code)
          |> assign(:step_index, 1)
          |> assign(:totp_secret, setup_data.secret)
          |> assign(:qr_code, setup_data.qr_code)
          |> add_announcement(
            "TOTP setup initiated. Please scan the QR code with your authenticator app."
          )
          |> add_flash_message(:info, "Step 1: Scan the QR code with your authenticator app")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:loading, false)
          |> add_flash_message(:error, "Failed to setup 2FA: #{reason}")
          |> add_announcement("2FA setup failed")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("verify_totp", %{"verification_code" => code}, socket) do
    socket = assign(socket, :loading, true)

    case TOTP.enable_totp(socket.assigns.current_user, code) do
      {:ok, updated_user, backup_codes} ->
        socket =
          socket
          |> assign(:loading, false)
          |> assign(:setup_state, :backup_codes)
          |> assign(:step_index, 2)
          |> assign(:current_user, updated_user)
          |> assign(:backup_codes, backup_codes)
          |> assign(:totp_enabled, true)
          |> add_announcement("2FA verification successful. Please save your backup codes.")
          |> add_flash_message(
            :success,
            "2FA enabled! Please save your backup codes in a secure location."
          )

        {:noreply, socket}

      {:error, reason} ->
        error_message = translate_totp_error(reason)

        socket =
          socket
          |> assign(:loading, false)
          |> put_flash(:error, error_message)
          |> add_announcement("2FA verification failed")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_backup_codes", _params, socket) do
    socket =
      socket
      |> assign(:show_backup_codes, true)
      |> add_announcement("Backup codes displayed. Please save them securely.")

    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_backup_codes", _params, socket) do
    socket =
      socket
      |> assign(:show_backup_codes, false)
      |> add_announcement("Backup codes hidden.")

    {:noreply, socket}
  end

  @impl true
  def handle_event("download_backup_codes", _params, socket) do
    # Generate downloadable backup codes content
    backup_content = generate_backup_codes_content(socket.assigns.backup_codes)

    socket =
      socket
      |> assign(:backup_codes_downloaded, true)
      |> push_event("download-backup-codes", %{content: backup_content})
      |> add_announcement("Backup codes downloaded.")
      |> add_flash_message(:success, "Backup codes downloaded! Keep them in a safe place.")

    {:noreply, socket}
  end

  @impl true
  def handle_event("copy_to_clipboard", %{"text" => text}, socket) do
    socket =
      socket
      |> assign(:copied_to_clipboard, true)
      |> push_event("copy-to-clipboard", %{text: text})
      |> add_announcement("Copied to clipboard.")

    # Reset the copied state after 2 seconds
    Process.send_after(self(), :reset_copied_state, 2000)

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_backup_codes_saved", _params, socket) do
    if socket.assigns.backup_codes_downloaded do
      socket =
        socket
        |> assign(:setup_state, :complete)
        |> assign(:step_index, 3)
        |> add_announcement("2FA setup completed successfully!")
        |> add_flash_message(:success, "2FA is now enabled on your account!")

      {:noreply, socket}
    else
      socket =
        socket
        |> add_flash_message(
          :warning,
          "Please download or copy your backup codes before continuing."
        )
        |> add_announcement("Backup codes must be saved first.")

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("finish_setup", _params, socket) do
    {:noreply, push_navigate(socket, to: "/settings/security")}
  end

  @impl true
  def handle_event("disable_2fa", %{"confirmation" => confirmation}, socket) do
    if confirmation != "DISABLE" do
      socket =
        socket
        |> add_flash_message(:error, "Please type 'DISABLE' to confirm 2FA removal.")
        |> add_announcement("2FA disable confirmation failed.")

      {:noreply, socket}
    else
      socket = assign(socket, :loading, true)

      case TOTP.disable_totp(socket.assigns.current_user) do
        {:ok, updated_user} ->
          socket =
            socket
            |> assign(:loading, false)
            |> assign(:current_user, updated_user)
            |> assign(:totp_enabled, false)
            |> assign(:setup_state, :intro)
            |> assign(:step_index, 0)
            |> add_announcement("2FA disabled successfully.")
            |> add_flash_message(:info, "2FA has been disabled on your account.")

          {:noreply, socket}

        {:error, reason} ->
          socket =
            socket
            |> assign(:loading, false)
            |> add_flash_message(:error, "Failed to disable 2FA: #{reason}")
            |> add_announcement("2FA disable failed.")

          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("regenerate_backup_codes", _params, socket) do
    socket = assign(socket, :loading, true)

    case TOTP.regenerate_backup_codes(socket.assigns.current_user) do
      {:ok, updated_user, new_backup_codes} ->
        socket =
          socket
          |> assign(:loading, false)
          |> assign(:current_user, updated_user)
          |> assign(:backup_codes, new_backup_codes)
          |> assign(:backup_codes_downloaded, false)
          |> assign(:show_backup_codes, true)
          |> add_announcement("New backup codes generated.")
          |> add_flash_message(:success, "New backup codes generated. Please save them securely.")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:loading, false)
          |> add_flash_message(:error, "Failed to regenerate backup codes: #{reason}")
          |> add_announcement("Backup codes regeneration failed.")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("test_2fa", %{"test_code" => code}, socket) do
    case TOTP.verify_totp_code(socket.assigns.current_user, code) do
      :ok ->
        socket =
          socket
          |> add_flash_message(
            :success,
            "2FA test successful! Your authenticator app is working correctly."
          )
          |> add_announcement("2FA test passed.")
          |> assign(:test_code, "")

        {:noreply, socket}

      {:error, reason} ->
        error_message = translate_totp_error(reason)

        socket =
          socket
          |> add_flash_message(:error, "2FA test failed: #{error_message}")
          |> add_announcement("2FA test failed.")

        {:noreply, socket}
    end
  end

  # Handle timeout for copied state reset
  @impl true
  def handle_info(:reset_copied_state, socket) do
    {:noreply, assign(socket, :copied_to_clipboard, false)}
  end

  # Private helper functions

  defp translate_totp_error(:invalid_code), do: "Invalid verification code. Please try again."

  # defp translate_totp_error(:code_already_used), do: "This code has already been used. Please wait for a new one."
  # defp translate_totp_error(:totp_not_enabled), do: "2FA is not enabled for this account."
  defp translate_totp_error(reason), do: "Verification failed: #{inspect(reason)}"

  def generate_backup_codes_content(backup_codes) do
    content = [
      "MCP Platform - 2FA Backup Codes",
      "Generated on: #{DateTime.to_string(DateTime.utc_now())}",
      "",
      "IMPORTANT: Keep these codes in a safe place. Each code can only be used once.",
      "",
      "Backup Codes:"
    ]

    codes_content =
      Enum.with_index(backup_codes, 1)
      |> Enum.map(fn {code, index} -> "#{index}. #{code}" end)

    (content ++ codes_content)
    |> Enum.join("\n")
  end

  defp add_announcement(socket, message) do
    announcements = [message | socket.assigns.announcements] |> Enum.take(3)
    assign(socket, :announcements, announcements)
  end

  defp add_flash_message(socket, kind, message) do
    flash_messages = Map.put(socket.assigns.flash_messages, kind, message)
    assign(socket, :flash_messages, flash_messages)
  end

  # Helper functions for step navigation
  defp setup_steps,
    do: [
      %{step: 1, title: "Scan QR Code", description: "Use your authenticator app"},
      %{step: 2, title: "Enter Code", description: "Verify the setup"},
      %{step: 3, title: "Save Backup Codes", description: "Download or copy your codes"},
      %{step: 4, title: "Complete", description: "2FA is now enabled"}
    ]
end
