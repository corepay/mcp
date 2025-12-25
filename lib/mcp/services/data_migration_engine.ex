defmodule Mcp.Services.DataMigrationEngine do
  @moduledoc """
  Service for executing data migrations.
  """

  alias Mcp.Platform.{DataMigration, DataMigrationLog, DataMigrationRecord}
  alias Mcp.Services.{DataImporter, DataTransformer, DataValidator}

  def execute_migration(migration_id) do
    with {:ok, migration} <- DataMigration.get(migration_id),
         {:ok, _} <-
           DataMigration.update_progress(migration, %{
             status: :processing,
             progress_percentage: 0.0
           }) do
      try do
        result = process_migration(migration)

        DataMigration.complete(migration, %{
          processed_records: result.processed_records,
          failed_records: result.failed_records,
          progress_percentage: 100.0,
          file_path: result[:file_path]
        })

        DataMigrationLog.create(%{
          migration_id: migration.id,
          message: "Migration completed successfully",
          level: :info
        })

        {:ok, result}
      rescue
        e ->
          DataMigration.fail(migration)

          DataMigrationLog.create(%{
            migration_id: migration.id,
            message: "Migration failed: #{inspect(e)}",
            level: :error
          })

          {:error, e}
      end
    end
  end

  defp process_migration(%{migration_type: :import} = migration) do
    # 1. Read Data
    {:ok, raw_data} = DataImporter.read_data(migration.source_format, migration.source_config)

    total_records = length(raw_data)
    batch_size = migration.batch_size || 100

    results =
      raw_data
      |> Enum.chunk_every(batch_size)
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {batch, index} ->
        DataMigrationLog.create(%{
          migration_id: migration.id,
          message: "Processing batch #{index} of #{ceil(total_records / batch_size)}",
          level: :info
        })

        # Update progress
        progress = index * batch_size / total_records * 100
        DataMigration.update_progress(migration, %{progress_percentage: min(progress, 99.0)})

        Enum.map(batch, fn record ->
          process_import_record(record, migration)
        end)
      end)

    processed_count = length(results)
    failed_count = Enum.count(results, fn r -> r.status != :success end)

    %{
      migration_type: :import,
      processed_records: processed_count,
      failed_records: failed_count
    }
  end

  defp process_migration(%{migration_type: :export} = migration) do
    # Placeholder for export logic
    # In a real app, this would query the DB and write to a file

    # Simulate export
    file_path = "/tmp/export_#{migration.id}.json"

    data = [
      %{
        "customer_id" => "CUST001",
        "first_name" => "John",
        "last_name" => "Doe"
      }
    ]

    File.write!(file_path, Jason.encode!(data))

    %{
      migration_type: :export,
      processed_records: 1,
      failed_records: 0,
      file_path: file_path
    }
  end

  defp process_import_record(record, migration) do
    # 1. Transform
    {:ok, transformed_record} = DataTransformer.transform_record(record, migration.field_mappings)

    # 2. Validate
    validation_result = validate_import_data(transformed_record, migration)

    error_message = format_validation_error(validation_result)
    validation_errors_map = format_validation_errors_map(validation_result)
    status = if validation_result == :ok, do: :success, else: :validation_failed

    # 3. Create Record
    create_migration_record(
      migration.id,
      record,
      transformed_record,
      status,
      error_message,
      validation_errors_map
    )

    %{status: status}
  end

  defp validate_import_data(transformed_record, migration) do
    if migration.validation_rules && migration.validation_rules != %{} do
      DataValidator.validate_record(transformed_record, migration.validation_rules)
    else
      :ok
    end
  end

  defp format_validation_error({:error, msg}) when is_binary(msg), do: msg

  defp format_validation_error({:error, errors}) when is_list(errors),
    do: "Validation failed with #{length(errors)} errors"

  defp format_validation_error(_), do: nil

  defp format_validation_errors_map({:error, errors}) when is_list(errors), do: %{errors: errors}
  defp format_validation_errors_map(_), do: %{}

  defp create_migration_record(migration_id, source, target, status, error, errors_map) do
    DataMigrationRecord.create(%{
      migration_id: migration_id,
      source_data: source,
      target_data: target,
      status: status,
      error_message: error,
      validation_errors: errors_map
    })
  end
end
