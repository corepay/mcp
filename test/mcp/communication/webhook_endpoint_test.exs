defmodule Mcp.Communication.WebhookEndpointTest do
  @moduledoc false
  use Mcp.DataCase

  alias Mcp.Accounts.User
  alias Mcp.Communication.WebhookEndpoint
  alias Mcp.Platform.Team
  alias Mcp.Platform.TeamMember
  alias Mcp.Platform.Tenant

  # Use existing tenant from seeder
  @test_tenant_subdomain "acme"

  setup do
    unique_id = "webhook#{System.unique_integer([:positive])}"
    {:ok, user} = User.register("#{unique_id}@example.com", "Password123!")

    # Get existing tenant (created by seeder)
    {:ok, tenant} = Tenant.by_subdomain(@test_tenant_subdomain)

    team =
      Team.create!(
        %{
          name: "Webhook Test Team #{unique_id}",
          slug: "webhook-team-#{unique_id}",
          entity_type: :tenant,
          entity_id: tenant.id,
          description: "Auto-created team for webhook tests"
        },
        actor: user
      )

    TeamMember.create!(
      %{
        role: :admin,
        user_id: user.id,
        team_id: team.id,
        # Satisfy DB constraint
        user_profile_id: Ash.UUID.generate()
      },
      actor: user
    )

    {:ok, user: user, tenant: tenant}
  end

  test "creates endpoint successfully", %{user: user, tenant: tenant} do
    endpoint =
      WebhookEndpoint
      |> Ash.Changeset.for_create(
        :create,
        %{
          url: "https://example.com",
          events: ["test.event"],
          tenant_id: tenant.id
        },
        actor: user
      )
      |> Ash.create!()

    assert endpoint.url == "https://example.com"
    # Should be generated
    assert endpoint.secret
    assert endpoint.tenant_id == tenant.id
  end

  test "rotates secret", %{user: user, tenant: tenant} do
    endpoint =
      WebhookEndpoint
      |> Ash.Changeset.for_create(
        :create,
        %{
          url: "https://example.com",
          events: ["test.event"],
          tenant_id: tenant.id
        },
        actor: user
      )
      |> Ash.create!()

    original_secret = endpoint.secret

    updated_endpoint =
      endpoint
      |> Ash.Changeset.for_update(:rotate_secret, %{}, actor: user)
      |> Ash.update!()

    assert updated_endpoint.secret != original_secret
  end

  test "enforces tenant access on create", %{user: user} do
    # User attempting to create for random tenant
    # Using a fake UUID for tenant ID
    random_tenant_id = Ash.UUID.generate()

    assert_raise Ash.Error.Forbidden, fn ->
      WebhookEndpoint
      |> Ash.Changeset.for_create(
        :create,
        %{
          url: "https://evil.com",
          events: ["all"],
          tenant_id: random_tenant_id
        },
        actor: user
      )
      |> Ash.create!()
    end
  end
end
