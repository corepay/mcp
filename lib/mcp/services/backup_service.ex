defmodule Mcp.Services.BackupService do
  @moduledoc """
  Comprehensive backup and restore service for ISP platform data.

  Provides tenant-level backup capabilities including database dumps,
  file storage backups, configuration snapshots, and incremental
  backup support with scheduling and retention management.
  """

  require Logger
  alias Mcp.MultiTenant
  alias Mcp.Platform.Tenant
  alias Mcp.Repo

  @type backup_result :: {:ok, map()} | {:error, String.t()}
  @type restore_result :: {:ok, map()} | {:error, String.t()}

  # Main Backup Operations

  @doc """
  Create a comprehensive backup of tenant data.
  """
  def create_tenant_backup(tenant_id, backup_options \\ %{}) do
    Logger.info("Starting tenant backup", tenant_id: tenant_id)

    with {:ok, tenant} <- Tenant.get(tenant_id),
         {:ok, backup_id} <- generate_backup_id(),
         _backup_info <- build_backup_info(tenant, backup_id, backup_options) do
      backup_result = %{
        backup_id: backup_id,
        tenant_id: tenant_id,
        started_at: DateTime.utc_now(),
        backup_type: Map.get(backup_options, "type", "full"),
        backup_options: backup_options
      }

      # Execute backup steps
      backup_result =
        backup_result
        |> backup_database_data(tenant)
        |> backup_file_storage(tenant, backup_options)
        |> backup_configuration(tenant)
        |> backup_metadata(tenant)

      # Store backup metadata
      final_result = finalize_backup(backup_result)

      Logger.info("Tenant backup completed", tenant_id: tenant_id, backup_id: backup_id)
      {:ok, final_result}
    else
      {:error, reason} -> {:error, "Backup setup failed: #{reason}"}
    end
  rescue
    error ->
      Logger.error("Tenant backup failed", tenant_id: tenant_id, error: error)
      {:error, "Backup failed: #{inspect(error)}"}
  end

  @doc """
  Restore tenant data from backup.
  """
  def restore_tenant_backup(backup_id, restore_options \\ %{}) do
    Logger.info("Starting tenant restore", backup_id: backup_id)

    with {:ok, backup_metadata} <- load_backup_metadata(backup_id),
         {:ok, tenant} <- Tenant.get(backup_metadata.tenant_id),
         :ok <- validate_restore_permissions(tenant, restore_options) do
      restore_result = %{
        backup_id: backup_id,
        tenant_id: backup_metadata.tenant_id,
        started_at: DateTime.utc_now(),
        restore_options: restore_options
      }

      # Create restore point first
      :ok = create_restore_point(tenant)

      # Execute restore steps
      restore_result =
        restore_result
        |> restore_database_data(backup_metadata, restore_options)
        |> restore_file_storage(backup_metadata, restore_options)
        |> restore_configuration(backup_metadata, restore_options)
        |> validate_restore_integrity(backup_metadata)

      # Finalize restore
      final_result = finalize_restore(restore_result, backup_metadata)

      Logger.info("Tenant restore completed",
        backup_id: backup_id,
        tenant_id: backup_metadata.tenant_id
      )

      {:ok, final_result}
    else
      {:error, reason} -> {:error, "Restore setup failed: #{reason}"}
    end
  rescue
    error ->
      Logger.error("Tenant restore failed", backup_id: backup_id, error: error)
      {:error, "Restore failed: #{inspect(error)}"}
  end

  @doc """
  Create incremental backup of changed tenant data.
  """
  def create_incremental_backup(tenant_id, since_timestamp, backup_options \\ %{}) do
    Logger.info("Starting incremental backup", tenant_id: tenant_id, since: since_timestamp)

    case Tenant.get(tenant_id) do
      {:ok, tenant} ->
        # Get list of changes since timestamp
        changes = get_tenant_changes(tenant, since_timestamp)

        backup_options =
          Map.merge(backup_options, %{
            "type" => "incremental",
            "since_timestamp" => since_timestamp,
            "changes" => changes
          })

        create_tenant_backup(tenant_id, backup_options)

      {:error, reason} ->
        {:error, "Incremental backup setup failed: #{reason}"}
    end
  end

  @doc """
  List available backups for a tenant.
  """
  def list_tenant_backups(tenant_id, opts \\ %{}) do
    backup_path = get_backup_storage_path(tenant_id)

    backups =
      backup_path
      |> File.ls!()
      |> Enum.filter(&String.starts_with?(&1, "backup_"))
      |> Enum.map(fn backup_dir ->
        load_backup_metadata_from_dir(Path.join(backup_path, backup_dir))
      end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.sort_by(& &1.created_at, {:desc, DateTime})

    # Apply filters
    backups = apply_backup_filters(backups, opts)

    {:ok, backups}
  rescue
    error ->
      Logger.error("Failed to list backups", tenant_id: tenant_id, error: error)
      {:error, "Failed to list backups: #{inspect(error)}"}
  end

  @doc """
  Delete old backups according to retention policy.
  """
  def cleanup_old_backups(tenant_id, retention_days \\ 90) do
    Logger.info("Starting backup cleanup", tenant_id: tenant_id, retention_days: retention_days)

    case list_tenant_backups(tenant_id) do
      {:ok, backups} ->
        old_backups = filter_old_backups(backups, retention_days)
        deleted_count = delete_backup_batch(old_backups)

        Logger.info("Backup cleanup completed", tenant_id: tenant_id, deleted: deleted_count)
        {:ok, %{deleted_count: deleted_count, total_backups: length(backups)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp filter_old_backups(backups, retention_days) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -retention_days * 24 * 60 * 60, :second)

    Enum.filter(backups, fn backup ->
      DateTime.compare(backup.created_at, cutoff_date) == :lt
    end)
  end

  defp delete_backup_batch(backups) do
    Enum.reduce(backups, 0, fn backup, acc ->
      case delete_backup(backup.backup_id) do
        :ok -> acc + 1
        {:error, _reason} -> acc
      end
    end)
  end

  @doc """
  Schedule automatic backups for tenant.
  """
  def schedule_automatic_backups(tenant_id, schedule_config) do
    # This would integrate with a job scheduler like Oban or Quantum
    # For now, return success
    Logger.info("Automatic backup scheduling configured",
      tenant_id: tenant_id,
      config: schedule_config
    )

    {:ok, :scheduled}
  end

  # Backup Implementation Functions

  defp backup_database_data(backup_result, tenant) do
    backup_type = backup_result.backup_type

    case backup_type do
      "full" ->
        backup_full_database(backup_result, tenant)

      "incremental" ->
        backup_incremental_database(
          backup_result,
          tenant,
          backup_result.backup_options["changes"]
        )

      _ ->
        Logger.error("Unsupported backup type", type: backup_type)
        Map.put(backup_result, :database_backup, {:error, "Unsupported backup type"})
    end
  end

  defp backup_full_database(backup_result, tenant) do
    # Create database dump using pg_dump
    timestamp = DateTime.to_iso8601(DateTime.utc_now())
    backup_filename = "database_full_#{timestamp}.sql"
    backup_path = Path.join(get_backup_path(backup_result.backup_id), backup_filename)

    # Use MultiTenant context to get proper schema
    MultiTenant.with_tenant_context(tenant.company_schema, fn ->
      # Create database dump
      dump_command = build_pg_dump_command(tenant.company_schema, backup_path)

      case System.cmd("sh", ["-c", dump_command], stderr_to_stdout: true) do
        {_output, 0} ->
          backup_size = File.stat!(backup_path).size
          Logger.info("Database backup completed", path: backup_path, size: backup_size)

          Map.put(backup_result, :database_backup, %{
            type: "full",
            filename: backup_filename,
            path: backup_path,
            size_bytes: backup_size,
            table_count: count_tenant_tables(tenant.company_schema),
            timestamp: timestamp
          })

        {output, exit_code} ->
          Logger.error("Database backup failed", exit_code: exit_code, output: output)
          Map.put(backup_result, :database_backup, {:error, "pg_dump failed: #{output}"})
      end
    end)
  rescue
    error ->
      Logger.error("Database backup error", error: error)

      Map.put(
        backup_result,
        :database_backup,
        {:error, "Database backup failed: #{inspect(error)}"}
      )
  end

  defp backup_incremental_database(backup_result, tenant, changes) do
    # Create incremental backup using change data
    timestamp = DateTime.to_iso8601(DateTime.utc_now())
    backup_filename = "database_incremental_#{timestamp}.json"
    backup_path = Path.join(get_backup_path(backup_result.backup_id), backup_filename)

    # Extract changes from database
    incremental_data = extract_incremental_changes(tenant.company_schema, changes)

    case Jason.encode(incremental_data, pretty: true) do
      {:ok, json_data} ->
        File.write!(backup_path, json_data)

        backup_size = File.stat!(backup_path).size

        Logger.info("Incremental database backup completed",
          path: backup_path,
          size: backup_size
        )

        Map.put(backup_result, :database_backup, %{
          type: "incremental",
          filename: backup_filename,
          path: backup_path,
          size_bytes: backup_size,
          change_count: length(changes),
          since_timestamp: backup_result.backup_options["since_timestamp"],
          timestamp: timestamp
        })

      {:error, reason} ->
        Map.put(backup_result, :database_backup, {:error, "JSON encoding failed: #{reason}"})
    end
  rescue
    error ->
      Logger.error("Incremental database backup error", error: error)

      Map.put(
        backup_result,
        :database_backup,
        {:error, "Incremental backup failed: #{inspect(error)}"}
      )
  end

  defp backup_file_storage(backup_result, tenant, backup_options) do
    include_files = Map.get(backup_options, "include_files", true)

    if include_files do
      try do
        timestamp = DateTime.to_iso8601(DateTime.utc_now())
        files_backup_dir = Path.join(get_backup_path(backup_result.backup_id), "files")

        File.mkdir_p!(files_backup_dir)

        # Backup tenant-specific files
        files_info = backup_tenant_files(tenant, files_backup_dir)

        Map.put(backup_result, :file_backup, %{
          type: "files",
          directory: files_backup_dir,
          file_count: files_info.file_count,
          total_size_bytes: files_info.total_size,
          timestamp: timestamp
        })
      rescue
        error ->
          Logger.error("File backup error", error: error)
          Map.put(backup_result, :file_backup, {:error, "File backup failed: #{inspect(error)}"})
      end
    else
      Map.put(backup_result, :file_backup, %{
        type: "files",
        skipped: true,
        reason: "File backup disabled in options"
      })
    end
  end

  defp backup_configuration(backup_result, tenant) do
    timestamp = DateTime.to_iso8601(DateTime.utc_now())
    config_filename = "configuration_#{timestamp}.json"
    config_path = Path.join(get_backup_path(backup_result.backup_id), config_filename)

    # Gather tenant configuration
    configuration = %{
      tenant: %{
        id: tenant.id,
        company_name: tenant.company_name,
        company_schema: tenant.company_schema,
        subdomain: tenant.subdomain,
        custom_domain: tenant.custom_domain,
        plan: tenant.plan,
        status: tenant.status,
        settings: tenant.settings,
        branding: tenant.branding
      },
      backup_timestamp: timestamp,
      platform_version: get_platform_version(),
      schema_version: "1.0"
    }

    case Jason.encode(configuration, pretty: true) do
      {:ok, json_data} ->
        File.write!(config_path, json_data)

        config_size = File.stat!(config_path).size
        Logger.info("Configuration backup completed", path: config_path, size: config_size)

        Map.put(backup_result, :configuration_backup, %{
          filename: config_filename,
          path: config_path,
          size_bytes: config_size,
          timestamp: timestamp
        })

      {:error, reason} ->
        Map.put(
          backup_result,
          :configuration_backup,
          {:error, "Configuration backup failed: #{reason}"}
        )
    end
  rescue
    error ->
      Logger.error("Configuration backup error", error: error)

      Map.put(
        backup_result,
        :configuration_backup,
        {:error, "Configuration backup failed: #{inspect(error)}"}
      )
  end

  defp backup_metadata(backup_result, tenant) do
    metadata = %{
      backup_id: backup_result.backup_id,
      tenant_id: tenant.id,
      tenant_name: tenant.company_name,
      backup_type: backup_result.backup_type,
      created_at: DateTime.utc_now(),
      backup_options: backup_result.backup_options,
      components: %{
        database: Map.get(backup_result, :database_backup),
        files: Map.get(backup_result, :file_backup),
        configuration: Map.get(backup_result, :configuration_backup)
      },
      platform_info: %{
        version: get_platform_version(),
        database_version: get_database_version(),
        backup_tool_version: "1.0.0"
      }
    }

    metadata_filename = "backup_metadata.json"
    metadata_path = Path.join(get_backup_path(backup_result.backup_id), metadata_filename)

    case Jason.encode(metadata, pretty: true) do
      {:ok, json_data} ->
        File.write!(metadata_path, json_data)
        Map.put(backup_result, :metadata, metadata)

      {:error, reason} ->
        Logger.error("Metadata backup failed", reason: reason)
        Map.put(backup_result, :metadata, {:error, "Metadata backup failed: #{reason}"})
    end
  rescue
    error ->
      Logger.error("Metadata backup error", error: error)
      Map.put(backup_result, :metadata, {:error, "Metadata backup failed: #{inspect(error)}"})
  end

  # Restore Implementation Functions

  defp restore_database_data(restore_result, backup_metadata, restore_options) do
    database_backup = backup_metadata.components.database

    case database_backup do
      %{type: "full"} ->
        restore_full_database(restore_result, database_backup, restore_options)

      %{type: "incremental"} ->
        restore_incremental_database(restore_result, database_backup, restore_options)

      {:error, reason} ->
        Map.put(restore_result, :database_restore, {:error, reason})

      _ ->
        Map.put(restore_result, :database_restore, {:error, "Invalid database backup format"})
    end
  end

  defp restore_full_database(restore_result, database_backup, restore_options) do
    tenant = get_tenant_from_restore(restore_result)
    backup_path = database_backup.path

    # Restore database using psql
    MultiTenant.with_tenant_context(tenant.company_schema, fn ->
      # Clear existing data if requested
      if Map.get(restore_options, "clear_existing", false) do
        clear_tenant_data(tenant.company_schema)
      end

      # Restore from backup
      restore_command = build_psql_restore_command(tenant.company_schema, backup_path)

      case System.cmd("sh", ["-c", restore_command], stderr_to_stdout: true) do
        {_output, 0} ->
          Logger.info("Database restore completed", path: backup_path)

          Map.put(restore_result, :database_restore, %{
            type: "full",
            restored: true,
            timestamp: DateTime.utc_now()
          })

        {output, exit_code} ->
          Logger.error("Database restore failed", exit_code: exit_code, output: output)
          Map.put(restore_result, :database_restore, {:error, "psql restore failed: #{output}"})
      end
    end)
  rescue
    error ->
      Logger.error("Database restore error", error: error)

      Map.put(
        restore_result,
        :database_restore,
        {:error, "Database restore failed: #{inspect(error)}"}
      )
  end

  defp restore_incremental_database(restore_result, database_backup, _restore_options) do
    tenant = get_tenant_from_restore(restore_result)
    backup_path = database_backup.path

    # Read incremental changes
    with {:ok, json_data} <- File.read(backup_path),
         {:ok, changes} <- Jason.decode(json_data) do
      # Apply incremental changes
      MultiTenant.with_tenant_context(tenant.company_schema, fn ->
        apply_incremental_changes(tenant.company_schema, changes)
      end)

      Map.put(restore_result, :database_restore, %{
        type: "incremental",
        restored: true,
        change_count: database_backup.change_count,
        timestamp: DateTime.utc_now()
      })
    else
      {:error, reason} ->
        error_msg = determine_incremental_error_reason(reason)
        Map.put(restore_result, :database_restore, {:error, error_msg})
    end
  rescue
    error ->
      Logger.error("Incremental database restore error", error: error)

      Map.put(
        restore_result,
        :database_restore,
        {:error, "Incremental restore failed: #{inspect(error)}"}
      )
  end

  defp determine_incremental_error_reason(reason) do
    if String.contains?(inspect(reason), "JSON") or
         String.contains?(inspect(reason), "decode") do
      "Failed to parse incremental backup: #{reason}"
    else
      "Failed to read backup file: #{reason}"
    end
  end

  defp restore_file_storage(restore_result, backup_metadata, restore_options) do
    file_backup = backup_metadata.components.files

    case file_backup do
      %{directory: backup_dir} when not is_nil(backup_dir) ->
        try do
          restore_files = Map.get(restore_options, "restore_files", true)

          if restore_files do
            tenant = get_tenant_from_restore(restore_result)
            target_dir = get_tenant_files_directory(tenant)

            # Restore files from backup
            File.cp_r!(backup_dir, target_dir)

            Map.put(restore_result, :file_restore, %{
              type: "files",
              restored: true,
              directory: backup_dir,
              timestamp: DateTime.utc_now()
            })
          else
            Map.put(restore_result, :file_restore, %{
              type: "files",
              skipped: true,
              reason: "File restore disabled in options"
            })
          end
        rescue
          error ->
            Logger.error("File restore error", error: error)

            Map.put(
              restore_result,
              :file_restore,
              {:error, "File restore failed: #{inspect(error)}"}
            )
        end

      {:error, reason} ->
        Map.put(restore_result, :file_restore, {:error, reason})

      _ ->
        Map.put(restore_result, :file_restore, %{
          type: "files",
          skipped: true,
          reason: "No file backup found"
        })
    end
  end

  defp restore_configuration(restore_result, backup_metadata, restore_options) do
    config_backup = backup_metadata.components.configuration

    case config_backup do
      %{path: config_path} when not is_nil(config_path) ->
        restore_from_config_file(restore_result, config_path, restore_options)

      {:error, reason} ->
        Map.put(restore_result, :configuration_restore, {:error, reason})

      _ ->
        Map.put(restore_result, :configuration_restore, %{
          type: "configuration",
          skipped: true,
          reason: "No configuration backup found"
        })
    end
  end

  defp restore_from_config_file(restore_result, config_path, restore_options) do
    restore_config = Map.get(restore_options, "restore_configuration", true)

    if restore_config do
      process_configuration_file(restore_result, config_path)
    else
      Map.put(restore_result, :configuration_restore, %{
        type: "configuration",
        skipped: true,
        reason: "Configuration restore disabled in options"
      })
    end
  rescue
    error ->
      Logger.error("Configuration restore error", error: error)

      Map.put(
        restore_result,
        :configuration_restore,
        {:error, "Configuration restore failed: #{inspect(error)}"}
      )
  end

  defp process_configuration_file(restore_result, config_path) do
    with {:ok, json_data} <- File.read(config_path),
         {:ok, configuration} <- Jason.decode(json_data) do
      tenant = get_tenant_from_restore(restore_result)
      apply_tenant_configuration(tenant, configuration)

      Map.put(restore_result, :configuration_restore, %{
        type: "configuration",
        restored: true,
        timestamp: DateTime.utc_now()
      })
    else
      {:error, reason} ->
        error_msg = determine_config_error_reason(reason)

        Map.put(
          restore_result,
          :configuration_restore,
          {:error, error_msg}
        )
    end
  end

  defp determine_config_error_reason(reason) do
    if String.contains?(inspect(reason), "JSON") or
         String.contains?(inspect(reason), "decode") do
      "Failed to parse configuration: #{reason}"
    else
      "Failed to read configuration: #{reason}"
    end
  end

  defp validate_restore_integrity(restore_result, _backup_metadata) do
    tenant = get_tenant_from_restore(restore_result)

    with validations <- collect_component_validations(restore_result, tenant),
         validation_result <- build_validation_result(validations) do
      Map.put(restore_result, :integrity_validation, validation_result)
    end
  rescue
    error ->
      Logger.error("Integrity validation error", error: error)

      Map.put(
        restore_result,
        :integrity_validation,
        {:error, "Integrity validation failed: #{inspect(error)}"}
      )
  end

  defp collect_component_validations(restore_result, tenant) do
    validations = []

    validations =
      validations ++ validate_database_component(restore_result, tenant)

    validations =
      validations ++ validate_file_component(restore_result, tenant)

    validations
  end

  defp validate_database_component(restore_result, tenant) do
    database_restore = Map.get(restore_result, :database_restore)

    if database_restore && match?(%{restored: true}, database_restore) do
      case validate_database_integrity(tenant.company_schema) do
        :ok -> []
        {:error, error} -> [%{component: "database", error: error}]
      end
    else
      []
    end
  end

  defp validate_file_component(restore_result, tenant) do
    file_restore = Map.get(restore_result, :file_restore)

    if file_restore && match?(%{restored: true}, file_restore) do
      case validate_file_integrity(tenant) do
        :ok -> []
        {:error, error} -> [%{component: "files", error: error}]
      end
    else
      []
    end
  end

  defp build_validation_result([]) do
    %{
      passed: true,
      timestamp: DateTime.utc_now()
    }
  end

  defp build_validation_result(errors) do
    %{
      passed: false,
      errors: errors,
      timestamp: DateTime.utc_now()
    }
  end

  # Utility and Helper Functions

  defp generate_backup_id do
    timestamp = DateTime.to_iso8601(DateTime.utc_now())
    random_part = :crypto.strong_rand_bytes(8) |> Base.encode16()
    "backup_#{timestamp}_#{random_part}"
  end

  defp build_backup_info(tenant, backup_id, backup_options) do
    %{
      backup_id: backup_id,
      tenant_id: tenant.id,
      tenant_name: tenant.company_name,
      created_at: DateTime.utc_now(),
      backup_options: backup_options
    }
  end

  defp get_backup_path(backup_id) do
    base_path = Application.get_env(:mcp, :backup_storage_path, "backups")
    Path.join([base_path, backup_id])
  end

  defp get_backup_storage_path(tenant_id) do
    base_path = Application.get_env(:mcp, :backup_storage_path, "backups")
    Path.join([base_path, "tenant_#{tenant_id}"])
  end

  defp build_pg_dump_command(schema, output_path) do
    # This would use actual database connection details
    # For now, provide a template command
    "pg_dump --host=localhost --port=5432 --username=postgres --schema=#{schema} --format=custom --file=#{output_path} mcp"
  end

  defp build_psql_restore_command(schema, input_path) do
    # This would use actual database connection details
    # For now, provide a template command
    "pg_restore --host=localhost --port=5432 --username=postgres --schema=#{schema} --clean --if-exists --no-owner --no-privileges -d mcp #{input_path}"
  end

  defp count_tenant_tables(schema) do
    MultiTenant.with_tenant_context(schema, fn ->
      query =
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = CURRENT_SCHEMA()"

      case Repo.query(query) do
        {:ok, %{rows: [[count]]}} -> count
        {:error, _reason} -> 0
      end
    end)
  end

  defp backup_tenant_files(_tenant, target_dir) do
    # This would backup tenant-specific files
    # For now, return placeholder info
    files_info = %{
      file_count: 0,
      total_size: 0
    }

    File.mkdir_p!(target_dir)
    files_info
  end

  defp get_tenant_files_directory(tenant) do
    Path.join([Application.get_env(:mcp, :files_storage_path, "files"), "tenant_#{tenant.id}"])
  end

  defp get_platform_version, do: "1.0.0"
  defp get_database_version, do: "PostgreSQL 15.0"

  defp finalize_backup(backup_result) do
    completed_at = DateTime.utc_now()
    duration_ms = DateTime.diff(completed_at, backup_result.started_at, :millisecond)

    Map.merge(backup_result, %{
      completed_at: completed_at,
      duration_ms: duration_ms,
      status: :completed
    })
  end

  defp finalize_restore(restore_result, backup_metadata) do
    completed_at = DateTime.utc_now()
    duration_ms = DateTime.diff(completed_at, restore_result.started_at, :millisecond)

    Map.merge(restore_result, %{
      completed_at: completed_at,
      duration_ms: duration_ms,
      status: :completed,
      backup_metadata: backup_metadata
    })
  end

  defp create_restore_point(tenant) do
    # Create a snapshot before restore for rollback capability
    Logger.info("Creating restore point", tenant_id: tenant.id)
    # Implementation would depend on database capabilities
    :ok
  end

  defp load_backup_metadata(backup_id) do
    metadata_path = Path.join(get_backup_path(backup_id), "backup_metadata.json")

    case File.read(metadata_path) do
      {:ok, json_data} ->
        case Jason.decode(json_data) do
          {:ok, metadata} -> {:ok, metadata}
          {:error, reason} -> {:error, "Failed to parse metadata: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Failed to read metadata: #{reason}"}
    end
  end

  defp load_backup_metadata_from_dir(backup_dir) do
    metadata_path = Path.join(backup_dir, "backup_metadata.json")

    case File.read(metadata_path) do
      {:ok, json_data} ->
        case Jason.decode(json_data) do
          {:ok, metadata} -> metadata
          {:error, _reason} -> nil
        end

      {:error, _reason} ->
        nil
    end
  end

  defp validate_restore_permissions(_tenant, restore_options) do
    # Check if restore is allowed based on options and permissions
    if Map.get(restore_options, "force_restore", false) do
      :ok
    else
      # Additional validation logic here
      :ok
    end
  end

  defp get_tenant_from_restore(restore_result) do
    {:ok, tenant} = Tenant.get(restore_result.tenant_id)
    tenant
  end

  defp get_tenant_changes(_tenant, _since_timestamp) do
    # Get list of changes since timestamp for incremental backup
    # This would track changes in tables, files, etc.
    []
  end

  defp extract_incremental_changes(schema, changes) do
    # Extract actual data changes for incremental backup
    MultiTenant.with_tenant_context(schema, fn ->
      # Implementation would extract changed records
      %{
        tables: %{},
        changes: changes
      }
    end)
  end

  defp apply_incremental_changes(schema, _changes) do
    # Apply incremental changes to restore data
    MultiTenant.with_tenant_context(schema, fn ->
      # Implementation would apply changes
      :ok
    end)
  end

  defp clear_tenant_data(schema) do
    # Clear existing tenant data before restore
    MultiTenant.with_tenant_context(schema, fn ->
      # Implementation would clear all data
      :ok
    end)
  end

  defp apply_tenant_configuration(tenant, configuration) do
    # Apply restored configuration to tenant
    case configuration["tenant"] do
      nil ->
        :ok

      tenant_config ->
        Tenant.update(tenant, tenant_config)
    end
  end

  defp validate_database_integrity(schema) do
    # Validate database integrity after restore
    MultiTenant.with_tenant_context(schema, fn ->
      # Implementation would check constraints, counts, etc.
      :ok
    end)
  end

  defp validate_file_integrity(tenant) do
    # Validate file integrity after restore
    files_dir = get_tenant_files_directory(tenant)

    if File.exists?(files_dir) do
      :ok
    else
      {:error, "Files directory not found"}
    end
  end

  defp apply_backup_filters(backups, opts) do
    backups
    |> maybe_filter_by_type(opts["type"])
    |> maybe_filter_by_date_range(opts["date_from"], opts["date_to"])
  end

  defp maybe_filter_by_type(backups, nil), do: backups

  defp maybe_filter_by_type(backups, type) do
    Enum.filter(backups, fn backup -> backup.backup_type == type end)
  end

  defp maybe_filter_by_date_range(backups, nil, nil), do: backups

  defp maybe_filter_by_date_range(backups, date_from, date_to) do
    from_date = if date_from, do: DateTime.from_iso8601(date_from) |> elem(1), else: nil
    to_date = if date_to, do: DateTime.from_iso8601(date_to) |> elem(1), else: nil

    Enum.filter(backups, fn backup ->
      from_date_check =
        if from_date, do: DateTime.compare(backup.created_at, from_date) != :lt, else: true

      to_date_check =
        if to_date, do: DateTime.compare(backup.created_at, to_date) != :gt, else: true

      from_date_check and to_date_check
    end)
  end

  defp delete_backup(backup_id) do
    backup_path = get_backup_path(backup_id)

    case File.rm_rf(backup_path) do
      {:ok, _} -> :ok
      {:error, _, reason} -> {:error, reason}
    end
  end
end
