defmodule Mcp.Platform.SchemaProvisionerTest do
  use ExUnit.Case, async: false

  alias Mcp.Repo
  alias Mcp.Platform.Tenant
  alias Mcp.Platform.SchemaProvisioner
  alias Mcp.MultiTenant

  @test_tenant_slug "test_tenant_#{System.unique_integer([:positive])}"

  setup do
    # Clean up any existing test tenant
    cleanup_test_tenant()

    on_exit(fn ->
      cleanup_test_tenant()
    end)

    :ok
  end

  describe "provision_tenant_schema/2" do
    test "successfully provisions a new tenant schema" do
      assert {:ok, :provisioned} = SchemaProvisioner.provision_tenant_schema(@test_tenant_slug)

      # Verify schema exists
      assert MultiTenant.tenant_schema_exists?(@test_tenant_slug)

      # Verify tables were created
      MultiTenant.with_tenant_context(@test_tenant_slug, fn ->
        # Check that expected tables exist
        tables_result =
          Repo.query(
            "SELECT table_name FROM information_schema.tables WHERE table_schema = current_schema()"
          )

        assert {:ok, %{rows: tables}} = tables_result

        table_names = List.flatten(tables)
        assert "merchants" in table_names
        assert "resellers" in table_names
        assert "developers" in table_names
        assert "mids" in table_names
        assert "stores" in table_names
        assert "customers" in table_names
      end)
    end

    test "fails to provision existing schema" do
      # Create schema first
      assert {:ok, :provisioned} = SchemaProvisioner.provision_tenant_schema(@test_tenant_slug)

      # Try to create again
      assert {:error, :schema_already_exists} =
               SchemaProvisioner.provision_tenant_schema(@test_tenant_slug)
    end

    test "handles invalid tenant slug" do
      invalid_slug = ""

      assert {:error, reason} = SchemaProvisioner.provision_tenant_schema(invalid_slug)
      # Should fail with some kind of validation error
    end
  end

  describe "initialize_tenant_schema/2" do
    test "initializes an existing schema" do
      # Create schema manually
      schema_name = "acq_" <> @test_tenant_slug
      {:ok, _} = Repo.query("CREATE SCHEMA #{schema_name}")

      assert {:ok, :initialized} = SchemaProvisioner.initialize_tenant_schema(@test_tenant_slug)

      # Verify tables were created
      MultiTenant.with_tenant_context(@test_tenant_slug, fn ->
        tables_result =
          Repo.query(
            "SELECT table_name FROM information_schema.tables WHERE table_schema = current_schema()"
          )

        assert {:ok, %{rows: tables}} = tables_result

        table_names = List.flatten(tables)
        assert "merchants" in table_names
      end)
    end
  end

  describe "backup and restore operations" do
    test "creates and restores backup" do
      # Provision schema first
      assert {:ok, :provisioned} = SchemaProvisioner.provision_tenant_schema(@test_tenant_slug)

      # Add some test data
      MultiTenant.with_tenant_context(@test_tenant_slug, fn ->
        Repo.query("""
        INSERT INTO merchants (id, slug, business_name, subdomain, status, plan)
        VALUES (gen_random_uuid(), 'test-merchant', 'Test Business', 'test', 'active', 'starter')
        """)
      end)

      # Create backup
      assert {:ok, backup_file} = SchemaProvisioner.backup_tenant_schema(@test_tenant_slug)
      assert File.exists?(backup_file)

      # Drop schema
      assert {:ok, _} =
               SchemaProvisioner.deprovision_tenant_schema(@test_tenant_slug,
                 backup_path: Path.dirname(backup_file)
               )

      refute MultiTenant.tenant_schema_exists?(@test_tenant_slug)

      # Restore from backup
      assert {:ok, :restored} =
               SchemaProvisioner.restore_tenant_schema(@test_tenant_slug, backup_file)

      assert MultiTenant.tenant_schema_exists?(@test_tenant_slug)

      # Verify data was restored
      MultiTenant.with_tenant_context(@test_tenant_slug, fn ->
        result = Repo.query("SELECT COUNT(*) FROM merchants")
        assert {:ok, %{rows: [[count]]}} = result
        assert count == 1
      end)
    end
  end

  describe "integration with tenant resource" do
    test "tenant creation triggers schema provisioning" do
      tenant_attrs = %{
        slug: @test_tenant_slug,
        company_name: "Test Company",
        subdomain: @test_tenant_slug,
        company_schema: @test_tenant_slug,
        plan: :trial
      }

      # Create tenant - this should trigger schema provisioning
      assert {:ok, tenant} = Tenant.create(tenant_attrs, action: :create_with_defaults)

      # Give some time for async provisioning to complete
      Process.sleep(2000)

      # Verify schema was created
      assert MultiTenant.tenant_schema_exists?(@test_tenant_slug)

      # Clean up
      Tenant.destroy!(tenant)
    end
  end

  defp cleanup_test_tenant do
    # Remove tenant if it exists
    case Tenant.by_slug(%{slug: @test_tenant_slug}) do
      {:ok, [tenant]} ->
        Tenant.destroy!(tenant)

      {:ok, []} ->
        :ok

      {:error, _} ->
        :ok
    end

    # Drop schema if it exists
    if MultiTenant.tenant_schema_exists?(@test_tenant_slug) do
      SchemaProvisioner.deprovision_tenant_schema(@test_tenant_slug, force: true)
    end
  end
end
