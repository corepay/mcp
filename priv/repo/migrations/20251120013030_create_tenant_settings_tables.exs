defmodule Mcp.Repo.Migrations.CreateTenantSettingsTables do
  use Ecto.Migration
  @disable_ddl_transaction true

  def up do
    # Create tenant_settings table
    create table(:tenant_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :category, :string, null: false
      add :key, :string, null: false
      add :value, :jsonb
      add :value_type, :string, default: "string", null: false
      add :encrypted, :boolean, default: false, null: false
      add :public, :boolean, default: false, null: false
      add :validation_rules, :jsonb, default: "{}", null: false
      add :description, :string
      add :last_updated_by, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    # Create unique index for tenant_id, category, key
    create unique_index(:tenant_settings, [:tenant_id, :category, :key],
             name: :unique_tenant_setting
           )

    # Create indexes for performance
    create index(:tenant_settings, [:tenant_id])
    create index(:tenant_settings, [:tenant_id, :category])
    create index(:tenant_settings, [:tenant_id, :category, :public])

    # Create feature_toggles table
    create table(:feature_toggles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :feature, :string, null: false
      add :enabled, :boolean, default: false, null: false
      add :configuration, :jsonb, default: "{}", null: false
      add :restrictions, :jsonb, default: "{}", null: false
      add :enabled_by, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :enabled_at, :utc_datetime_usec
      add :metadata, :jsonb, default: "{}", null: false

      timestamps()
    end

    # Create unique index for tenant_id, feature
    create unique_index(:feature_toggles, [:tenant_id, :feature], name: :unique_tenant_feature)

    # Create indexes for performance
    create index(:feature_toggles, [:tenant_id])
    create index(:feature_toggles, [:tenant_id, :enabled])
    create index(:feature_toggles, [:feature])

    # Create tenant_branding table
    create table(:tenant_branding, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :is_active, :boolean, default: false, null: false
      add :logo_url, :string
      add :logo_dark_url, :string
      add :favicon_url, :string
      add :primary_color, :string
      add :secondary_color, :string
      add :accent_color, :string
      add :background_color, :string
      add :text_color, :string
      add :font_family, :string
      add :theme, :string, default: "light", null: false
      add :custom_css, :text
      add :brand_assets, :jsonb, default: "{}", null: false
      add :email_template_branding, :jsonb, default: "{}", null: false
      add :mobile_branding, :jsonb, default: "{}", null: false
      add :portal_branding, :jsonb, default: "{}", null: false
      add :created_by, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :updated_by, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    # Create unique index for tenant_id, name
    create unique_index(:tenant_branding, [:tenant_id, :name], name: :unique_tenant_branding_name)

    # Create indexes for performance
    create index(:tenant_branding, [:tenant_id])
    create index(:tenant_branding, [:tenant_id, :is_active])

    # Create a function to trigger schema creation for tenant-specific settings
    execute """
            CREATE OR REPLACE FUNCTION ensure_tenant_settings_schema(tenant_uuid UUID)
            RETURNS VOID AS $$
            DECLARE
                schema_name TEXT;
            BEGIN
                -- Get schema name from tenants table
                SELECT company_schema INTO schema_name
                FROM tenants
                WHERE id = tenant_uuid;

                -- Create schema if it doesn't exist
                IF schema_name IS NOT NULL THEN
                    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_name);

                    -- Grant permissions
                    EXECUTE format('GRANT USAGE ON SCHEMA %I TO mcp_app', schema_name);
                    EXECUTE format('GRANT CREATE ON SCHEMA %I TO mcp_app', schema_name);

                    -- Create tenant settings table in the schema if it doesn't exist
                    EXECUTE format('
                        CREATE TABLE IF NOT EXISTS %I.tenant_settings (
                            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                            category TEXT NOT NULL,
                            key TEXT NOT NULL,
                            value JSONB,
                            value_type TEXT DEFAULT ''string'',
                            encrypted BOOLEAN DEFAULT false,
                            public BOOLEAN DEFAULT false,
                            validation_rules JSONB DEFAULT ''{}'',
                            description TEXT,
                            last_updated_by UUID,
                            inserted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                            UNIQUE(category, key)
                        )', schema_name);

                    -- Create indexes in tenant schema
                    EXECUTE format('CREATE INDEX IF NOT EXISTS %I.idx_tenant_settings_category ON tenant_settings (category)', schema_name);
                    EXECUTE format('CREATE INDEX IF NOT EXISTS %I.idx_tenant_settings_public ON tenant_settings (public)', schema_name);
                END IF;
            END;
            $$ LANGUAGE plpgsql;
            """,
            """
            DROP FUNCTION IF EXISTS ensure_tenant_settings_schema(UUID);
            """

    # Create a trigger to automatically create schema for tenant settings
    execute """
            CREATE OR REPLACE FUNCTION trigger_tenant_settings_schema()
            RETURNS TRIGGER AS $$
            BEGIN
                PERFORM ensure_tenant_settings_schema(NEW.id);
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
            """,
            """
            DROP FUNCTION IF EXISTS trigger_tenant_settings_schema();
            """

    # Create trigger on tenants table
    execute """
            CREATE TRIGGER tenant_settings_schema_trigger
            AFTER INSERT ON tenants
            FOR EACH ROW
            EXECUTE FUNCTION trigger_tenant_settings_schema();
            """,
            """
            DROP TRIGGER IF EXISTS tenant_settings_schema_trigger ON tenants;
            """

    # Insert default ISP feature toggles for existing tenants
    execute """
    INSERT INTO feature_toggles (id, tenant_id, feature, enabled, configuration, restrictions, metadata, inserted_at, updated_at)
    SELECT
        gen_random_uuid(),
        t.id,
        ft.feature,
        ft.enabled,
        ft.configuration,
        ft.restrictions,
        ft.metadata,
        NOW(),
        NOW()
    FROM tenants t,
    (SELECT
        unnest(ARRAY[
            'customer_portal', 'billing_management', 'network_monitoring',
            'ticketing_system', 'two_factor_auth', 'email_campaigns'
        ]) as feature,
        unnest(ARRAY[true, true, false, false, true, false]) as enabled,
        unnest(ARRAY[
            '{"max_customers": 1000}'::jsonb,
            '{"auto_invoicing": true, "grace_period_days": 7}'::jsonb,
            '{"alert_threshold": 90, "monitoring_interval": 300}'::jsonb,
            '{"auto_assign": false, "priority_levels": 3}'::jsonb,
            '{"methods": ["totp", "sms"]}'::jsonb,
            '{"provider": "sendgrid", "templates_enabled": true}'::jsonb
        ]) as configuration,
        unnest(ARRAY[
            '{}'::jsonb,
            '{}'::jsonb,
            '{"max_devices": 500}'::jsonb,
            '{"max_tickets": 1000}'::jsonb,
            '{}'::jsonb,
            '{"monthly_limit": 5000}'::jsonb
        ]) as restrictions,
        unnest(ARRAY[
            '{"auto_enabled": true}'::jsonb,
            '{"auto_enabled": true}'::jsonb,
            '{"auto_enabled": false}'::jsonb,
            '{"auto_enabled": false}'::jsonb,
            '{"auto_enabled": true}'::jsonb,
            '{"auto_enabled": false}'::jsonb
        ]) as metadata
    ) ft
    WHERE NOT EXISTS (
        SELECT 1 FROM feature_toggles
        WHERE tenant_id = t.id AND feature = ft.feature
    );
    """
  end

  def down do
    # Drop tables
    drop table(:tenant_settings)
    drop table(:feature_toggles)
    drop table(:tenant_branding)

    # Drop functions and triggers
    execute """
    DROP TRIGGER IF EXISTS tenant_settings_schema_trigger ON tenants;
    DROP FUNCTION IF EXISTS trigger_tenant_settings_schema();
    DROP FUNCTION IF EXISTS ensure_tenant_settings_schema(UUID);
    """
  end
end
