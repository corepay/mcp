defmodule Mcp.Repo.Migrations.AddGdprCompliance do
  @moduledoc """
  Comprehensive GDPR compliance migration.

  Adds soft delete functionality, audit trails, and data retention tracking
  to ensure compliance with GDPR requirements including the "right to be forgotten".
  """

  use Ecto.Migration

  def up do
    # Add GDPR fields to existing users table
    alter table(:users, prefix: "platform") do
      # GDPR deletion tracking
      add :gdpr_deletion_requested_at, :utc_datetime
      add :gdpr_deletion_reason, :text
      add :gdpr_retention_expires_at, :utc_datetime
      add :gdpr_anonymized_at, :utc_datetime

      # Data export functionality
      add :gdpr_data_export_token, :uuid
      add :gdpr_last_exported_at, :utc_datetime

      # Consent management
      add :gdpr_consent_record, :jsonb, default: "{}"
      add :gdpr_marketing_consent, :boolean, default: false
      add :gdpr_analytics_consent, :boolean, default: false

      # Account deletion request tracking
      add :gdpr_deletion_request_ip, :inet
      add :gdpr_deletion_request_user_agent, :text
    end

    # Create GDPR audit trail table
    create table(:gdpr_audit_trail, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, :uuid, null: false, references: :users, type: :uuid, prefix: "platform"

      # Action details
      add :action_type, :text, null: false
      # 'user', 'system', 'admin'
      add :actor_type, :text
      add :actor_id, :uuid
      add :ip_address, :inet
      add :user_agent, :text
      add :request_id, :text

      # Compliance tracking
      add :data_categories, :jsonb, default: "[]"
      add :legal_basis, :text
      add :retention_period_days, :integer

      # Additional details
      add :details, :jsonb, default: "{}"
      add :processed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Create data retention schedule table
    create table(:data_retention_schedule, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, :uuid, null: false, references: :users, type: :uuid, prefix: "platform"

      # Schedule details
      add :data_category, :text, null: false
      add :retention_days, :integer, null: false
      add :expires_at, :utc_datetime, null: false

      # Processing status
      # 'scheduled', 'processing', 'processed', 'failed'
      add :status, :text, default: "scheduled"
      add :processing_started_at, :utc_datetime
      add :processing_completed_at, :utc_datetime
      add :retry_count, :integer, default: 0
      add :max_retries, :integer, default: 3

      # Error handling
      add :error_details, :jsonb, default: "{}"
      add :last_error_at, :utc_datetime

      # Oban job tracking
      add :oban_job_id, :bigint

      timestamps(type: :utc_datetime)
    end

    # Create consent records table for granular consent tracking
    create table(:gdpr_consent_records, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, :uuid, null: false, references: :users, type: :uuid, prefix: "platform"

      # Consent details
      # 'marketing', 'analytics', 'essential', 'third_party'
      add :consent_type, :text, null: false
      add :granted, :boolean, null: false
      # 'consent', 'contract', 'legal_obligation', 'legitimate_interest'
      add :legal_basis, :text, null: false
      add :purpose, :text, null: false
      add :data_categories, :jsonb, default: "[]"

      # Timing and validity
      add :granted_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :is_current, :boolean, default: true

      # Request context
      add :ip_address, :inet
      add :user_agent, :text
      add :request_id, :text
      add :consent_form_version, :text

      timestamps(type: :utc_datetime)
    end

    # Create data export requests table
    create table(:gdpr_data_export_requests, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, :uuid, null: false, references: :users, type: :uuid, prefix: "platform"

      # Request details
      add :export_token, :uuid, null: false, unique: true
      # 'json', 'csv', 'pdf'
      add :requested_format, :text, default: "json"
      add :data_categories, :jsonb, default: "[]"
      # 'requested', 'processing', 'completed', 'expired', 'failed'
      add :status, :text, default: "requested"

      # Processing tracking
      add :requested_at, :utc_datetime, null: false
      add :processing_started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false

      # File details
      add :file_path, :text
      add :file_size_bytes, :bigint
      add :download_count, :integer, default: 0
      add :max_downloads, :integer, default: 5
      add :last_downloaded_at, :utc_datetime

      # Request context
      add :ip_address, :inet
      add :user_agent, :text
      add :request_id, :text

      # Error handling
      add :error_details, :jsonb, default: "{}"
      add :oban_job_id, :bigint

      timestamps(type: :utc_datetime)
    end

    # Create indexes for users table
    create index(:users, [:gdpr_deletion_requested_at], prefix: "platform")
    create index(:users, [:gdpr_retention_expires_at], prefix: "platform")
    create index(:users, [:gdpr_anonymized_at], prefix: "platform")

    create index(:users, [:gdpr_data_export_token],
             prefix: "platform",
             unique: true,
             where: "gdpr_data_export_token IS NOT NULL"
           )

    # Create indexes for gdpr_audit_trail
    create index(:gdpr_audit_trail, [:user_id], prefix: "platform")
    create index(:gdpr_audit_trail, [:action_type], prefix: "platform")
    create index(:gdpr_audit_trail, [:actor_type, :actor_id], prefix: "platform")
    create index(:gdpr_audit_trail, [:inserted_at], prefix: "platform")
    create index(:gdpr_audit_trail, [:processed_at], prefix: "platform")

    # Create indexes for data_retention_schedule
    create index(:data_retention_schedule, [:user_id], prefix: "platform")
    create index(:data_retention_schedule, [:status], prefix: "platform")
    create index(:data_retention_schedule, [:expires_at], prefix: "platform")
    create index(:data_retention_schedule, [:data_category], prefix: "platform")

    create index(:data_retention_schedule, [:oban_job_id],
             prefix: "platform",
             unique: true,
             where: "oban_job_id IS NOT NULL"
           )

    # Create indexes for gdpr_consent_records
    create index(:gdpr_consent_records, [:user_id], prefix: "platform")
    create index(:gdpr_consent_records, [:consent_type], prefix: "platform")
    create index(:gdpr_consent_records, [:is_current], prefix: "platform")
    create index(:gdpr_consent_records, [:granted_at], prefix: "platform")
    create index(:gdpr_consent_records, [:expires_at], prefix: "platform")

    # Create indexes for gdpr_data_export_requests
    create index(:gdpr_data_export_requests, [:user_id], prefix: "platform")
    create index(:gdpr_data_export_requests, [:export_token], prefix: "platform", unique: true)
    create index(:gdpr_data_export_requests, [:status], prefix: "platform")
    create index(:gdpr_data_export_requests, [:expires_at], prefix: "platform")

    create index(:gdpr_data_export_requests, [:oban_job_id],
             prefix: "platform",
             unique: true,
             where: "oban_job_id IS NOT NULL"
           )

    # Update status constraint to include new GDPR statuses
    execute """
    ALTER TABLE platform.users
    DROP CONSTRAINT IF EXISTS users_status_check
    """

    execute """
    ALTER TABLE platform.users
    ADD CONSTRAINT users_status_check
    CHECK (status IN ('active', 'suspended', 'deletion_requested', 'deleted', 'anonymized', 'purged'))
    """

    # Add helpful constraints
    create constraint(:gdpr_audit_trail, :action_type_check,
             check:
               "action_type IN ('access_request', 'export_request', 'delete_request', 'anonymization', 'data_export', 'consent_granted', 'consent_revoked', 'account_restored')",
             prefix: "platform"
           )

    create constraint(:gdpr_audit_trail, :actor_type_check,
             check: "actor_type IN ('user', 'system', 'admin')",
             prefix: "platform"
           )

    create constraint(:data_retention_schedule, :status_check,
             check: "status IN ('scheduled', 'processing', 'processed', 'failed')",
             prefix: "platform"
           )

    create constraint(:data_retention_schedule, :retry_count_check,
             check: "retry_count >= 0 AND retry_count <= max_retries",
             prefix: "platform"
           )

    create constraint(:gdpr_consent_records, :consent_type_check,
             check: "consent_type IN ('marketing', 'analytics', 'essential', 'third_party')",
             prefix: "platform"
           )

    create constraint(:gdpr_consent_records, :legal_basis_check,
             check:
               "legal_basis IN ('consent', 'contract', 'legal_obligation', 'legitimate_interest')",
             prefix: "platform"
           )

    create constraint(:gdpr_data_export_requests, :status_check,
             check: "status IN ('requested', 'processing', 'completed', 'expired', 'failed')",
             prefix: "platform"
           )

    create constraint(:gdpr_data_export_requests, :format_check,
             check: "requested_format IN ('json', 'csv', 'pdf')",
             prefix: "platform"
           )

    # Add retention function for automatic expiration calculation
    execute """
    CREATE OR REPLACE FUNCTION platform.calculate_retention_expires(retention_days INTEGER)
    RETURNS TIMESTAMP WITH TIME ZONE AS $$
    BEGIN
      RETURN NOW() + (retention_days || ' days')::INTERVAL;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Add function to check if user data should be anonymized
    execute """
    CREATE OR REPLACE FUNCTION platform.should_anonymize_user(user_record platform.users)
    RETURNS BOOLEAN AS $$
    BEGIN
      RETURN (
        user_record.status = 'deleted' AND
        user_record.gdpr_retention_expires_at IS NOT NULL AND
        user_record.gdpr_retention_expires_at < NOW()
      );
    END;
    $$ LANGUAGE plpgsql;
    """

    # Add trigger function for consent record management
    execute """
    CREATE OR REPLACE FUNCTION platform.update_consent_records()
    RETURNS TRIGGER AS $$
    BEGIN
      -- When a new consent is granted, revoke previous ones of the same type
      IF NEW.granted = true AND NEW.is_current = true THEN
        UPDATE platform.gdpr_consent_records
        SET is_current = false, revoked_at = NOW()
        WHERE user_id = NEW.user_id
          AND consent_type = NEW.consent_type
          AND is_current = true
          AND id != NEW.id;
      END IF;

      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Create trigger for automatic consent record updates
    execute """
    CREATE TRIGGER consent_record_update_trigger
      AFTER INSERT ON platform.gdpr_consent_records
      FOR EACH ROW
      EXECUTE FUNCTION platform.update_consent_records();
    """

    # Add GDPR-specific comments for documentation
    execute """
    COMMENT ON TABLE platform.gdpr_audit_trail IS 'Comprehensive audit trail for all GDPR-related actions and data processing activities';
    """

    execute """
    COMMENT ON TABLE platform.data_retention_schedule IS 'Schedule for managing data retention and automatic anonymization of user data';
    """

    execute """
    COMMENT ON TABLE platform.gdpr_consent_records IS 'Granular consent tracking for GDPR compliance with audit trail';
    """

    execute """
    COMMENT ON TABLE platform.gdpr_data_export_requests IS 'Data Subject Access Request (DSAR) export request management';
    """
  end

  def down do
    # Drop triggers and functions
    execute "DROP TRIGGER IF EXISTS consent_record_update_trigger ON platform.gdpr_consent_records"
    execute "DROP FUNCTION IF EXISTS platform.update_consent_records()"
    execute "DROP FUNCTION IF EXISTS platform.should_anonymize_user(platform.users)"
    execute "DROP FUNCTION IF EXISTS platform.calculate_retention_expires(INTEGER)"

    # Drop tables
    drop table(:gdpr_data_export_requests, prefix: "platform")
    drop table(:gdpr_consent_records, prefix: "platform")
    drop table(:data_retention_schedule, prefix: "platform")
    drop table(:gdpr_audit_trail, prefix: "platform")

    # Remove GDPR fields from users table
    alter table(:users, prefix: "platform") do
      remove :gdpr_deletion_requested_at
      remove :gdpr_deletion_reason
      remove :gdpr_retention_expires_at
      remove :gdpr_anonymized_at
      remove :gdpr_data_export_token
      remove :gdpr_last_exported_at
      remove :gdpr_consent_record
      remove :gdpr_marketing_consent
      remove :gdpr_analytics_consent
      remove :gdpr_deletion_request_ip
      remove :gdpr_deletion_request_user_agent
    end

    # Restore original status constraint
    execute """
    ALTER TABLE platform.users
    DROP CONSTRAINT IF EXISTS users_status_check
    """

    execute """
    ALTER TABLE platform.users
    ADD CONSTRAINT users_status_check
    CHECK (status IN ('active', 'suspended', 'deleted'))
    """
  end
end
