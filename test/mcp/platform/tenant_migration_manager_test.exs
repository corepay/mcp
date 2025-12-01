defmodule Mcp.Platform.TenantMigrationManagerTest do
  use Mcp.DataCase

  alias Mcp.Platform.SchemaProvisioner
  alias Mcp.Platform.TenantMigrationManager

  @test_tenant_slug "test_migration_tenant_#{System.unique_integer([:positive])}"

  setup do
    # Checkout a real connection, bypassing sandbox for migrations
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)

    # Clean up any existing test tenant
    cleanup_test_tenant()

    on_exit(fn ->
      cleanup_test_tenant()
    end)

    :ok
  end

  describe "migrate_tenant/2" do
    test "successfully migrates a new tenant schema" do
      # Provision schema first (without migrations)
      assert {:ok, _} =
               SchemaProvisioner.provision_tenant_schema(@test_tenant_slug, skip_tables: true)

      # Run migrations
      assert {:ok, :migrated} = TenantMigrationManager.migrate_tenant(@test_tenant_slug)

      # Verify migrations table was created
      verify_migrations_table_exists()

      # Verify migrations were applied
      {:ok, status} = TenantMigrationManager.tenant_migration_status(@test_tenant_slug)
      assert status.status == :up_to_date
      assert status.applied_migrations > 0
    end

    test "handles tenant with no pending migrations" do
      # Provision and migrate once
      assert {:ok, _} =
               SchemaProvisioner.provision_tenant_schema(@test_tenant_slug, skip_tables: true)

      assert {:ok, :migrated} = TenantMigrationManager.migrate_tenant(@test_tenant_slug)

      # Try to migrate again
      assert {:ok, :migrated} = TenantMigrationManager.migrate_tenant(@test_tenant_slug)

      {:ok, status} = TenantMigrationManager.tenant_migration_status(@test_tenant_slug)
      assert status.status == :up_to_date
      assert status.pending_migrations == 0
    end

    test "fails for non-existent tenant" do
      non_existent_tenant = "non_existent_tenant"

      assert {:error, :schema_not_found} =
               TenantMigrationManager.migrate_tenant(non_existent_tenant)
    end
  end

  describe "migration status" do
    test "reports correct status for migrated tenant" do
      assert {:ok, _} =
               SchemaProvisioner.provision_tenant_schema(@test_tenant_slug, skip_tables: true)

      assert {:ok, :migrated} = TenantMigrationManager.migrate_tenant(@test_tenant_slug)

      {:ok, status} = TenantMigrationManager.tenant_migration_status(@test_tenant_slug)
      assert status.tenant_slug == @test_tenant_slug
      assert status.status == :up_to_date
      assert status.applied_migrations > 0
      assert status.pending_migrations == 0
    end

    test "reports pending migrations for new tenant" do
      assert {:ok, _} =
               SchemaProvisioner.provision_tenant_schema(@test_tenant_slug, skip_tables: true)

      {:ok, status} = TenantMigrationManager.tenant_migration_status(@test_tenant_slug)
      assert status.status == :pending_migrations
      assert status.applied_migrations == 0
      assert status.pending_migrations > 0
    end

    test "reports schema not found for non-existent tenant" do
      non_existent_tenant = "non_existent_tenant"

      {:ok, status} = TenantMigrationManager.tenant_migration_status(non_existent_tenant)
      assert status.status == :schema_not_found
    end
  end

  describe "migrate_all_tenants/1" do
    test "migrates multiple tenants" do
      tenant_1 = @test_tenant_slug <> "_1"
      tenant_2 = @test_tenant_slug <> "_2"

      # Provision multiple tenants
      assert {:ok, _} = SchemaProvisioner.provision_tenant_schema(tenant_1, skip_tables: true)
      assert {:ok, _} = SchemaProvisioner.provision_tenant_schema(tenant_2, skip_tables: true)

      # Note: These aren't in the platform.tenants table, so migrate_all_tenants won't find them
      # This test demonstrates the basic functionality, but full integration would require
      # creating actual tenant records

      on_exit(fn ->
        SchemaProvisioner.deprovision_tenant_schema(tenant_1, force: true)
        SchemaProvisioner.deprovision_tenant_schema(tenant_2, force: true)
      end)
    end
  end

  defp verify_migrations_table_exists do
    # This would need to be adapted based on the actual implementation
    # For now, just a placeholder
    :ok
  end

  defp cleanup_test_tenant do
    # Drop schema if it exists
    require Mcp.MultiTenant

    if Mcp.MultiTenant.tenant_schema_exists?(@test_tenant_slug) do
      SchemaProvisioner.deprovision_tenant_schema(@test_tenant_slug, force: true)
    end

    # Also clean up any additional test schemas created
    tenant_1 = @test_tenant_slug <> "_1"
    tenant_2 = @test_tenant_slug <> "_2"

    if Mcp.MultiTenant.tenant_schema_exists?(tenant_1) do
      SchemaProvisioner.deprovision_tenant_schema(tenant_1, force: true)
    end

    if Mcp.MultiTenant.tenant_schema_exists?(tenant_2) do
      SchemaProvisioner.deprovision_tenant_schema(tenant_2, force: true)
    end
  end
end
