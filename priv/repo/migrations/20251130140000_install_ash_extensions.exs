defmodule Mcp.Repo.Migrations.InstallAshExtensions do
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION ash_raise_error(json_data jsonb, type_signal bigint)
    RETURNS bigint
    LANGUAGE plpgsql
    AS $$
    BEGIN
        RAISE EXCEPTION 'ash_error: %', json_data;
        RETURN type_signal;
    END;
    $$;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION ash_raise_error(json_data jsonb)
    RETURNS boolean
    LANGUAGE plpgsql
    AS $$
    BEGIN
        RAISE EXCEPTION 'ash_error: %', json_data;
        RETURN NULL;
    END;
    $$;
    """)
  end
end
