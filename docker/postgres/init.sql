-- PostgreSQL Extensions Initialization Script for MCP
-- This script enables all required extensions for the MCP platform

-- Basic PostgreSQL 17 extensions (advanced extensions will be added in separate stories)
-- PostGIS, pgvector, and AGE require additional installation steps
-- For now, focusing on core PostgreSQL 17 capabilities

-- Advanced extensions will be loaded in subsequent stories

-- Create schemas required by the application
CREATE SCHEMA IF NOT EXISTS platform;
CREATE SCHEMA IF NOT EXISTS shared;

-- Set default search path
ALTER DATABASE base_mcp_dev SET search_path TO platform, shared, public;

-- Grant permissions to the development user
-- Grant permissions to the development user
GRANT ALL ON SCHEMA platform TO base_mcp_dev;
GRANT ALL ON SCHEMA shared TO base_mcp_dev;
GRANT ALL ON SCHEMA public TO base_mcp_dev;

GRANT ALL ON ALL TABLES IN SCHEMA platform TO base_mcp_dev;
GRANT ALL ON ALL TABLES IN SCHEMA shared TO base_mcp_dev;
GRANT ALL ON ALL TABLES IN SCHEMA public TO base_mcp_dev;
GRANT ALL ON ALL SEQUENCES IN SCHEMA platform TO base_mcp_dev;
GRANT ALL ON ALL SEQUENCES IN SCHEMA shared TO base_mcp_dev;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO base_mcp_dev;

-- Set up default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA platform GRANT ALL ON TABLES TO base_mcp_dev;
ALTER DEFAULT PRIVILEGES IN SCHEMA shared GRANT ALL ON TABLES TO base_mcp_dev;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO base_mcp_dev;