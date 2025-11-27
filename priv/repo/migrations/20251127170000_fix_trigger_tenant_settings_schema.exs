defmodule Mcp.Repo.Migrations.FixTriggerTenantSettingsSchema do
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE FUNCTION platform.trigger_tenant_settings_schema() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
    BEGIN
        PERFORM platform.ensure_tenant_settings_schema(NEW.id);
        RETURN NEW;
    END;
    $$;
    """
  end

  def down do
    execute """
    CREATE OR REPLACE FUNCTION platform.trigger_tenant_settings_schema() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
    BEGIN
        PERFORM ensure_tenant_settings_schema(NEW.id);
        RETURN NEW;
    END;
    $$;
    """
  end
end
