-- Complete PostgreSQL initialization for AI-powered MSP platform

-- Create the database user if it doesn't exist
DO
$do$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE  rolname = 'mcp_user') THEN

      CREATE ROLE mcp_user LOGIN PASSWORD 'mcp_password';
   END IF;
END
$do$;

-- Install required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create platform schemas for shared resources
CREATE SCHEMA IF NOT EXISTS platform;
CREATE SCHEMA IF NOT EXISTS shared;

-- Create platform users table
CREATE TABLE IF NOT EXISTS platform.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create tenant types table
CREATE TABLE IF NOT EXISTS platform.tenant_types (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    ai_risk_profile VARCHAR(50)
);

-- Create payment gateway catalog with Apache AGE for graph relationships
CREATE TABLE IF NOT EXISTS shared.payment_gateways (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    configuration JSONB DEFAULT '{}',
    status VARCHAR(50) DEFAULT 'active',
    processing_times JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Initialize platform admin user with complete access
INSERT INTO platform.users (id, email, password_hash, created_at, updated_at)
VALUES (
    uuid_generate_v4(),
    'platform@admin.com',
    crypt('admin123', gen_salt('bf')),
    NOW(),
    NOW()
) ON CONFLICT DO NOTHING;

-- Create default tenant types with AI categorization
INSERT INTO platform.tenant_types (id, name, description, ai_risk_profile) VALUES
    (1, 'acquirer', 'Bank/Acquirer partners', 'low'),
    (2, 'fintech', 'FinTech/ISV partners', 'medium'),
    (3, 'isv', 'Independent Software Vendors', 'high')
ON CONFLICT DO NOTHING;

-- Create initial payment gateways
INSERT INTO shared.payment_gateways (name, type, configuration, status) VALUES
    ('QorPay', 'payfac',
     '{"features": ["mid_creation", "tokenization", "payment_processing", "ai_underwriting"],
       "apis": ["v1", "v2"], "regions": ["US", "EU", "APAC"]}'::jsonb,
     'active'),
    ('Stripe', 'payment',
     '{"features": ["payments", "customers", "subscriptions", "radar"],
       "apis": ["v1", "v2"], "regions": ["global"]}'::jsonb,
     'active'),
    ('Adyen', 'payment',
     '{"features": ["payments", "tokenization", "risk_management", "revenueprotect"],
       "apis": ["v1", "v2"], "regions": ["global"]}'::jsonb,
     'active')
ON CONFLICT DO NOTHING;

-- Grant necessary permissions to the database user
GRANT ALL PRIVILEGES ON SCHEMA platform TO mcp_user;
GRANT ALL PRIVILEGES ON SCHEMA shared TO mcp_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA platform TO mcp_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA shared TO mcp_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA platform TO mcp_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA shared TO mcp_user;

-- Create tenant schema creation function with full stack support
CREATE OR REPLACE FUNCTION create_tenant_schema(tenant_schema_name TEXT)
RETURNS VOID AS $$
DECLARE
    schema_full_name TEXT;
BEGIN
    schema_full_name := 'acq_' || tenant_schema_name;

    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_full_name);

    -- Grant permissions to mcp_user
    EXECUTE format('GRANT ALL ON SCHEMA %I TO mcp_user', schema_full_name);
    EXECUTE format('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA %I TO mcp_user', schema_full_name);
    EXECUTE format('GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA %I TO mcp_user', schema_full_name);

    -- Create comprehensive tenant tables with Apache AGE support

    -- Merchants table for graph-based relationships
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.merchants (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            tenant_id UUID NOT NULL,
            name VARCHAR(255) NOT NULL,
            business_type VARCHAR(100),
            status VARCHAR(50) DEFAULT ''pending'',
            configuration JSONB DEFAULT ''{}'',
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        )', schema_full_name);

    -- Merchant metrics table for analytics
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.merchant_metrics (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            merchant_id UUID NOT NULL,
            metric_date DATE NOT NULL,
            transaction_volume DECIMAL(15,2),
            transaction_count INTEGER,
            average_transaction_amount DECIMAL(10,2),
            risk_score DECIMAL(5,2),
            created_at TIMESTAMPTZ DEFAULT NOW()
        )', schema_full_name);

    -- MIDs table for payment processing
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.mids (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            merchant_id UUID NOT NULL,
            name VARCHAR(255) NOT NULL,
            gateway_id INTEGER NOT NULL,
            gateway_configuration JSONB DEFAULT ''{}'',
            routing_rules JSONB DEFAULT ''{}'',
            performance_metrics JSONB DEFAULT ''{}'',
            status VARCHAR(50) DEFAULT ''active'',
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        )', schema_full_name);

    -- MID performance tracking
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.mid_performance (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            mid_id UUID NOT NULL,
            performance_date DATE NOT NULL,
            response_time_ms INTEGER,
            success_rate DECIMAL(5,2),
            throughput_tps DECIMAL(10,2),
            error_count INTEGER,
            created_at TIMESTAMPTZ DEFAULT NOW()
        )', schema_full_name);

    -- Stores table for physical locations
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I.stores (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            merchant_id UUID NOT NULL,
            name VARCHAR(255) NOT NULL,
            operating_hours JSONB DEFAULT ''{}'',
            status VARCHAR(50) DEFAULT ''active'',
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        )', schema_full_name);

    RAISE NOTICE 'Complete tenant schema % created successfully', schema_full_name;
END;
$$ LANGUAGE plpgsql;

-- Create function for checking tenant schema exists
CREATE OR REPLACE FUNCTION tenant_schema_exists(tenant_schema_name TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM information_schema.schemata
        WHERE schema_name = 'acq_' || tenant_schema_name
    );
END;
$$ LANGUAGE plpgsql;

-- Create comprehensive analytics functions
CREATE OR REPLACE FUNCTION analyze_merchant_performance(tenant_schema_name TEXT, merchant_id UUID, days INTEGER DEFAULT 30)
RETURNS TABLE(
    metric_date DATE,
    transaction_volume DECIMAL,
    transaction_count BIGINT,
    average_amount DECIMAL,
    risk_score DECIMAL,
    ai_recommendation TEXT
) AS $$
BEGIN
    RETURN QUERY
    EXECUTE format('
        SELECT
            metric_date,
            SUM(transaction_volume) as volume,
            SUM(transaction_count) as count,
            AVG(average_transaction_amount) as avg_amount,
            AVG(risk_score) as avg_risk,
            CASE
                WHEN AVG(risk_score) < 0.3 THEN ''Low Risk - Standard Processing''
                WHEN AVG(risk_score) < 0.7 THEN ''Medium Risk - Enhanced Monitoring''
                ELSE ''High Risk - Additional Verification Required''
            END as recommendation
        FROM %I.merchant_metrics
        WHERE merchant_id = $2
        AND metric_date >= CURRENT_DATE - INTERVAL ''%s days''
        GROUP BY metric_date
        ORDER BY metric_date DESC
    ', 'acq_' || tenant_schema_name || '.merchant_metrics', days);
END;
$$ LANGUAGE plpgsql;

COMMIT;