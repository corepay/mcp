defmodule Mcp.Registration.EmailService do
  @moduledoc """
  Handles email notifications for registration workflow.
  """

  @doc """
  Sends a verification email to the user.

  ## Parameters
  - `email` - User's email address
  - `user_id` - User's ID

  ## Returns
  - `:ok` or `:mocked`
  """
  def send_verification_email(_email, _user_id) do
    # Mock email sending
    :mocked
  end

  @doc """
  Sends an approval notification to admins.

  ## Parameters
  - `request` - The registration request struct

  ## Returns
  - `:ok` or `:mocked`
  """
  def send_admin_approval_notification(_request) do
    # Mock email sending
    :mocked
  end
end
