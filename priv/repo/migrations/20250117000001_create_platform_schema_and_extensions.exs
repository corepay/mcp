defmodule Mcp.Repo.Migrations.CreatePlatformSchemaAndExtensions do
  use Ecto.Migration

  def up do
    # Create platform schema
    execute "CREATE SCHEMA IF NOT EXISTS platform"

    # Enable required PostgreSQL extensions
    execute "CREATE EXTENSION IF NOT EXISTS citext"
    execute "CREATE EXTENSION IF NOT EXISTS postgis"
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""

    # Set default search path
    execute "ALTER DATABASE #{repo().config()[:database]} SET search_path TO platform, public"
  end

  def down do
    execute "DROP SCHEMA IF EXISTS platform CASCADE"
    execute "DROP EXTENSION IF EXISTS citext CASCADE"
    execute "DROP EXTENSION IF EXISTS postgis CASCADE"
    execute "DROP EXTENSION IF EXISTS pgcrypto CASCADE"
    execute "DROP EXTENSION IF EXISTS \"uuid-ossp\" CASCADE"
  end
end
