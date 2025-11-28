defmodule Mcp.Repo.Migrations.FixEnsureTenantSettingsSchema do
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE FUNCTION platform.ensure_tenant_settings_schema(tenant_uuid uuid) RETURNS void
        LANGUAGE plpgsql
        AS $$
    DECLARE
        schema_name TEXT;
    BEGIN
        -- Get schema name from tenants table
        SELECT company_schema INTO schema_name
        FROM platform.tenants
        WHERE id = tenant_uuid;

        -- Create schema if it doesn't exist
        IF schema_name IS NOT NULL THEN
            EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_name);

            -- Grant permissions if role exists
            IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mcp_app') THEN
                EXECUTE format('GRANT USAGE ON SCHEMA %I TO mcp_app', schema_name);
                EXECUTE format('GRANT CREATE ON SCHEMA %I TO mcp_app', schema_name);
            END IF;

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
            EXECUTE format('CREATE INDEX IF NOT EXISTS idx_tenant_settings_category ON %I.tenant_settings (category)', schema_name);
            EXECUTE format('CREATE INDEX IF NOT EXISTS idx_tenant_settings_public ON %I.tenant_settings (public)', schema_name);
        END IF;
    END;
    $$;
    """
  end

  def down do
    # No op, or revert to the broken version (not recommended)
  end
end
