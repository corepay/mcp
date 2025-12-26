defmodule Mcp.Platform.CustomDomainTest do
  @moduledoc false
  use Mcp.DataCase, async: true
  import Mox

  alias Mcp.Platform.CustomDomain

  # Make sure mocks are verified when test exits
  setup :verify_on_exit!

  setup do
    tenant =
      Mcp.Platform.Tenant
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Tenant",
        slug: "test-#{System.unique_integer([:positive])}",
        subdomain: "test-#{System.unique_integer([:positive])}"
      })
      |> Ash.create!()

    %{tenant: tenant}
  end

  # Helper to setup actor
  defp setup_actor(tenant) do
    user =
      Mcp.Accounts.User
      |> Ash.Changeset.for_create(:register, %{
        email: "user_#{System.unique_integer([:positive])}@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "Test",
        last_name: "User"
      })
      |> Ash.create!()

    # Create Team (Tenant usually creates one, but keeping it simple)
    team =
      Mcp.Platform.Team
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Team",
        slug: "team-#{System.unique_integer([:positive])}",
        entity_type: :tenant,
        entity_id: tenant.id
      })
      |> Ash.create!()

    # Add user to team
    _member =
      Mcp.Platform.TeamMember
      |> Ash.Changeset.for_create(:create, %{
        team_id: team.id,
        user_id: user.id,
        role: :admin,
        user_profile_id: Ash.UUID.generate()
      })
      |> Ash.create!()

    user
  end

  setup %{tenant: tenant} do
    %{user: setup_actor(tenant)}
  end

  describe "create/1" do
    test "creates a custom domain in pending_verification state", %{tenant: tenant, user: user} do
      {:ok, domain} =
        CustomDomain
        |> Ash.Changeset.for_create(:create, %{
          domain: "example.com",
          tenant_id: tenant.id
        })
        |> Ash.create(actor: user)

      assert domain.state == :pending_verification
      assert domain.verification_record_name == "_mcp_challenge"
      assert is_binary(domain.verification_record_value)
      assert domain.tenant_id == tenant.id
    end
  end

  describe "verify/1" do
    test "transitions to verified if DNS check passes", %{tenant: tenant, user: user} do
      {:ok, domain} =
        CustomDomain
        |> Ash.Changeset.for_create(:create, %{
          domain: "verified.com",
          tenant_id: tenant.id
        })
        |> Ash.create(actor: user)

      # Expect call to DnsVerifierMock
      Mcp.Infrastructure.DnsVerifierMock
      |> expect(:verify_txt, fn _domain, _value -> {:ok, true} end)

      {:ok, verified_domain} =
        domain
        |> Ash.Changeset.for_update(:verify)
        |> Ash.update(actor: user)

      assert verified_domain.state == :verified
    end

    test "fails if DNS check fails", %{tenant: tenant, user: user} do
      {:ok, domain} =
        CustomDomain
        |> Ash.Changeset.for_create(:create, %{
          domain: "failed.com",
          tenant_id: tenant.id
        })
        |> Ash.create(actor: user)

      # Expect call to DnsVerifierMock
      Mcp.Infrastructure.DnsVerifierMock
      |> expect(:verify_txt, fn _domain, _value -> {:ok, false} end)

      assert {:error, %Ash.Error.Unknown{errors: [error]}} =
               domain
               |> Ash.Changeset.for_update(:verify)
               |> Ash.update(actor: user)

      assert Exception.message(error) =~ "DNS Verification failed"

      # Reload to confirm state didn't change (transaction rollback)
      reloaded = Ash.get!(CustomDomain, domain.id, actor: user)
      assert reloaded.state == :pending_verification
    end
  end
end
