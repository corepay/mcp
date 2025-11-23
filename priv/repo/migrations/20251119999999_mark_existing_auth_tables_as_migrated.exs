defmodule Mcp.Repo.Migrations.MarkExistingAuthTablesAsMigrated do
  use Ecto.Migration

  def up do
    # This migration handles the case where authentication-related tables already exist
    # in the platform schema but weren't created through Ecto migrations.
    # We mark them as already migrated by inserting their migration versions directly.

    # Since these tables already exist, we don't need to create them.
    # We just need to mark their migrations as complete.

    # Mark the create_users migration as complete
    execute """
    INSERT INTO schema_migrations (version, inserted_at)
    VALUES ('20250117000003', NOW())
    ON CONFLICT (version) DO NOTHING
    """

    # Mark the create_user_profiles migration as complete
    execute """
    INSERT INTO schema_migrations (version, inserted_at)
    VALUES ('20250117000004', NOW())
    ON CONFLICT (version) DO NOTHING
    """

    # Mark the create_tenants migration as complete
    execute """
    INSERT INTO schema_migrations (version, inserted_at)
    VALUES ('20250117000005', NOW())
    ON CONFLICT (version) DO NOTHING
    """

    # Ensure platform schema exists
    execute "CREATE SCHEMA IF NOT EXISTS platform", "DROP SCHEMA IF EXISTS platform CASCADE"
  end

  def down do
    # When rolling back, we remove these migration records from schema_migrations
    # but we don't drop the actual tables since they may contain data
    execute "DELETE FROM schema_migrations WHERE version = '20250117000003'"
    execute "DELETE FROM schema_migrations WHERE version = '20250117000004'"
    execute "DELETE FROM schema_migrations WHERE version = '20250117000005'"
  end
end
