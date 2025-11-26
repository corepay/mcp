defmodule Mcp.Repo.Migrations.EnableAgeExtension do
  use Ecto.Migration

  def up do
    # Enable AGE extension
    execute "CREATE EXTENSION IF NOT EXISTS age"
    
    # Load AGE library (required for AGE to work)
    execute "LOAD 'age'"
    
    # Set search path to include ag_catalog
    execute "SET search_path = ag_catalog, \"$user\", public, platform"

    # Create tenant graph function
    execute """
    CREATE OR REPLACE FUNCTION create_tenant_schema(tenant_schema_name TEXT)
    RETURNS VOID AS $$
    DECLARE
        schema_full_name TEXT;
        graph_name TEXT;
    BEGIN
        schema_full_name := 'acq_' || tenant_schema_name;
        graph_name := schema_full_name || '_relationships';

        -- Create schema
        EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_full_name);
        
        -- Create graph (AGE requires search_path to include ag_catalog)
        -- We need to ensure we are in the right context
        PERFORM ag_catalog.create_graph(graph_name);

        -- Grant permissions (adjust mcp_user as needed, assuming current user has access)
        -- EXECUTE format('GRANT ALL ON SCHEMA %I TO mcp_user', schema_full_name);

        RAISE NOTICE 'Created tenant schema % with graph %', schema_full_name, graph_name;
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  def down do
    execute "DROP FUNCTION IF EXISTS create_tenant_schema(TEXT)"
    execute "DROP EXTENSION IF EXISTS age"
  end
end
