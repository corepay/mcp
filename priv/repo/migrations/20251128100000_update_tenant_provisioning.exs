defmodule Mcp.Repo.Migrations.UpdateTenantProvisioning do
  use Ecto.Migration

  def up do
    # Define function to provision tables in a tenant schema
    execute """
    CREATE OR REPLACE FUNCTION platform.provision_tenant_tables(schema_name text) RETURNS void
        LANGUAGE plpgsql
        AS $$
    BEGIN
        -- Merchants Table
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I.merchants (
                id UUID PRIMARY KEY,
                slug TEXT NOT NULL,
                business_name TEXT NOT NULL,
                subdomain TEXT NOT NULL,
                status TEXT DEFAULT ''active'',
                plan TEXT DEFAULT ''starter'',
                risk_level TEXT DEFAULT ''low'',
                risk_profile TEXT DEFAULT ''low'',
                verification_status TEXT DEFAULT ''pending'',
                kyc_status TEXT DEFAULT ''pending'',
                country TEXT DEFAULT ''US'',
                timezone TEXT DEFAULT ''UTC'',
                default_currency TEXT DEFAULT ''USD'',
                settings JSONB DEFAULT ''{}'',
                branding JSONB DEFAULT ''{}'',
                kyc_documents JSONB DEFAULT ''{}'',
                operating_hours JSONB DEFAULT ''{}'',
                processing_limits JSONB DEFAULT ''{}'',
                max_stores INTEGER DEFAULT 0,
                max_products INTEGER,
                max_monthly_volume DECIMAL,
                risk_score INTEGER,
                business_type TEXT,
                ein TEXT,
                website_url TEXT,
                description TEXT,
                address_line1 TEXT,
                address_line2 TEXT,
                city TEXT,
                state TEXT,
                postal_code TEXT,
                phone TEXT,
                support_email TEXT,
                mcc TEXT,
                tax_id_type TEXT,
                kyc_verified_at TIMESTAMP,
                custom_domain TEXT,
                dba_name TEXT,
                reseller_id UUID,
                inserted_at TIMESTAMP NOT NULL,
                updated_at TIMESTAMP NOT NULL
            )', schema_name);

        -- Underwriting Applications
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I.underwriting_applications (
                id UUID PRIMARY KEY,
                status TEXT DEFAULT ''draft'',
                application_data JSONB DEFAULT ''{}'',
                risk_score BIGINT DEFAULT 0,
                merchant_id UUID NOT NULL,
                inserted_at TIMESTAMP NOT NULL,
                updated_at TIMESTAMP NOT NULL
            )', schema_name);

        -- Underwriting Reviews
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I.underwriting_reviews (
                id UUID PRIMARY KEY,
                decision TEXT NOT NULL,
                notes TEXT,
                risk_score INTEGER,
                application_id UUID NOT NULL,
                inserted_at TIMESTAMP NOT NULL,
                updated_at TIMESTAMP NOT NULL
            )', schema_name);

        -- Risk Assessments
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I.risk_assessments (
                id UUID PRIMARY KEY,
                score BIGINT NOT NULL,
                factors JSONB DEFAULT ''{}'',
                recommendation TEXT,
                risk_level TEXT,
                merchant_id UUID,
                inserted_at TIMESTAMP NOT NULL,
                updated_at TIMESTAMP NOT NULL
            )', schema_name);

        -- Underwriting Clients
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I.underwriting_clients (
                id UUID PRIMARY KEY,
                type TEXT NOT NULL,
                email TEXT,
                phone TEXT,
                external_id TEXT,
                person_details JSONB DEFAULT ''{}'',
                company_details JSONB DEFAULT ''{}'',
                application_id UUID,
                inserted_at TIMESTAMP NOT NULL,
                updated_at TIMESTAMP NOT NULL
            )', schema_name);

        -- Underwriting Addresses
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I.underwriting_addresses (
                id UUID PRIMARY KEY,
                line1 TEXT,
                line2 TEXT,
                city TEXT,
                state TEXT,
                postal_code TEXT,
                country TEXT,
                type TEXT,
                client_id UUID,
                inserted_at TIMESTAMP NOT NULL,
                updated_at TIMESTAMP NOT NULL
            )', schema_name);

        -- Underwriting Documents
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I.underwriting_documents (
                id UUID PRIMARY KEY,
                type TEXT NOT NULL,
                issuing_country TEXT,
                external_id TEXT,
                status TEXT DEFAULT ''pending'',
                client_id UUID,
                inserted_at TIMESTAMP NOT NULL,
                updated_at TIMESTAMP NOT NULL
            )', schema_name);

        -- Underwriting Checks
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I.underwriting_checks (
                id UUID PRIMARY KEY,
                type TEXT NOT NULL,
                status TEXT DEFAULT ''pending'',
                outcome TEXT DEFAULT ''none'',
                external_id TEXT,
                raw_result JSONB,
                client_id UUID,
                document_id UUID,
                inserted_at TIMESTAMP NOT NULL,
                updated_at TIMESTAMP NOT NULL
            )', schema_name);

    END;
    $$;
    """

    # Update create_tenant_schema to call provision_tenant_tables
    execute """
    CREATE OR REPLACE FUNCTION platform.create_tenant_schema(tenant_slug text) RETURNS void
        LANGUAGE plpgsql
        AS $$
    DECLARE
      schema_name TEXT := 'acq_' || tenant_slug;
    BEGIN
      -- Create schema
      EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_name);

      -- Grant usage
      EXECUTE format('GRANT USAGE ON SCHEMA %I TO PUBLIC', schema_name);

      -- Provision tables
      PERFORM platform.provision_tenant_tables(schema_name);

      -- Set search path for subsequent operations
      EXECUTE format('SET search_path TO %I, platform, public', schema_name);
    END;
    $$;
    """
  end

  def down do
    # Revert create_tenant_schema to original version (without provisioning call)
    execute """
    CREATE OR REPLACE FUNCTION platform.create_tenant_schema(tenant_slug text) RETURNS void
        LANGUAGE plpgsql
        AS $$
    DECLARE
      schema_name TEXT := 'acq_' || tenant_slug;
    BEGIN
      -- Create schema
      EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_name);

      -- Grant usage
      EXECUTE format('GRANT USAGE ON SCHEMA %I TO PUBLIC', schema_name);

      -- Set search path for subsequent operations
      EXECUTE format('SET search_path TO %I, platform, public', schema_name);
    END;
    $$;
    """

    execute "DROP FUNCTION IF EXISTS platform.provision_tenant_tables(text)"
  end
end
