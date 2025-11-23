defmodule Mcp.Repo.Migrations.CreateDataMigrationTables do
  @moduledoc """
  Create tables for data migration functionality.

  This migration creates tables for tracking migration jobs, logs,
  and individual record processing for the ISP platform's data
  migration capabilities.
  """

  use Ecto.Migration

  def change do
    create table(:data_migrations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :migration_type, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :name, :string, null: false
      add :description, :text
      add :source_format, :string
      add :target_format, :string
      add :source_config, :jsonb, default: "{}"
      add :target_config, :jsonb, default: "{}"
      add :field_mappings, :jsonb, default: "{}"
      add :validation_rules, :jsonb, default: "{}"
      add :total_records, :integer, default: 0, null: false
      add :processed_records, :integer, default: 0, null: false
      add :failed_records, :integer, default: 0, null: false
      add :progress_percentage, :float, default: 0.0, null: false
      add :error_message, :text
      add :error_details, :jsonb, default: "{}"
      add :result_summary, :jsonb, default: "{}"
      add :file_path, :string
      add :backup_path, :string
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :estimated_duration_minutes, :integer
      add :priority, :string, default: "normal", null: false
      add :batch_size, :integer, default: 1000, null: false
      add :retry_count, :integer, default: 0, null: false
      add :max_retries, :integer, default: 3, null: false
      add :created_by, :binary_id
      add :tags, {:array, :string}, default: []

      timestamps()
    end

    create index(:data_migrations, [:tenant_id])
    create index(:data_migrations, [:status])
    create index(:data_migrations, [:migration_type])
    create index(:data_migrations, [:priority])
    create index(:data_migrations, [:inserted_at])
    create index(:data_migrations, [:tenant_id, :status])
    create index(:data_migrations, [:status, :priority])

    create table(:data_migration_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :migration_id, :binary_id, null: false
      add :log_level, :string, null: false, default: "info"
      add :message, :text, null: false
      add :details, :jsonb, default: "{}"
      add :batch_number, :integer
      add :record_count, :integer
      add :duration_ms, :integer
      add :step_name, :string
      add :source_table, :string
      add :target_table, :string
      add :error_type, :string
      add :stack_trace, :text
      add :context_data, :jsonb, default: "{}"

      timestamps()
    end

    create index(:data_migration_logs, [:migration_id])
    create index(:data_migration_logs, [:log_level])
    create index(:data_migration_logs, [:inserted_at])
    create index(:data_migration_logs, [:migration_id, :inserted_at])
    create index(:data_migration_logs, [:migration_id, :log_level])

    create table(:data_migration_records, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :migration_id, :binary_id, null: false
      add :batch_number, :integer
      add :record_index, :integer
      add :source_table, :string
      add :target_table, :string
      add :status, :string, null: false, default: "pending"
      add :source_data, :jsonb, default: "{}"
      add :target_data, :jsonb, default: "{}"
      add :field_transformations, :jsonb, default: "{}"
      add :validation_errors, {:array, :jsonb}, default: []
      add :error_message, :text
      add :error_type, :string
      add :processing_time_ms, :integer
      add :warnings, {:array, :string}, default: []
      add :checksum, :string
      add :source_record_id, :string
      add :target_record_id, :string

      timestamps()
    end

    create index(:data_migration_records, [:migration_id])
    create index(:data_migration_records, [:status])
    create index(:data_migration_records, [:batch_number])
    create index(:data_migration_records, [:target_table])
    create index(:data_migration_records, [:inserted_at])
    create index(:data_migration_records, [:migration_id, :status])
    create index(:data_migration_records, [:migration_id, :batch_number])
    create index(:data_migration_records, [:source_record_id])
    create index(:data_migration_records, [:target_record_id])

    # Foreign key constraints
    execute """
    ALTER TABLE data_migrations
    ADD CONSTRAINT data_migrations_tenant_id_fkey
    FOREIGN KEY (tenant_id) REFERENCES tenants (id);
    """

    execute """
    ALTER TABLE data_migration_logs
    ADD CONSTRAINT data_migration_logs_migration_id_fkey
    FOREIGN KEY (migration_id) REFERENCES data_migrations (id)
    ON DELETE CASCADE;
    """

    execute """
    ALTER TABLE data_migration_records
    ADD CONSTRAINT data_migration_records_migration_id_fkey
    FOREIGN KEY (migration_id) REFERENCES data_migrations (id)
    ON DELETE CASCADE;
    """

    # Create composite indexes for common query patterns
    create index(:data_migrations, [:tenant_id, :migration_type, :status])
    create index(:data_migrations, [:status, :inserted_at, :priority])

    create index(:data_migration_logs, [:migration_id, :log_level, :inserted_at])
    create index(:data_migration_logs, [:log_level, :inserted_at])

    create index(:data_migration_records, [:migration_id, :status, :batch_number])
    create index(:data_migration_records, [:status, :inserted_at])
    create index(:data_migration_records, [:migration_id, :target_table, :status])
  end
end
