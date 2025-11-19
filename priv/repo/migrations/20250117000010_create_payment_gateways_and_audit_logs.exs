defmodule Mcp.Repo.Migrations.CreatePaymentGatewaysAndAuditLogs do
  use Ecto.Migration

  def up do
    # ========================================
    # PAYMENT GATEWAYS (Platform-level)
    # ========================================
    create table(:payment_gateways, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Gateway identity
      add :name, :text, null: false
      add :slug, :text, null: false
      add :provider, :text, null: false

      # Configuration
      add :api_version, :text
      add :supported_countries, {:array, :text}
      add :supported_currencies, {:array, :text}
      add :supported_payment_methods, {:array, :text}

      # Capabilities
      add :supports_auth, :boolean, default: true
      add :supports_capture, :boolean, default: true
      add :supports_refund, :boolean, default: true
      add :supports_void, :boolean, default: true
      add :supports_recurring, :boolean, default: false
      add :supports_3ds, :boolean, default: false

      # Credentials (platform-level, encrypted)
      add :credentials, :jsonb, default: "{}"

      # Fees
      add :fee_structure, :jsonb, default: "{}"

      # Status
      add :status, :text, null: false, default: "active"
      add :is_default, :boolean, default: false

      # Metadata
      add :metadata, :jsonb, default: "{}"

      timestamps(type: :utc_datetime, default: fragment("NOW()"))
    end

    # Indexes
    create unique_index(:payment_gateways, [:slug], prefix: "platform")
    create index(:payment_gateways, [:provider], prefix: "platform")
    create index(:payment_gateways, [:status], prefix: "platform")
    create index(:payment_gateways, [:is_default], where: "is_default = true", prefix: "platform")

    # Add constraint
    execute """
    ALTER TABLE platform.payment_gateways
    ADD CONSTRAINT payment_gateways_status_check
    CHECK (status IN ('active', 'maintenance', 'deprecated'))
    """

    execute """
    ALTER TABLE platform.payment_gateways
    ADD CONSTRAINT payment_gateways_provider_check
    CHECK (provider IN ('stripe', 'authorize_net', 'braintree', 'paypal', 'square', 'adyen'))
    """

    # Seed common payment gateways
    execute """
    INSERT INTO platform.payment_gateways (name, slug, provider, supported_countries, supported_currencies, supported_payment_methods, supports_3ds, is_default, fee_structure)
    VALUES
      (
        'Stripe',
        'stripe',
        'stripe',
        ARRAY['US', 'CA', 'GB', 'EU'],
        ARRAY['USD', 'CAD', 'GBP', 'EUR'],
        ARRAY['card', 'ach', 'wallet'],
        true,
        true,
        '{"percentage": 2.9, "fixed": 0.30}'::jsonb
      ),
      (
        'Authorize.Net',
        'authorize_net',
        'authorize_net',
        ARRAY['US', 'CA', 'GB', 'EU'],
        ARRAY['USD', 'CAD', 'GBP', 'EUR'],
        ARRAY['card'],
        false,
        false,
        '{"percentage": 2.9, "fixed": 0.30}'::jsonb
      ),
      (
        'PayPal',
        'paypal',
        'paypal',
        ARRAY['US', 'CA', 'GB', 'EU'],
        ARRAY['USD', 'CAD', 'GBP', 'EUR'],
        ARRAY['paypal', 'card'],
        false,
        false,
        '{"percentage": 2.9, "fixed": 0.30}'::jsonb
      )
    """

    # ========================================
    # AUDIT LOGS
    # ========================================
    create table(:audit_logs, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Actor (who performed the action)
      add :actor_type, :text
      add :actor_id, :uuid

      # Target (what was affected)
      add :target_type, :text
      add :target_id, :uuid

      # Action details
      add :action, :text, null: false
      add :description, :text

      # Changes
      add :changes, :jsonb, default: "{}"

      # Request context
      add :ip_address, :inet
      add :user_agent, :text
      add :request_id, :text

      # Metadata
      add :metadata, :jsonb, default: "{}"

      # Timestamp
      add :created_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    # FK constraints
    execute """
    ALTER TABLE platform.audit_logs
    ADD CONSTRAINT audit_logs_actor_type_fkey
    FOREIGN KEY (actor_type) REFERENCES platform.entity_types(value)
    """

    execute """
    ALTER TABLE platform.audit_logs
    ADD CONSTRAINT audit_logs_target_type_fkey
    FOREIGN KEY (target_type) REFERENCES platform.entity_types(value)
    """

    # Indexes
    create index(:audit_logs, [:actor_type, :actor_id], prefix: "platform")
    create index(:audit_logs, [:target_type, :target_id], prefix: "platform")
    create index(:audit_logs, [:action], prefix: "platform")
    create index(:audit_logs, [:created_at], prefix: "platform")
    create index(:audit_logs, [:request_id], prefix: "platform")

    # Partitioning by month for audit logs (TimescaleDB-ready)
    execute """
    COMMENT ON TABLE platform.audit_logs IS 'Audit log table - ready for TimescaleDB partitioning by created_at'
    """
  end

  def down do
    drop table(:audit_logs, prefix: "platform")
    drop table(:payment_gateways, prefix: "platform")
  end
end
