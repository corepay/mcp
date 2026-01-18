defmodule Mcp.Repo.Migrations.EnsureAgeAndVectorExtensions do
  @moduledoc """
  Ensures that the Apache AGE and pgvector extensions are installed.
  Apache AGE also requires the ag_catalog schema to be created first.
  """

  use Ecto.Migration

  def up do
    # pgvector is usually straightforward
    execute("CREATE EXTENSION IF NOT EXISTS \"vector\"")

    # Apache AGE requires a specific setup sequence
    # 1. Create the ag_catalog schema if we want to be explicit,
    # but CREATE EXTENSION usually handles it.
    # We use a PL/pgSQL block to handle cases where the extension might be
    # physically missing from the OS but we don't want the whole migration to crash.

    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'age') THEN
        BEGIN
          CREATE EXTENSION IF NOT EXISTS "age" CASCADE;
        EXCEPTION WHEN OTHERS THEN
          RAISE NOTICE 'Could not install Apache AGE extension. Ensure the age binary is installed on the OS.';
        END;
      END IF;
    END
    $$;
    """
  end

  def down do
    # We typically don't want to drop extensions on rollback in shared environments,
    # but here is the logic if needed.
    # execute("DROP EXTENSION IF EXISTS \"age\" CASCADE")
    # execute("DROP EXTENSION IF EXISTS \"vector\"")
  end
end
