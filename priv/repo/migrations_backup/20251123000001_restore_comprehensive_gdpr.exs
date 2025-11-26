defmodule Mcp.Repo.Migrations.RestoreComprehensiveGdpr do
  use Ecto.Migration
  @disable_ddl_transaction true

  def up do
    # First, add missing GDPR fields to existing users table
    # First, add missing GDPR fields to existing users table
    execute "ALTER TABLE platform.users ADD COLUMN IF NOT EXISTS deleted_at timestamp(6) without time zone"
    execute "ALTER TABLE platform.users ADD COLUMN IF NOT EXISTS deletion_reason text"
    execute "ALTER TABLE platform.users ADD COLUMN IF NOT EXISTS gdpr_retention_expires_at timestamp(6) without time zone"
    execute "ALTER TABLE platform.users ADD COLUMN IF NOT EXISTS anonymized_at timestamp(6) without time zone"

    # Drop and recreate status index to include GDPR status values
    drop_if_exists(index(:users, [:status]))
    create_if_not_exists index(:users, [:gdpr_retention_expires_at])

    # Drop existing incomplete GDPR tables if they exist
    drop_if_exists(table(:gdpr_requests))
    drop_if_exists(table(:gdpr_consents))
    drop_if_exists(table(:gdpr_audit_logs))

    # Create comprehensive GDPR schema

    # Main compliance requests table
    create table(:gdpr_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      # deletion, export, correction, restriction
      add :type, :string, null: false
      # pending, processing, completed, failed
      add :status, :string, null: false, default: "pending"
      add :reason, :string
      add :actor_id, :binary_id
      add :data, :jsonb
      add :expires_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :error_message, :text

      timestamps()
    end

    create_if_not_exists index(:gdpr_requests, [:user_id])
    create_if_not_exists index(:gdpr_requests, [:type, :status])
    create_if_not_exists index(:gdpr_requests, [:expires_at])

    # Comprehensive consent management
    create table(:gdpr_consents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :purpose, :string, null: false
      # consent, contract, legal_obligation, vital_interests, public_task, legitimate_interests
      add :legal_basis, :string, null: false
      # active, withdrawn, expired
      add :status, :string, null: false, default: "active"
      add :withdrawn_at, :utc_datetime_usec
      add :version, :integer, default: 1
      # What data this consent covers
      add :scope, :jsonb
      add :valid_until, :utc_datetime_usec
      add :metadata, :jsonb

      timestamps()
    end

    create_if_not_exists index(:gdpr_consents, [:user_id])
    create_if_not_exists index(:gdpr_consents, [:purpose, :status])
    create_if_not_exists unique_index(:gdpr_consents, [:user_id, :purpose, :version])

    # Comprehensive audit trail
    create table(:gdpr_audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id
      add :actor_id, :binary_id
      add :action, :string, null: false
      add :resource_type, :string
      add :resource_id, :binary_id
      add :old_values, :jsonb
      add :new_values, :jsonb
      add :metadata, :jsonb
      add :ip_address, :string
      add :user_agent, :string
      add :session_id, :string
      add :request_id, :string
      add :timestamp, :utc_datetime_usec, null: false

      timestamps()
    end

    create_if_not_exists index(:gdpr_audit_logs, [:user_id])
    create_if_not_exists index(:gdpr_audit_logs, [:actor_id])
    create_if_not_exists index(:gdpr_audit_logs, [:action])
    create_if_not_exists index(:gdpr_audit_logs, [:timestamp])
    create_if_not_exists index(:gdpr_audit_logs, [:resource_type, :resource_id])

    # Data retention schedules
    create table(:gdpr_retention_schedules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :data_category, :string, null: false
      add :retention_days, :integer, null: false
      add :expires_at, :utc_datetime_usec, null: false
      # delete, anonymize, archive
      add :action, :string, null: false
      # scheduled, processing, completed, failed
      add :status, :string, null: false, default: "scheduled"
      # low, normal, high, urgent
      add :priority, :string, default: "normal"
      add :legal_hold, :boolean, default: false
      add :processed_at, :utc_datetime_usec
      add :error_message, :text

      timestamps()
    end

    create_if_not_exists index(:gdpr_retention_schedules, [:user_id])
    create_if_not_exists index(:gdpr_retention_schedules, [:expires_at])
    create_if_not_exists index(:gdpr_retention_schedules, [:status, :priority])

    # Export tracking
    create table(:gdpr_exports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :request_id, :binary_id, null: false
      add :format, :string, null: false
      # pending, processing, ready, expired, failed
      add :status, :string, null: false, default: "pending"
      add :file_path, :string
      add :file_size, :integer
      add :download_count, :integer, default: 0
      add :max_downloads, :integer, default: 3
      add :expires_at, :utc_datetime_usec, null: false
      add :metadata, :jsonb
      add :error_message, :text

      timestamps()
    end

    create_if_not_exists index(:gdpr_exports, [:user_id])
    create_if_not_exists index(:gdpr_exports, [:request_id])
    create_if_not_exists index(:gdpr_exports, [:status, :expires_at])

    # Anonymization tracking
    create table(:gdpr_anonymization_records, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :table_name, :string, null: false
      add :column_name, :string, null: false
      add :original_value_hash, :string, null: false
      add :anonymization_strategy, :string, null: false
      add :reversible, :boolean, default: false
      add :salt, :string
      add :anonymized_at, :utc_datetime_usec, null: false
      add :reversal_key, :string

      timestamps()
    end

    create_if_not_exists index(:gdpr_anonymization_records, [:user_id])
    create_if_not_exists index(:gdpr_anonymization_records, [:table_name, :column_name])

    # Legal holds
    create table(:gdpr_legal_holds, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :case_reference, :string, null: false
      add :reason, :text
      # active, released
      add :status, :string, null: false, default: "active"
      add :placed_by, :binary_id, null: false
      add :released_by, :binary_id
      add :released_at, :utc_datetime_usec
      # What data is preserved
      add :scope, :jsonb

      timestamps()
    end

    create_if_not_exists index(:gdpr_legal_holds, [:user_id])
    create_if_not_exists index(:gdpr_legal_holds, [:case_reference])
    create_if_not_exists index(:gdpr_legal_holds, [:status])
  end

  def down do
    # Remove GDPR fields from users table (status is part of core schema)
    alter table(:users) do
      remove :deleted_at
      remove :deletion_reason
      remove :gdpr_retention_expires_at
      remove :anonymized_at
    end

    drop table(:gdpr_legal_holds)
    drop table(:gdpr_anonymization_records)
    drop table(:gdpr_exports)
    drop table(:gdpr_retention_schedules)
    drop table(:gdpr_audit_logs)
    drop table(:gdpr_consents)
    drop table(:gdpr_requests)
  end
end
