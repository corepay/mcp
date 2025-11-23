defmodule Mcp.Repo.Migrations.CreateTenantSchemaFunctions do
  use Ecto.Migration

  def up do
    # Function to check if tenant schema exists
    execute """
    CREATE OR REPLACE FUNCTION tenant_schema_exists(tenant_slug TEXT)
    RETURNS BOOLEAN AS $$
    DECLARE
      schema_name TEXT := 'acq_' || tenant_slug;
      schema_exists BOOLEAN;
    BEGIN
      SELECT EXISTS (
        SELECT 1 FROM information_schema.schemata
        WHERE schema_name = schema_name
      ) INTO schema_exists;

      RETURN schema_exists;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Function to create tenant schema with all required tables
    execute """
    CREATE OR REPLACE FUNCTION create_tenant_schema(tenant_slug TEXT)
    RETURNS VOID AS $$
    DECLARE
      schema_name TEXT := 'acq_' || tenant_slug;
    BEGIN
      -- Create schema
      EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_name);

      -- Grant usage
      EXECUTE format('GRANT USAGE ON SCHEMA %I TO PUBLIC', schema_name);

      -- Set search path for subsequent operations
      EXECUTE format('SET search_path TO %I, platform, public', schema_name);
    END;
    $$ LANGUAGE plpgsql;
    """

    # Function to drop tenant schema
    execute """
    CREATE OR REPLACE FUNCTION drop_tenant_schema(tenant_slug TEXT)
    RETURNS VOID AS $$
    DECLARE
      schema_name TEXT := 'acq_' || tenant_slug;
    BEGIN
      EXECUTE format('DROP SCHEMA IF EXISTS %I CASCADE', schema_name);
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  def down do
    execute "DROP FUNCTION IF EXISTS tenant_schema_exists(TEXT)"
    execute "DROP FUNCTION IF EXISTS create_tenant_schema(TEXT)"
    execute "DROP FUNCTION IF EXISTS drop_tenant_schema(TEXT)"
  end
end
