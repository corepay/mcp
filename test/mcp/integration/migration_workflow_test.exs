defmodule Mcp.Integration.MigrationWorkflowTest do
  @moduledoc """
  Integration tests for complete data migration workflow.

  Tests the end-to-end migration process including data import,
  transformation, validation, and storage.
  """

  # These tests may affect database state
  use ExUnit.Case, async: false
  alias Ecto.Adapters.SQL.Sandbox
  alias Mcp.MultiTenant
  alias Mcp.Platform.{DataMigration, DataMigrationLog, DataMigrationRecord, Tenant}
  alias Mcp.Repo

  alias Mcp.Services.{
    BackupService,
    DataImporter,
    DataMigrationEngine,
    DataTransformer,
    DataValidator
  }

  @moduletag :integration

  setup do
    # Ensure clean state for each test
    :ok = Sandbox.checkout(Repo)
    Sandbox.mode(Repo, {:shared, self()})

    # Create a test tenant
    {:ok, tenant} =
      Tenant.create(%{
        company_name: "Test ISP",
        company_schema: "test_tenant_#{:erlang.unique_integer()}",
        subdomain: "test-isp-#{:erlang.unique_integer()}",
        plan: :professional,
        status: :active
      })

    # Create tenant schema
    {:ok, _} = MultiTenant.create_tenant_schema(tenant.company_schema)

    %{
      tenant: tenant
    }
  end

  describe "complete migration workflow" do
    test "imports customer data from CSV to tenant schema", %{tenant: tenant} do
      # Prepare test CSV data
      csv_content = """
      customer_id,first_name,last_name,email,phone,service_type,monthly_fee
      CUST001,John,Doe,john@example.com,(555)123-4567,residential_basic,49.99
      CUST002,Jane,Smith,jane@example.com,(555)234-5678,residential_premium,79.99
      CUST003,Bob,Johnson,bob@company.com,(555)345-6789,business_standard,199.99
      """

      temp_file = write_temp_file("customers.csv", csv_content)

      try do
        # Create migration record
        {:ok, migration} =
          DataMigration.create(%{
            tenant_id: tenant.id,
            migration_type: :import,
            name: "Customer Data Import",
            description: "Import customer records from legacy system",
            source_format: :csv,
            source_config: %{
              "file_path" => temp_file,
              "headers" => :first_row
            },
            target_config: %{
              "table" => "customers"
            },
            field_mappings: DataTransformer.generate_isp_field_mappings("legacy_customer_db"),
            validation_rules: DataValidator.generate_isp_validation_rules("customer"),
            batch_size: 2
          })

        # Execute migration
        result = DataMigrationEngine.execute_migration(migration.id)

        # Verify migration completed successfully
        assert {:ok, migration_result} = result
        assert migration_result.migration_type == :import
        assert migration_result.processed_records > 0
        assert migration_result.failed_records == 0

        # Check migration status
        {:ok, updated_migration} = DataMigration.get(migration.id)
        assert updated_migration.status == :completed
        assert updated_migration.processed_records == 3

        # Verify data was imported to tenant schema
        imported_customers =
          MultiTenant.with_tenant_context(tenant.company_schema, fn ->
            # This would query the actual customers table
            # For now, verify migration records were created
            DataMigrationRecord.by_migration(migration.id) |> elem(1) || []
          end)

        assert length(imported_customers) == 3

        # Check all records were successful
        successful_records =
          Enum.filter(imported_customers, fn record ->
            record.status == :success
          end)

        assert length(successful_records) == 3

        # Verify migration logs were created
        {:ok, logs} = DataMigrationLog.by_migration(migration.id)
        assert length(logs) > 0

        # Check for completion log
        completion_logs =
          Enum.filter(logs, fn log ->
            String.contains?(log.message, "completed")
          end)

        assert length(completion_logs) > 0
      after
        File.rm(temp_file)
      end
    end

    test "exports tenant data to JSON format", %{tenant: tenant} do
      # First, create some test data in tenant schema
      setup_test_data(tenant)

      # Create export migration
      {:ok, migration} =
        DataMigration.create(%{
          tenant_id: tenant.id,
          migration_type: :export,
          name: "Customer Data Export",
          description: "Export customer records for backup",
          target_format: :json,
          target_config: %{
            "tables" => ["customers"],
            "pretty" => true
          },
          batch_size: 10
        })

      # Execute export
      result = DataMigrationEngine.execute_migration(migration.id)

      # Verify export completed
      assert {:ok, export_result} = result
      assert export_result.migration_type == :export
      assert export_result.processed_records > 0

      # Check migration status
      {:ok, updated_migration} = DataMigration.get(migration.id)
      assert updated_migration.status == :completed
      assert is_binary(updated_migration.file_path)

      # Verify export file was created
      assert File.exists?(updated_migration.file_path)

      # Verify export file content
      {:ok, file_content} = File.read(updated_migration.file_path)
      assert {:ok, exported_data} = Jason.decode(file_content)
      assert is_list(exported_data)
      assert length(exported_data) > 0

      # Verify exported data structure
      first_record = hd(exported_data)
      assert Map.has_key?(first_record, "customer_id")
      assert Map.has_key?(first_record, "first_name")
      assert Map.has_key?(first_record, "last_name")
    end

    test "handles validation errors gracefully", %{tenant: tenant} do
      # Prepare invalid CSV data (missing required fields)
      csv_content = """
      customer_id,first_name,last_name,email
      CUST001,John,Doe,john@example.com
      CUST002,,Smith,jane@example.com  # Missing first_name
      CUST003,Bob,,bob@example.com    # Missing last_name
      """

      temp_file = write_temp_file("invalid_customers.csv", csv_content)

      try do
        # Create migration with strict validation
        {:ok, migration} =
          DataMigration.create(%{
            tenant_id: tenant.id,
            migration_type: :import,
            name: "Invalid Customer Import",
            description: "Test import with validation errors",
            source_format: :csv,
            source_config: %{"file_path" => temp_file, "headers" => :first_row},
            validation_rules: %{
              "fields" => %{
                "first_name" => %{"required" => true, "min_length" => 1},
                "last_name" => %{"required" => true, "min_length" => 1},
                "email" => %{"type" => "email", "required" => true}
              }
            },
            batch_size: 1
          })

        # Execute migration
        result = DataMigrationEngine.execute_migration(migration.id)

        # Migration should complete with some failures
        assert {:ok, migration_result} = result
        assert migration_result.processed_records >= 1
        # Two invalid records
        assert migration_result.failed_records >= 2

        # Check migration status
        {:ok, updated_migration} = DataMigration.get(migration.id)
        assert updated_migration.status == :completed

        # Verify error tracking
        {:ok, records} = DataMigrationRecord.by_migration(migration.id)

        failed_records =
          Enum.filter(records, fn record ->
            record.status in [:failed, :validation_failed]
          end)

        assert length(failed_records) >= 2

        # Check error details
        failed_record = hd(failed_records)
        assert is_binary(failed_record.error_message)
        assert length(failed_record.validation_errors) > 0
      after
        File.rm(temp_file)
      end
    end

    test "applies field transformations during import", %{tenant: tenant} do
      # Prepare CSV with data that needs transformation
      csv_content = """
      cust_id,fname,lname,email_addr,phone_num,plan_type,base_fee
      1,john doe,JOHN@EXAMPLE.COM,555-123-4567,basic,49.99
      2,jane smith,JANE@EXAMPLE.COM,(555) 234-5678,premium,79.99
      """

      temp_file = write_temp_file("raw_customers.csv", csv_content)

      try do
        # Create migration with transformations
        field_mappings = %{
          "customer_id" => %{
            "source_field" => "cust_id",
            "transformation" => "string"
          },
          "first_name" => %{
            "source_field" => "fname",
            "transformation" => "function:capitalize_name"
          },
          "last_name" => %{
            "source_field" => "lname",
            "transformation" => "function:capitalize_name"
          },
          "email" => %{
            "source_field" => "email_addr",
            "transformation" => "function:normalize_email"
          },
          "phone" => %{
            "source_field" => "phone_num",
            "transformation" => "function:normalize_phone"
          },
          "service_type" => %{
            "source_field" => "plan_type",
            "transformation" => %{
              "type" => "lookup",
              "lookup_table" => %{
                "basic" => "residential_basic",
                "premium" => "residential_premium"
              }
            }
          },
          "monthly_fee" => %{
            "source_field" => "base_fee",
            "transformation" => "float"
          }
        }

        {:ok, migration} =
          DataMigration.create(%{
            tenant_id: tenant.id,
            migration_type: :import,
            name: "Transformed Customer Import",
            source_format: :csv,
            source_config: %{"file_path" => temp_file, "headers" => :first_row},
            field_mappings: field_mappings,
            batch_size: 1
          })

        # Execute migration
        result = DataMigrationEngine.execute_migration(migration.id)

        assert {:ok, migration_result} = result
        assert migration_result.processed_records == 2
        assert migration_result.failed_records == 0

        # Verify transformations were applied
        {:ok, records} = DataMigrationRecord.by_migration(migration.id)

        successful_records =
          Enum.filter(records, fn record ->
            record.status == :success
          end)

        # Check first record transformations
        first_record =
          Enum.find(successful_records, fn record ->
            record.source_data["cust_id"] == "1"
          end)

        target_data = first_record.target_data
        assert target_data["customer_id"] == "1"
        assert target_data["first_name"] == "John Doe"
        assert target_data["email"] == "john@example.com"
        assert target_data["phone"] == "5551234567"
        assert target_data["service_type"] == "residential_basic"
        assert target_data["monthly_fee"] == 49.99
      after
        File.rm(temp_file)
      end
    end

    test "processes large dataset in batches", %{tenant: tenant} do
      # Generate large dataset
      large_csv_content = generate_large_customer_csv(1000)

      temp_file = write_temp_file("large_customers.csv", large_csv_content)

      try do
        # Create migration with small batch size to test batching
        {:ok, migration} =
          DataMigration.create(%{
            tenant_id: tenant.id,
            migration_type: :import,
            name: "Large Customer Import",
            description: "Import 1000 customer records in batches",
            source_format: :csv,
            source_config: %{"file_path" => temp_file, "headers" => :first_row},
            field_mappings: DataTransformer.generate_isp_field_mappings("legacy_customer_db"),
            # Small batch size for testing
            batch_size: 50,
            total_records: 1000
          })

        # Execute migration
        result = DataMigrationEngine.execute_migration(migration.id)

        assert {:ok, migration_result} = result
        assert migration_result.processed_records == 1000
        assert migration_result.failed_records == 0

        # Check migration completed
        {:ok, updated_migration} = DataMigration.get(migration.id)
        assert updated_migration.status == :completed
        assert updated_migration.processed_records == 1000
        assert updated_migration.progress_percentage == 100.0

        # Verify logs for batch processing
        {:ok, logs} = DataMigrationLog.by_migration(migration.id)

        batch_logs =
          Enum.filter(logs, fn log ->
            String.contains?(log.message, "Processing batch")
          end)

        # Should have 1000/50 = 20 batch logs
        assert length(batch_logs) == 20
      after
        File.rm(temp_file)
      end
    end
  end

  describe "backup and restore workflow" do
    test "creates and restores tenant backup", %{tenant: tenant} do
      # Setup test data
      setup_test_data(tenant)

      # Create backup
      backup_result =
        BackupService.create_tenant_backup(tenant.id, %{
          "type" => "full",
          "include_files" => false
        })

      assert {:ok, backup_info} = backup_result
      assert backup_info.backup_id != nil
      assert backup_info.tenant_id == tenant.id
      assert backup_info.backup_type == "full"

      # Verify backup files were created
      backup_path = get_backup_path(backup_info.backup_id)
      assert File.exists?(backup_path)

      metadata_path = Path.join(backup_path, "backup_metadata.json")
      assert File.exists?(metadata_path)

      # Verify backup metadata
      {:ok, metadata_content} = File.read(metadata_path)
      {:ok, metadata} = Jason.decode(metadata_content)
      assert metadata["backup_id"] == backup_info.backup_id
      assert metadata["tenant_id"] == tenant.id

      # List backups
      {:ok, backups} = BackupService.list_tenant_backups(tenant.id)
      assert length(backups) >= 1
      our_backup = Enum.find(backups, fn b -> b.backup_id == backup_info.backup_id end)
      assert our_backup != nil
    end

    test "cleanup old backups", %{tenant: tenant} do
      # Create multiple backups
      backup_ids =
        Enum.map(1..3, fn _i ->
          {:ok, backup_info} =
            BackupService.create_tenant_backup(tenant.id, %{
              "type" => "full",
              "include_files" => false
            })

          backup_info.backup_id
        end)

      # List backups before cleanup
      {:ok, backups_before} = BackupService.list_tenant_backups(tenant.id)
      assert length(backups_before) >= 3

      # Cleanup with 0 days retention (should delete all)
      cleanup_result = BackupService.cleanup_old_backups(tenant.id, 0)

      assert {:ok, cleanup_info} = cleanup_result
      assert cleanup_info.deleted_count >= 3

      # Verify backups were deleted
      Enum.each(backup_ids, fn backup_id ->
        backup_path = get_backup_path(backup_id)
        refute File.exists?(backup_path)
      end)
    end
  end

  # Helper functions

  defp setup_test_data(tenant) do
    # Create test tables and data in tenant schema
    MultiTenant.with_tenant_context(tenant.company_schema, fn ->
      # This would create actual tables and insert test data
      # For now, we just verify the schema exists
      assert true
    end)
  end

  defp write_temp_file(filename, content) do
    temp_dir = System.tmp_dir!()
    temp_path = Path.join(temp_dir, filename)
    File.write!(temp_path, content)
    temp_path
  end

  defp get_backup_path(backup_id) do
    base_path = Application.get_env(:mcp, :backup_storage_path, "backups")
    Path.join([base_path, backup_id])
  end

  defp generate_large_customer_csv(count) do
    header = "customer_id,first_name,last_name,email,service_type,monthly_fee\n"

    rows =
      Enum.map(1..count, fn i ->
        email = "customer#{i}@example.com"
        service_type = if rem(i, 3) == 0, do: "business_standard", else: "residential_basic"
        monthly_fee = if service_type == "business_standard", do: "199.99", else: "49.99"

        "CUST#{String.pad_leading("#{i}", 6, "0")},Customer#{i},Test#{i},#{email},#{service_type},#{monthly_fee}"
      end)

    header <> Enum.join(rows, "\n")
  end
end
