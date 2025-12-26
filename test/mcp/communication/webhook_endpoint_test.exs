defmodule Mcp.Communication.WebhookEndpointTest do
  @moduledoc false
  use Mcp.DataCase

  alias Mcp.Accounts.User
  alias Mcp.Communication.WebhookEndpoint
  alias Mcp.Platform.Team
  alias Mcp.Platform.TeamMember
  alias Mcp.Platform.Tenant

  setup do
    {:ok, user} = User.register("user@example.com", "Password123!")

    tenant_uuid = Ash.UUID.generate()

    tenant =
      Tenant.create!(
        %{
          name: "Test Tenant",
          slug: "test-tenant-#{tenant_uuid}",
          subdomain: "test-#{tenant_uuid}"
        },
        actor: user
      )

    team =
      Team.create!(
        %{
          name: "Tenant Admin Team",
          slug: "tenant-admin-#{tenant_uuid}",
          entity_type: :tenant,
          entity_id: tenant.id,
          description: "Auto-created admin team"
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
