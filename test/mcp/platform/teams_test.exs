defmodule Mcp.Platform.TeamsTest do
  use Mcp.DataCase, async: true

  alias Mcp.Accounts.User
  alias Mcp.Platform.Team
  alias Mcp.Platform.TeamMember
  alias Mcp.Platform.TeamScope

  describe "Teams" do
    test "can create and read a team" do
      team =
        Team.create!(%{
          name: "Engineering",
          slug: "engineering",
          description: "Core eng team",
          permissions: ["deploy", "manage_users"],
          entity_type: :tenant,
          entity_id: Ecto.UUID.generate()
        })

      assert team.name == "Engineering"
      assert team.permissions == ["deploy", "manage_users"]

      fetched_team = Team.by_id!(team.id)
      assert fetched_team.id == team.id
    end

    test "can add members to a team" do
      team =
        Team.create!(%{
          name: "Product",
          slug: "product",
          entity_type: :tenant,
          entity_id: Ecto.UUID.generate()
        })

      user = User.create_for_test(%{email: "alice@example.com", password: "Password123!"})

      member =
        TeamMember.create!(%{
          team_id: team.id,
          user_id: user.id,
          user_profile_id: Ecto.UUID.generate(),
          role: :admin
        })

      assert member.role == :admin
      assert member.team_id == team.id
      assert member.user_id == user.id

      # Verify relationship loading
      fetched_team = Team.by_id!(team.id, load: [:members])
      assert length(fetched_team.members) == 1
      assert hd(fetched_team.members).user_id == user.id
    end

    test "can assign scopes to a team" do
      team =
        Team.create!(%{
          name: "Support",
          slug: "support",
          entity_type: :tenant,
          entity_id: Ecto.UUID.generate()
        })

      tenant_id = Ecto.UUID.generate()

      scope =
        TeamScope.create!(%{
          team_id: team.id,
          entity_type: :tenant,
          entity_id: tenant_id
        })

      assert scope.entity_type == :tenant
      assert scope.entity_id == tenant_id

      team_with_scopes =
        Team.by_id!(team.id, load: [:scopes])

      assert length(team_with_scopes.scopes) == 1
      assert hd(team_with_scopes.scopes).entity_id == tenant_id
    end
  end
end
