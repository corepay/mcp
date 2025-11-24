defmodule Mcp.Accounts do
  @moduledoc """
  Accounts domain for user authentication and management.
  
  This domain handles:
  - User registration and authentication
  - JWT token-based sessions
  - OAuth provider integration
  - TOTP 2FA management
  - Registration settings and policies
  """

  use Ash.Domain,
    otp_app: :mcp

  resources do
    resource Mcp.Accounts.User
  end
end
