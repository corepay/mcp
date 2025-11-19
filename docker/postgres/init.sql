-- PostgreSQL Extensions Initialization Script for MCP
-- This script enables all required extensions for the MCP platform

-- Enable TimescaleDB extension (comes pre-installed with timescaledb image)
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- Enable PostGIS for geospatial queries
CREATE EXTENSION IF NOT EXISTS postgis CASCADE;

-- Enable pgvector for AI/ML similarity search
CREATE EXTENSION IF NOT EXISTS vector CASCADE;

-- Enable Apache AGE for graph database capabilities
CREATE EXTENSION IF NOT EXISTS age CASCADE;

-- Load AGE extension
LOAD 'age';

-- Create schemas required by the application
CREATE SCHEMA IF NOT EXISTS platform;
CREATE SCHEMA IF NOT EXISTS shared;

-- Set default search path
ALTER DATABASE base_mcp_dev SET search_path TO platform, shared, public;

-- Grant permissions to the development user
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE base_mcp_dev TO base_mcp_dev;
GRANT ALL PRIVILEGES ON ALL TABLES IN ALL SCHEMAS TO base_mcp_dev;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN ALL SCHEMAS TO base_mcp_dev;

-- Set up default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA platform GRANT ALL ON TABLES TO base_mcp_dev;
ALTER DEFAULT PRIVILEGES IN SCHEMA shared GRANT ALL ON TABLES TO base_mcp_dev;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO base_mcp_dev;