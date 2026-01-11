defmodule Mcp.Platform.SharedEntitiesTest do
  use Mcp.DataCase
  alias Mcp.Accounts.User
  alias Mcp.Platform.Address
  alias Mcp.Platform.Tenant

  # Use existing tenant from seeder
  @test_tenant_subdomain "acme"

  setup do
    # Create users
    user1 = user_fixture()
    user2 = user_fixture()

    # Get existing tenant (created by seeder)
    {:ok, tenant} = Tenant.by_subdomain(@test_tenant_subdomain)

    # Create team for tenant
    unique_id = System.unique_integer([:positive])

    team =
      Mcp.Platform.Team
      |> Ash.Changeset.for_create(:create, %{
        name: "Default Team #{unique_id}",
        slug: "default-team-#{unique_id}",
        entity_type: :tenant,
        entity_id: tenant.id
      })
      |> Ash.create!()

    # Add user1 to team
    Mcp.Platform.TeamMember
    |> Ash.Changeset.for_create(:create, %{
      team_id: team.id,
      user_id: user1.id,
      user_profile_id: Ash.UUID.generate()
    })
    |> Ash.create!()

    %{user1: user1, user2: user2, tenant: tenant}
  end

  describe "Address Policies" do
    test "user can create and read their own address", %{user1: user} do
      address =
        address_fixture(user, %{
          owner_type: :user,
          owner_id: user.id,
          line1: "123 Main St",
          city: "Metropolis",
          postal_code: "12345",
          country: "US"
        })

      assert {:ok, fetched} = Address.read_one(address.id, actor: user)
      assert fetched.id == address.id
    end

    test "user cannot read another user's address", %{user1: user1, user2: user2} do
      address =
        address_fixture(user1, %{
          owner_type: :user,
          owner_id: user1.id,
          line1: "123 Main St",
          city: "Metropolis",
          postal_code: "12345",
          country: "US"
        })

      result = Address.read_one(address.id, actor: user2)
      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} = result
    end

    test "user can create and read tenant address if member", %{user1: user, tenant: tenant} do
      address =
        Address
        |> Ash.Changeset.for_create(:create, %{
          owner_type: :tenant,
          owner_id: tenant.id,
          line1: "HQ",
          city: "Gotham",
          postal_code: "99999",
          country: "US"
        })
        |> Ash.create!(actor: user)

      assert {:ok, fetched} = Address.read_one(address.id, actor: user)
      assert fetched.id == address.id
    end

    test "can create address with geo_location", %{user1: user} do
      address =
        address_fixture(user, %{
          owner_type: :user,
          owner_id: user.id,
          line1: "Geo St",
          city: "Metropolis",
          postal_code: "12345",
          country: "US",
          geo_location: %Geo.Point{coordinates: {30.0, -90.0}, srid: 4326}
        })

      assert address.geo_location == %Geo.Point{coordinates: {30.0, -90.0}, srid: 4326}
    end
  end

  describe "Email Policies" do
    test "update :set_primary unsets other emails", %{user1: user} do
      assert {:ok, email1} =
               Mcp.Platform.Email
               |> Ash.Changeset.for_create(:create, %{
                 owner_type: :user,
                 owner_id: user.id,
                 email: "test1@example.com",
                 is_primary: true
               })
               |> Ash.create(actor: user)

      assert {:ok, email2} =
               Mcp.Platform.Email
               |> Ash.Changeset.for_create(:create, %{
                 owner_type: :user,
                 owner_id: user.id,
                 email: "test2@example.com",
                 is_primary: false
               })
               |> Ash.create(actor: user)

      # Initially email1 is primary
      assert email1.is_primary
      assert !email2.is_primary

      # Set email2 as primary
      email2 =
        email2
        |> Ash.Changeset.for_update(:set_primary)
        |> Ash.update!(actor: user)

      assert email2.is_primary

      # Refresh email1
      email1 = Ash.reload!(email1, actor: user)
      assert !email1.is_primary
    end
  end

  defp user_fixture do
    User
    |> Ash.Changeset.for_create(:register, %{
      email: "user_#{System.unique_integer()}@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    })
    |> Ash.create!()
  end

  defp address_fixture(actor, attrs) do
    Address
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(actor: actor)
  end
end
