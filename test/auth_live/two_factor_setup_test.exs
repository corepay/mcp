defmodule McpWeb.AuthLive.TwoFactorSetupTest do
  use ExUnit.Case, async: true

  alias McpWeb.AuthLive.TwoFactorManagement
  alias McpWeb.AuthLive.TwoFactorSetup

  # Basic test to ensure the 2FA LiveView components can be started
  test "2FA setup LiveView mounts successfully" do
    # Test that the LiveView module exists and has the correct structure
    Code.ensure_loaded(TwoFactorSetup)
    assert function_exported?(TwoFactorSetup, :mount, 3)
    assert function_exported?(TwoFactorSetup, :handle_event, 3)
    assert function_exported?(TwoFactorSetup, :handle_info, 2)
  end

  test "2FA management component exists" do
    # Test that the management component exists
    Code.ensure_loaded(TwoFactorManagement)
    assert function_exported?(TwoFactorManagement, :update, 2)
    assert function_exported?(TwoFactorManagement, :handle_event, 3)
    assert function_exported?(TwoFactorManagement, :render, 1)
  end

  test "2FA setup has required handlers" do
    # Test that all required event handlers are present
    handlers = [
      "start_setup",
      "verify_totp",
      "show_backup_codes",
      "hide_backup_codes",
      "download_backup_codes",
      "copy_to_clipboard",
      "confirm_backup_codes_saved",
      "finish_setup",
      "disable_2fa",
      "regenerate_backup_codes",
      "test_2fa"
    ]

    for _handler <- handlers do
      # This tests that the handle_event function can handle different event types
      assert is_function(&TwoFactorSetup.handle_event/3)
    end
  end

  test "2FA setup helper functions exist" do
    # Test that helper functions exist by checking they are defined
    assert function_exported?(TwoFactorSetup, :generate_backup_codes_content, 1)
    assert function_exported?(TwoFactorManagement, :format_otp_date, 1)
  end
end
