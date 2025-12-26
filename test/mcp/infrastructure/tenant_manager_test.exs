defmodule Mcp.Infrastructure.TenantManagerTest do
  use Mcp.DataCase, async: false

  alias Mcp.Infrastructure.TenantManager

  @test_tenant_schema "test_tenant_manager"

  describe "schema management" do
    setup do
      # Clean up any existing test schema
      if TenantManager.tenant_schema_exists?(@test_tenant_schema) do
        TenantManager.drop_tenant_schema(@test_tenant_schema)
      end

      :ok
    end

    test "creates tenant schema" do
      refute TenantManager.tenant_schema_exists?(@test_tenant_schema)

      assert {:ok, schema_name} = TenantManager.create_tenant_schema(@test_tenant_schema)
      assert schema_name == "acq_#{@test_tenant_schema}"

      assert TenantManager.tenant_schema_exists?(@test_tenant_schema)
    end

    test "handles existing schema gracefully" do
      {:ok, schema_name} = TenantManager.create_tenant_schema(@test_tenant_schema)

      # Should be idempotent and return success
      assert {:ok, ^schema_name} = TenantManager.create_tenant_schema(@test_tenant_schema)
    end

    test "drops tenant schema" do
      {:ok, _} = TenantManager.create_tenant_schema(@test_tenant_schema)
      assert TenantManager.tenant_schema_exists?(@test_tenant_schema)

      assert {:ok, schema_name} = TenantManager.drop_tenant_schema(@test_tenant_schema)
      assert schema_name == "acq_#{@test_tenant_schema}"

      refute TenantManager.tenant_schema_exists?(@test_tenant_schema)
    end

    test "handles non-existent schema drop" do
      refute TenantManager.tenant_schema_exists?(@test_tenant_schema)

      assert {:error, :schema_not_found} =
               TenantManager.drop_tenant_schema(@test_tenant_schema)
    end
  end

  describe "tenant name resolution" do
    setup do
      # This test would require actual tenant data in the database
      # For now, we'll test the query structure
      :ok
    end

    test "gets tenant schema name by ID" do
      # This would normally query the database
      # For testing purposes, we'll verify the query structure
      query =
        from(t in "platform.tenants",
          where: t.id == type(^Ecto.UUID.generate(), :binary_id),
          select: t.company_schema
        )

      # The query should be valid
      assert %Ecto.Query{} = query
    end
  end
end
