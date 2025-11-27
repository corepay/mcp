defmodule Mcp.Repo.Migrations.FixTenantSchemaExists do
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE FUNCTION platform.tenant_schema_exists(tenant_slug text) RETURNS boolean
        LANGUAGE plpgsql
        AS $$
    DECLARE
      _schema_name TEXT := 'acq_' || tenant_slug;
      schema_exists BOOLEAN;
    BEGIN
      SELECT EXISTS (
        SELECT 1 FROM information_schema.schemata
        WHERE schema_name = _schema_name
      ) INTO schema_exists;
      RETURN schema_exists;
    END;
    $$;
    """
  end

  def down do
    # Revert to the buggy version? Probably not necessary, but for correctness:
    execute """
    CREATE OR REPLACE FUNCTION platform.tenant_schema_exists(tenant_slug text) RETURNS boolean
        LANGUAGE plpgsql
        AS $$
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
    $$;
    """
  end
end
