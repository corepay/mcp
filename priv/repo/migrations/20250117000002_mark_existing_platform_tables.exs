defmodule Mcp.Repo.Migrations.MarkExistingPlatformTables do
  use Ecto.Migration

  def up do
    # This migration handles the case where platform schema tables already exist
    # but weren't created through Ecto migrations. We mark them as already created
    # by inserting this migration version directly into schema_migrations.

    # Since the tables already exist, we don't need to create them.
    # We'll just ensure the platform schema exists and mark this migration as complete.
    execute "CREATE SCHEMA IF NOT EXISTS platform", "DROP SCHEMA IF EXISTS platform CASCADE"
  end

  def down do
    # When rolling back, we don't drop the tables since they may contain data
    # We just remove the migration record from schema_migrations
    # No-op for rollback
    execute "SELECT 1", "SELECT 1"
  end
end
