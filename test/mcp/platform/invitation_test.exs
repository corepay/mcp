defmodule Mcp.Platform.InvitationTest do
  use Mcp.DataCase, async: true

  alias Mcp.Accounts.User
  alias Mcp.Platform.Invitation
  alias Mcp.Platform.Reactors.DeveloperInviteReactor
  alias Mcp.Platform.Steps.GenerateInvitationToken
  alias Mcp.Platform.Team
  alias Mcp.Platform.TeamScope

  describe "Invitations" do
    test "can create an invitation via Reactor" do
      # Setup inviter
      inviter = User.create_for_test(%{email: "admin@example.com", password: "Password123!"})

      # Setup entity context (Tenant)
      tenant_id = Ecto.UUID.generate()

      # Setup Team (optional but good for test)
      team =
        Team.create!(%{
          name: "Dev Team",
          slug: "dev-team",
          entity_type: :tenant,
          entity_id: tenant_id
        })

      # Create Scope
      scope =
        TeamScope.create!(%{
          team_id: team.id,
          entity_type: :tenant,
          entity_id: tenant_id
        })

      # Run Reactor
      {:ok, invitation} =
        Reactor.run(DeveloperInviteReactor, %{
          email: "newdev@example.com",
          role: :developer,
          permissions: [:read, :write],
          entity_type: :tenant,
          entity_id: tenant_id,
          team_id: team.id,
          scope_id: scope.id,
          inviter: inviter
        })

      # Assetions
      assert invitation.email == "newdev@example.com"
      assert invitation.role == :developer
      # Should be generated
      assert invitation.token
      assert invitation.status == :pending
      # Should be set
      assert invitation.expires_at
      assert invitation.team_id == team.id

      # Check persistence
      fetched = Invitation.by_token!(invitation.token)
      assert fetched.id == invitation.id
    end

    test "generates secure tokens" do
      {:ok, token1} = GenerateInvitationToken.run(nil, nil, nil)
      {:ok, token2} = GenerateInvitationToken.run(nil, nil, nil)

      assert String.length(token1) > 20
      assert token1 != token2
    end
  end
end
