defmodule Mcp.Repo.Migrations.CreatePlatformSchemaAndExtensions do
  use Ecto.Migration

  def up do
    # Create schemas
    execute "CREATE SCHEMA IF NOT EXISTS platform"
    execute "CREATE SCHEMA IF NOT EXISTS shared"

    # Enable required PostgreSQL extensions for MCP platform
    execute "CREATE EXTENSION IF NOT EXISTS citext"
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""
    # Core extensions for PostgreSQL 17 (TimescaleDB, PostGIS, pgvector, AGE to be added later)
    execute "CREATE EXTENSION IF NOT EXISTS pg_stat_statements CASCADE"

    # AGE extension will be loaded when installed

    # Set default search path to platform, shared, public
    execute "ALTER DATABASE #{repo().config()[:database]} SET search_path TO platform, shared, public"
  end

  def down do
    execute "DROP SCHEMA IF EXISTS platform CASCADE"
    execute "DROP SCHEMA IF EXISTS shared CASCADE"
    execute "DROP EXTENSION IF EXISTS citext CASCADE"
    execute "DROP EXTENSION IF EXISTS pgcrypto CASCADE"
    execute "DROP EXTENSION IF EXISTS \"uuid-ossp\" CASCADE"
    # Advanced extensions (TimescaleDB, PostGIS, pgvector, AGE to be added later)
    execute "DROP EXTENSION IF EXISTS pg_stat_statements CASCADE"
  end
end
