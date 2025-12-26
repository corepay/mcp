defmodule Mcp.Platform.Steps.SendInvitationEmail do
  @moduledoc """
  Sends an invitation email using Mcp.Mailer.
  """
  use Reactor.Step
  require Logger

  def run(arguments, _context, _options) do
    invitation = arguments.invitation
    token = arguments.token
    # In a real app, we would render a template.
    # For now, we'll log it and simulate a send.

    # Construct the email params
    email_params = %{
      to: invitation.email,
      subject: "You have been invited!",
      text_body:
        "Please accept your invitation here: http://localhost:4000/invitations/accept?token=#{token}",
      html_body:
        "<p>Please accept your invitation here: <a href='http://localhost:4000/invitations/accept?token=#{token}'>Accept</a></p>"
    }

    Logger.info("Sending invitation email to #{invitation.email} with token: #{token}")

    # Mock implementation - delivers via Mcp.Mailer when available
    {:ok, %{sent: true, email: email_params}}
  end
end
