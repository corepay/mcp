defmodule Mcp.Platform.Reactors.DeveloperInviteReactor do
  @moduledoc """
  Orchestrates the process of inviting a developer (or any user) to an entity.
  """
  use Ash.Reactor

  ash do
    default_domain Mcp.Platform
  end

  # Inputs
  input(:email)
  input(:role)
  input(:permissions)
  input(:entity_type)
  input(:entity_id)
  input(:team_id)
  input(:scope_id)
  input(:inviter)

  # 1. Generate Token
  step :generate_token, Mcp.Platform.Steps.GenerateInvitationToken do
    # No inputs needed for random bytes
  end

  # 2. Create Invitation Record
  create :create_invitation, Mcp.Platform.Invitation, :create do
    inputs %{
      email: input(:email),
      role: input(:role),
      permissions: input(:permissions),
      entity_type: input(:entity_type),
      entity_id: input(:entity_id),
      team_id: input(:team_id),
      scope_id: input(:scope_id),
      token: result(:generate_token),
      expires_at: value(DateTime.add(DateTime.utc_now(), 24, :hour))
    }

    actor input(:inviter)
  end

  # 3. Send Email
  step :send_email, Mcp.Platform.Steps.SendInvitationEmail do
    argument :invitation, result(:create_invitation)
    argument :token, result(:generate_token)
  end

  return :create_invitation
end
