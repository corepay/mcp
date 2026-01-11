defmodule Mcp.Platform.ApiKeyTest do
  use Mcp.DataCase
  alias Mcp.Platform.ApiKey
  alias Mcp.Platform.Tenant

  # Use existing tenant from seeder
  @test_tenant_subdomain "acme"

  describe "api_keys" do
    setup do
      # Get existing tenant (created by seeder)
      {:ok, tenant} = Tenant.by_subdomain(@test_tenant_subdomain)

      {:ok, tenant: tenant}
    end

    test "create/1 generates a key and hash", %{tenant: tenant} do
      {:ok, api_key} =
        ApiKey.create(%{
          prefix: "mcp_test",
          type: :developer,
          owner_id: tenant.id,
          owner_type: :tenant
        })

      assert api_key.prefix == "mcp_test"
      assert api_key.owner_id == tenant.id
      assert api_key.key_hash

      # Verify raw key is available in metadata
      raw_key = api_key.__metadata__.raw_key
      assert raw_key
      assert String.starts_with?(raw_key, "mcp_test_")

      # Verify hash matches
      hashed = ApiKey.hash_key(raw_key)
      assert hashed == api_key.key_hash
    end

    test "authenticate/1 verifies valid token", %{tenant: tenant} do
      {:ok, api_key} =
        ApiKey.create(%{
          prefix: "mcp_test",
          type: :developer,
          owner_id: tenant.id,
          owner_type: :tenant
        })

      raw_key = api_key.__metadata__.raw_key

      {:ok, authenticated_key} = ApiKey.authenticate(raw_key)
      assert authenticated_key.id == api_key.id
    end

    test "authenticate/1 fails with invalid token", %{tenant: tenant} do
      {:ok, _api_key} =
        ApiKey.create(%{
          prefix: "mcp_test",
          type: :developer,
          owner_id: tenant.id,
          owner_type: :tenant
        })

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} =
               ApiKey.authenticate("invalid_token")
    end

    test "authenticate/1 fails if key is revoked", %{tenant: tenant} do
      {:ok, api_key} =
        ApiKey.create(%{
          prefix: "mcp_test",
          type: :developer,
          owner_id: tenant.id,
          owner_type: :tenant
        })

      raw_key = api_key.__metadata__.raw_key

      {:ok, revoked_key} = ApiKey.revoke(api_key)
      assert revoked_key.revoked_at

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} =
               ApiKey.authenticate(raw_key)
    end
  end
end
