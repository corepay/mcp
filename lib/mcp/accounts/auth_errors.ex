defmodule Mcp.Accounts.AuthErrors do
  @moduledoc """
  Helper module for handling authentication errors.
  """

  def format_user_error(:invalid_credentials), do: "Invalid email or password. Please try again."
  def format_user_error(:account_locked), do: "Account is locked. Please contact support."
  def format_user_error(:token_expired), do: "Your session has expired. Please sign in again."
  def format_user_error(_), do: "Authentication failed."

  def get_recovery_instructions(:account_locked), do: ["Contact support at support@example.com"]
  def get_recovery_instructions(_), do: []

  def create_error_response(type, context \\ %{}) do
    %{
      error: true,
      error_type: type,
      error_code: "JWT_002", # Simplified for now
      message: format_user_error(type),
      recovery: get_recovery_instructions(type),
      context: context
    }
  end

  def error_type_to_http_status(:invalid_credentials), do: :unauthorized
  def error_type_to_http_status(:token_expired), do: :unauthorized
  def error_type_to_http_status(:account_locked), do: :forbidden
  def error_type_to_http_status(:insufficient_permissions), do: :forbidden
  def error_type_to_http_status(:rate_limit_exceeded), do: :too_many_requests
  def error_type_to_http_status(_), do: :internal_server_error
end
