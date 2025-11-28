defmodule Mcp.Repo.Migrations.FixFunctionSearchPaths do
  use Ecto.Migration

  def up do
    execute "ALTER FUNCTION platform.trigger_tenant_settings_schema() SET search_path = ''"
    execute "ALTER FUNCTION platform.drop_tenant_schema(text) SET search_path = ''"
    execute "ALTER FUNCTION platform.aggregate_hourly_metrics() SET search_path = ''"
    execute "ALTER FUNCTION platform.ensure_tenant_settings_schema(uuid) SET search_path = ''"
    execute "ALTER FUNCTION platform.tenant_schema_exists(text) SET search_path = ''"
    execute "ALTER FUNCTION platform.create_tenant_schema(text) SET search_path = ''"

    execute "ALTER FUNCTION platform.metric_aggregates(uuid, varchar, timestamptz, timestamptz, interval) SET search_path = ''"

    execute "ALTER FUNCTION platform.should_anonymize_user(platform.users) SET search_path = ''"
    execute "ALTER FUNCTION platform.update_consent_records() SET search_path = ''"
    execute "ALTER FUNCTION platform.calculate_retention_expires(integer) SET search_path = ''"
  end

  def down do
    # Reverting SET search_path is usually not necessary or just setting it back to default
    # But since we don't know the default, we can just leave it or set to 'public'
    # Ideally we just leave it as is, as setting it to '' is safer anyway.
    :ok
  end
end
