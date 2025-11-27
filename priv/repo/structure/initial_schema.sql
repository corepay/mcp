--
-- PostgreSQL database dump
--


-- Dumped from database version 17.7 (Debian 17.7-3.pgdg13+1)
-- Dumped by pg_dump version 17.7 (Debian 17.7-3.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: ag_catalog; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA ag_catalog;


--
-- Name: finance; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA finance;


--
-- Name: platform; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA platform;


--
-- Name: shared; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA shared;


--
-- Name: age; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS age WITH SCHEMA ag_catalog;


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA platform;


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA platform;


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA platform;


--
-- Name: oban_job_state; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oban_job_state AS ENUM (
    'available',
    'scheduled',
    'executing',
    'retryable',
    'completed',
    'discarded',
    'cancelled'
);


--
-- Name: create_tenant_schema(text); Type: FUNCTION; Schema: ag_catalog; Owner: -
--

CREATE FUNCTION ag_catalog.create_tenant_schema(tenant_schema_name text) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: aggregate_hourly_metrics(); Type: FUNCTION; Schema: platform; Owner: -
--

CREATE FUNCTION platform.aggregate_hourly_metrics() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    -- This would be called by a scheduled job to aggregate hourly data
    -- For now, it's a placeholder that can be called manually
    RETURN NEW;
  END;
  $$;


--
-- Name: calculate_retention_expires(integer); Type: FUNCTION; Schema: platform; Owner: -
--

CREATE FUNCTION platform.calculate_retention_expires(retention_days integer) RETURNS timestamp with time zone
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN NOW() + (retention_days || ' days')::INTERVAL;
END;
$$;


--
-- Name: create_tenant_schema(text); Type: FUNCTION; Schema: platform; Owner: -
--

CREATE FUNCTION platform.create_tenant_schema(tenant_slug text) RETURNS void
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


--
-- Name: drop_tenant_schema(text); Type: FUNCTION; Schema: platform; Owner: -
--

CREATE FUNCTION platform.drop_tenant_schema(tenant_slug text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  schema_name TEXT := 'acq_' || tenant_slug;
BEGIN
  EXECUTE format('DROP SCHEMA IF EXISTS %I CASCADE', schema_name);
END;
$$;


--
-- Name: ensure_tenant_settings_schema(uuid); Type: FUNCTION; Schema: platform; Owner: -
--

CREATE FUNCTION platform.ensure_tenant_settings_schema(tenant_uuid uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    schema_name TEXT;
BEGIN
    -- Get schema name from tenants table
    SELECT company_schema INTO schema_name
    FROM platform.tenants
    WHERE id = tenant_uuid;

    -- Create schema if it doesn't exist
    IF schema_name IS NOT NULL THEN
        EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_name);

        -- Grant permissions if role exists
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mcp_app') THEN
            EXECUTE format('GRANT USAGE ON SCHEMA %I TO mcp_app', schema_name);
            EXECUTE format('GRANT CREATE ON SCHEMA %I TO mcp_app', schema_name);
        END IF;

        -- Create tenant settings table in the schema if it doesn't exist
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I.tenant_settings (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                category TEXT NOT NULL,
                key TEXT NOT NULL,
                value JSONB,
                value_type TEXT DEFAULT ''string'',
                encrypted BOOLEAN DEFAULT false,
                public BOOLEAN DEFAULT false,
                validation_rules JSONB DEFAULT ''{}'',
                description TEXT,
                last_updated_by UUID,
                inserted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                UNIQUE(category, key)
            )', schema_name);

        -- Create indexes in tenant schema
        EXECUTE format('CREATE INDEX IF NOT EXISTS idx_tenant_settings_category ON %I.tenant_settings (category)', schema_name);
        EXECUTE format('CREATE INDEX IF NOT EXISTS idx_tenant_settings_public ON %I.tenant_settings (public)', schema_name);
    END IF;
END;
$$;


--
-- Name: metric_aggregates(uuid, character varying, timestamp with time zone, timestamp with time zone, interval); Type: FUNCTION; Schema: platform; Owner: -
--

CREATE FUNCTION platform.metric_aggregates(p_tenant_id uuid, p_metric_key character varying, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_interval interval DEFAULT '01:00:00'::interval) RETURNS TABLE(time_bucket timestamp with time zone, count bigint, sum_val numeric, avg_val numeric, min_val numeric, max_val numeric)
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RETURN QUERY
    SELECT
      date_trunc('hour', analytics_metrics.recorded_at + p_interval) as time_bucket,
      COUNT(*) as count,
      SUM(analytics_metrics.value) as sum_val,
      AVG(analytics_metrics.value) as avg_val,
      MIN(analytics_metrics.value) as min_val,
      MAX(analytics_metrics.value) as max_val
    FROM analytics_metrics
    WHERE analytics_metrics.tenant_id = p_tenant_id
      AND analytics_metrics.metric_key = p_metric_key
      AND analytics_metrics.recorded_at >= p_start_time
      AND analytics_metrics.recorded_at <= p_end_time
    GROUP BY date_trunc('hour', analytics_metrics.recorded_at + p_interval)
    ORDER BY time_bucket;
  END;
  $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: users; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email public.citext NOT NULL,
    hashed_password text NOT NULL,
    totp_secret text,
    backup_codes text[],
    confirmed_at timestamp(0) without time zone,
    oauth_tokens jsonb DEFAULT '{}'::jsonb,
    last_sign_in_at timestamp(0) without time zone,
    last_sign_in_ip inet,
    sign_in_count integer DEFAULT 0,
    status text DEFAULT 'active'::text NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    failed_attempts integer DEFAULT 0 NOT NULL,
    locked_at timestamp(0) without time zone,
    unlock_token text,
    unlock_token_expires_at timestamp(0) without time zone,
    password_change_required boolean DEFAULT false NOT NULL,
    gdpr_deletion_requested_at timestamp(0) without time zone,
    gdpr_deletion_reason text,
    gdpr_retention_expires_at timestamp(0) without time zone,
    gdpr_anonymized_at timestamp(0) without time zone,
    gdpr_data_export_token uuid,
    gdpr_last_exported_at timestamp(0) without time zone,
    gdpr_consent_record jsonb DEFAULT '{}'::jsonb,
    gdpr_marketing_consent boolean DEFAULT false,
    gdpr_analytics_consent boolean DEFAULT false,
    gdpr_deletion_request_ip inet,
    gdpr_deletion_request_user_agent text,
    deleted_at timestamp(6) without time zone,
    deletion_reason text,
    anonymized_at timestamp(6) without time zone,
    CONSTRAINT users_status_check CHECK ((status = ANY (ARRAY['active'::text, 'suspended'::text, 'deletion_requested'::text, 'deleted'::text, 'anonymized'::text, 'purged'::text])))
);


--
-- Name: should_anonymize_user(platform.users); Type: FUNCTION; Schema: platform; Owner: -
--

CREATE FUNCTION platform.should_anonymize_user(user_record platform.users) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN (
    user_record.status = 'deleted' AND
    user_record.gdpr_retention_expires_at IS NOT NULL AND
    user_record.gdpr_retention_expires_at < NOW()
  );
END;
$$;


--
-- Name: tenant_schema_exists(text); Type: FUNCTION; Schema: platform; Owner: -
--

CREATE FUNCTION platform.tenant_schema_exists(tenant_slug text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  schema_name TEXT := 'acq_' || tenant_slug;
  schema_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.schemata
    WHERE schema_name = schema_name
  ) INTO schema_exists;

  RETURN schema_exists;
END;
$$;


--
-- Name: trigger_tenant_settings_schema(); Type: FUNCTION; Schema: platform; Owner: -
--

CREATE FUNCTION platform.trigger_tenant_settings_schema() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM ensure_tenant_settings_schema(NEW.id);
    RETURN NEW;
END;
$$;


--
-- Name: update_consent_records(); Type: FUNCTION; Schema: platform; Owner: -
--

CREATE FUNCTION platform.update_consent_records() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- When a new consent is granted, revoke previous ones of the same type
  IF NEW.granted = true AND NEW.is_current = true THEN
    UPDATE platform.gdpr_consent_records
    SET is_current = false, revoked_at = NOW()
    WHERE user_id = NEW.user_id
      AND consent_type = NEW.consent_type
      AND is_current = true
      AND id != NEW.id;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: accounts; Type: TABLE; Schema: finance; Owner: -
--

CREATE TABLE finance.accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    identifier text NOT NULL,
    type text NOT NULL,
    balance numeric DEFAULT 0 NOT NULL,
    currency text NOT NULL,
    tenant_id uuid,
    merchant_id uuid,
    mid_id uuid,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: balances; Type: TABLE; Schema: finance; Owner: -
--

CREATE TABLE finance.balances (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    balance numeric NOT NULL,
    currency text NOT NULL,
    account_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: transfers; Type: TABLE; Schema: finance; Owner: -
--

CREATE TABLE finance.transfers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    amount numeric NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    from_account_id uuid NOT NULL,
    to_account_id uuid NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
PARTITION BY RANGE (inserted_at);


--
-- Name: transfers_default; Type: TABLE; Schema: finance; Owner: -
--

CREATE TABLE finance.transfers_default (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    amount numeric NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    from_account_id uuid NOT NULL,
    to_account_id uuid NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: transfers_p2025_11; Type: TABLE; Schema: finance; Owner: -
--

CREATE TABLE finance.transfers_p2025_11 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    amount numeric NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    from_account_id uuid NOT NULL,
    to_account_id uuid NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: transfers_p2025_12; Type: TABLE; Schema: finance; Owner: -
--

CREATE TABLE finance.transfers_p2025_12 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    amount numeric NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    from_account_id uuid NOT NULL,
    to_account_id uuid NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: address_types; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.address_types (
    value text NOT NULL,
    label text NOT NULL,
    description text,
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    created_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- Name: addresses; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.addresses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_type text NOT NULL,
    owner_id uuid NOT NULL,
    address_type text,
    label text,
    line1 text NOT NULL,
    line2 text,
    city text NOT NULL,
    state text,
    postal_code text NOT NULL,
    country text DEFAULT 'US'::text NOT NULL,
    is_verified boolean DEFAULT false,
    verified_at timestamp(0) without time zone,
    verification_method text,
    is_primary boolean DEFAULT false,
    notes text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: analytics_alerts; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.analytics_alerts (
    id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    metric_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(255),
    severity character varying(255) DEFAULT 'warning'::character varying,
    condition character varying(255) NOT NULL,
    threshold_value numeric,
    threshold_percentage numeric,
    evaluation_window character varying(255) DEFAULT '5m'::character varying,
    evaluation_interval integer DEFAULT 60,
    consecutive_violations integer DEFAULT 1,
    notification_config jsonb DEFAULT '{"channels": [], "escalation_rules": []}'::jsonb,
    status character varying(255) DEFAULT 'active'::character varying,
    is_enabled boolean DEFAULT true NOT NULL,
    is_triggered boolean DEFAULT false NOT NULL,
    last_triggered_at timestamp(0) without time zone,
    last_resolved_at timestamp(0) without time zone,
    trigger_count integer DEFAULT 0,
    tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: analytics_dashboards; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.analytics_dashboards (
    id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    description character varying(255),
    role character varying(255) NOT NULL,
    category character varying(255) NOT NULL,
    layout_config jsonb DEFAULT '{"grid": {"cols": 12, "rows": 8}}'::jsonb,
    refresh_interval integer DEFAULT 300,
    is_public boolean DEFAULT false NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    config jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: analytics_metrics; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.analytics_metrics (
    id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    category character varying(255) NOT NULL,
    metric_name character varying(255) NOT NULL,
    metric_key character varying(255) NOT NULL,
    metric_type character varying(255) NOT NULL,
    value numeric NOT NULL,
    unit character varying(255),
    tags jsonb DEFAULT '{}'::jsonb,
    source character varying(255) NOT NULL,
    recorded_at timestamp without time zone NOT NULL,
    aggregation_window character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: analytics_metrics_daily; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.analytics_metrics_daily (
    tenant_id uuid NOT NULL,
    category character varying(255) NOT NULL,
    metric_key character varying(255) NOT NULL,
    metric_type character varying(255) NOT NULL,
    time_bucket timestamp(0) without time zone NOT NULL,
    count_metrics bigint NOT NULL,
    sum_value numeric NOT NULL,
    avg_value numeric NOT NULL,
    min_value numeric,
    max_value numeric,
    first_value numeric,
    last_value numeric,
    stddev_value numeric,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: analytics_metrics_hourly; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.analytics_metrics_hourly (
    tenant_id uuid NOT NULL,
    category character varying(255) NOT NULL,
    metric_key character varying(255) NOT NULL,
    metric_type character varying(255) NOT NULL,
    time_bucket timestamp(0) without time zone NOT NULL,
    count_metrics bigint NOT NULL,
    sum_value numeric NOT NULL,
    avg_value numeric NOT NULL,
    min_value numeric,
    max_value numeric,
    first_value numeric,
    last_value numeric,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: analytics_reports; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.analytics_reports (
    id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    description character varying(255),
    category character varying(255) NOT NULL,
    report_type character varying(255) NOT NULL,
    data_sources jsonb[] DEFAULT ARRAY[]::jsonb[],
    template_config jsonb DEFAULT '{}'::jsonb,
    schedule_config jsonb,
    output_format character varying(255) DEFAULT 'pdf'::character varying,
    distribution_config jsonb DEFAULT '{"email": [], "webhook": []}'::jsonb,
    parameters jsonb DEFAULT '{}'::jsonb,
    status character varying(255) DEFAULT 'draft'::character varying,
    last_generated_at timestamp(0) without time zone,
    next_run_at timestamp(0) without time zone,
    is_public boolean DEFAULT false NOT NULL,
    tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: analytics_widgets; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.analytics_widgets (
    id uuid NOT NULL,
    dashboard_id uuid NOT NULL,
    widget_id character varying(255) NOT NULL,
    title character varying(255) NOT NULL,
    widget_type character varying(255) NOT NULL,
    data_source jsonb NOT NULL,
    visualization_config jsonb DEFAULT '{}'::jsonb,
    "position" jsonb DEFAULT '{"x": 0, "y": 0, "width": 3, "height": 2}'::jsonb,
    refresh_interval integer,
    filters jsonb DEFAULT '{}'::jsonb,
    drilldown_config jsonb,
    is_visible boolean DEFAULT true NOT NULL,
    is_collapsible boolean DEFAULT false NOT NULL,
    custom_css character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: api_keys; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.api_keys (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_type text NOT NULL,
    owner_id uuid NOT NULL,
    name text NOT NULL,
    key_prefix text NOT NULL,
    hashed_key text NOT NULL,
    scopes text[] DEFAULT ARRAY[]::text[],
    permissions jsonb DEFAULT '{}'::jsonb,
    last_used_at timestamp(0) without time zone,
    usage_count integer DEFAULT 0,
    rate_limit integer,
    daily_quota integer,
    monthly_quota integer,
    expires_at timestamp(0) without time zone,
    status text DEFAULT 'active'::text NOT NULL,
    allowed_ips text[],
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT api_keys_status_check CHECK ((status = ANY (ARRAY['active'::text, 'revoked'::text, 'expired'::text])))
);


--
-- Name: audit_logs; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_type text,
    actor_id uuid,
    target_type text,
    target_id uuid,
    action text NOT NULL,
    description text,
    changes jsonb DEFAULT '{}'::jsonb,
    ip_address inet,
    user_agent text,
    request_id text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- Name: auth_tokens; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.auth_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token text NOT NULL,
    type text NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    revoked_at timestamp without time zone,
    used_at timestamp without time zone,
    context jsonb DEFAULT '{}'::jsonb,
    device_info jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    jti character varying(255),
    session_id character varying(255),
    device_id character varying(255),
    last_used_at timestamp without time zone,
    CONSTRAINT auth_tokens_type_check CHECK ((type = ANY (ARRAY['access'::text, 'refresh'::text, 'reset'::text, 'verification'::text, 'session'::text, 'revoked_jwt'::text])))
);


--
-- Name: data_migration_logs; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.data_migration_logs (
    id uuid NOT NULL,
    migration_id uuid NOT NULL,
    log_level character varying(255) DEFAULT 'info'::character varying NOT NULL,
    message text NOT NULL,
    details jsonb DEFAULT '{}'::jsonb,
    batch_number integer,
    record_count integer,
    duration_ms integer,
    step_name character varying(255),
    source_table character varying(255),
    target_table character varying(255),
    error_type character varying(255),
    stack_trace text,
    context_data jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: data_migration_records; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.data_migration_records (
    id uuid NOT NULL,
    migration_id uuid NOT NULL,
    batch_number integer,
    record_index integer,
    source_table character varying(255),
    target_table character varying(255),
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    source_data jsonb DEFAULT '{}'::jsonb,
    target_data jsonb DEFAULT '{}'::jsonb,
    field_transformations jsonb DEFAULT '{}'::jsonb,
    validation_errors jsonb[] DEFAULT ARRAY[]::jsonb[],
    error_message text,
    error_type character varying(255),
    processing_time_ms integer,
    warnings character varying(255)[] DEFAULT ARRAY[]::character varying[],
    checksum character varying(255),
    source_record_id character varying(255),
    target_record_id character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: data_migrations; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.data_migrations (
    id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    migration_type character varying(255) NOT NULL,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    source_format character varying(255),
    target_format character varying(255),
    source_config jsonb DEFAULT '{}'::jsonb,
    target_config jsonb DEFAULT '{}'::jsonb,
    field_mappings jsonb DEFAULT '{}'::jsonb,
    validation_rules jsonb DEFAULT '{}'::jsonb,
    total_records integer DEFAULT 0 NOT NULL,
    processed_records integer DEFAULT 0 NOT NULL,
    failed_records integer DEFAULT 0 NOT NULL,
    progress_percentage double precision DEFAULT 0.0 NOT NULL,
    error_message text,
    error_details jsonb DEFAULT '{}'::jsonb,
    result_summary jsonb DEFAULT '{}'::jsonb,
    file_path character varying(255),
    backup_path character varying(255),
    started_at timestamp without time zone,
    completed_at timestamp without time zone,
    estimated_duration_minutes integer,
    priority character varying(255) DEFAULT 'normal'::character varying NOT NULL,
    batch_size integer DEFAULT 1000 NOT NULL,
    retry_count integer DEFAULT 0 NOT NULL,
    max_retries integer DEFAULT 3 NOT NULL,
    created_by uuid,
    tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: data_retention_schedule; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.data_retention_schedule (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    data_category text NOT NULL,
    retention_days integer NOT NULL,
    expires_at timestamp(0) without time zone NOT NULL,
    status text DEFAULT 'scheduled'::text,
    processing_started_at timestamp(0) without time zone,
    processing_completed_at timestamp(0) without time zone,
    retry_count integer DEFAULT 0,
    max_retries integer DEFAULT 3,
    error_details jsonb DEFAULT '{}'::jsonb,
    last_error_at timestamp(0) without time zone,
    oban_job_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT retry_count_check CHECK (((retry_count >= 0) AND (retry_count <= max_retries))),
    CONSTRAINT status_check CHECK ((status = ANY (ARRAY['scheduled'::text, 'processing'::text, 'processed'::text, 'failed'::text])))
);


--
-- Name: developer_tenants; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.developer_tenants (
    developer_id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    status text DEFAULT 'active'::text,
    permissions jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: developers; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.developers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    company_name text NOT NULL,
    contact_name text NOT NULL,
    contact_email text NOT NULL,
    contact_phone text,
    technical_contact_email text,
    admin_contact_email text,
    support_phone text,
    webhook_url text,
    webhook_secret text,
    webhook_events text[] DEFAULT ARRAY[]::text[],
    webhook_signing_secret text,
    app_type text DEFAULT 'public'::text,
    revenue_share_percentage numeric(5,2) DEFAULT 0.0,
    payout_settings jsonb DEFAULT '{}'::jsonb,
    api_quota_daily integer DEFAULT 1000,
    api_quota_monthly integer DEFAULT 10000,
    status text DEFAULT 'active'::text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: developers_versions; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.developers_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    version_action_type text NOT NULL,
    version_source_id uuid NOT NULL,
    changes jsonb,
    version_inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    version_updated_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL
);


--
-- Name: document_types; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.document_types (
    value text NOT NULL,
    label text NOT NULL,
    description text,
    is_sensitive boolean DEFAULT true,
    requires_encryption boolean DEFAULT true,
    retention_years integer,
    allowed_mime_types text[],
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    created_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- Name: documents; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_type text NOT NULL,
    owner_id uuid NOT NULL,
    document_type text,
    storage_provider text DEFAULT 's3'::text,
    storage_bucket text NOT NULL,
    storage_key text NOT NULL,
    encryption_key_id text,
    filename text NOT NULL,
    mime_type text NOT NULL,
    file_size integer NOT NULL,
    category text,
    tags text[],
    is_sensitive boolean DEFAULT true,
    requires_approval boolean DEFAULT false,
    approved_by uuid,
    approved_at timestamp(0) without time zone,
    retention_policy text,
    expires_at timestamp(0) without time zone,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: email_types; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.email_types (
    value text NOT NULL,
    label text NOT NULL,
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    created_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- Name: emails; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.emails (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_type text NOT NULL,
    owner_id uuid NOT NULL,
    email_type text,
    label text,
    email public.citext NOT NULL,
    is_verified boolean DEFAULT false,
    verified_at timestamp(0) without time zone,
    verification_token text,
    verification_sent_at timestamp(0) without time zone,
    is_primary boolean DEFAULT false,
    can_receive_marketing boolean DEFAULT false,
    can_receive_transactional boolean DEFAULT true,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: entity_types; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.entity_types (
    value text NOT NULL,
    label text NOT NULL,
    description text,
    category text,
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone DEFAULT now() NOT NULL,
    updated_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- Name: feature_toggles; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.feature_toggles (
    id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    feature character varying(255) NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    configuration jsonb DEFAULT '{}'::jsonb NOT NULL,
    restrictions jsonb DEFAULT '{}'::jsonb NOT NULL,
    enabled_by uuid,
    enabled_at timestamp without time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: gdpr_anonymization_records; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.gdpr_anonymization_records (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    table_name character varying(255) NOT NULL,
    column_name character varying(255) NOT NULL,
    original_value_hash character varying(255) NOT NULL,
    anonymization_strategy character varying(255) NOT NULL,
    reversible boolean DEFAULT false,
    salt character varying(255),
    anonymized_at timestamp without time zone NOT NULL,
    reversal_key character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: gdpr_audit_logs; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.gdpr_audit_logs (
    id uuid NOT NULL,
    user_id uuid,
    actor_id uuid,
    action character varying(255) NOT NULL,
    resource_type character varying(255),
    resource_id uuid,
    old_values jsonb,
    new_values jsonb,
    metadata jsonb,
    ip_address character varying(255),
    user_agent character varying(255),
    session_id character varying(255),
    request_id character varying(255),
    "timestamp" timestamp without time zone NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: gdpr_audit_trail; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.gdpr_audit_trail (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    action_type text NOT NULL,
    actor_type text,
    actor_id uuid,
    ip_address inet,
    user_agent text,
    request_id text,
    data_categories jsonb DEFAULT '[]'::jsonb,
    legal_basis text,
    retention_period_days integer,
    details jsonb DEFAULT '{}'::jsonb,
    processed_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT action_type_check CHECK ((action_type = ANY (ARRAY['access_request'::text, 'export_request'::text, 'delete_request'::text, 'anonymization'::text, 'data_export'::text, 'consent_granted'::text, 'consent_revoked'::text, 'account_restored'::text]))),
    CONSTRAINT actor_type_check CHECK ((actor_type = ANY (ARRAY['user'::text, 'system'::text, 'admin'::text])))
);


--
-- Name: gdpr_consent_records; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.gdpr_consent_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    consent_type text NOT NULL,
    granted boolean NOT NULL,
    legal_basis text NOT NULL,
    purpose text NOT NULL,
    data_categories jsonb DEFAULT '[]'::jsonb,
    granted_at timestamp(0) without time zone NOT NULL,
    revoked_at timestamp(0) without time zone,
    expires_at timestamp(0) without time zone,
    is_current boolean DEFAULT true,
    ip_address inet,
    user_agent text,
    request_id text,
    consent_form_version text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT consent_type_check CHECK ((consent_type = ANY (ARRAY['marketing'::text, 'analytics'::text, 'essential'::text, 'third_party'::text]))),
    CONSTRAINT legal_basis_check CHECK ((legal_basis = ANY (ARRAY['consent'::text, 'contract'::text, 'legal_obligation'::text, 'legitimate_interest'::text])))
);


--
-- Name: gdpr_consents; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.gdpr_consents (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    purpose character varying(255) NOT NULL,
    legal_basis character varying(255) NOT NULL,
    status character varying(255) DEFAULT 'active'::character varying NOT NULL,
    withdrawn_at timestamp without time zone,
    version integer DEFAULT 1,
    scope jsonb,
    valid_until timestamp without time zone,
    metadata jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: gdpr_data_export_requests; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.gdpr_data_export_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    export_token uuid NOT NULL,
    requested_format text DEFAULT 'json'::text,
    data_categories jsonb DEFAULT '[]'::jsonb,
    status text DEFAULT 'requested'::text,
    requested_at timestamp(0) without time zone NOT NULL,
    processing_started_at timestamp(0) without time zone,
    completed_at timestamp(0) without time zone,
    expires_at timestamp(0) without time zone NOT NULL,
    file_path text,
    file_size_bytes bigint,
    download_count integer DEFAULT 0,
    max_downloads integer DEFAULT 5,
    last_downloaded_at timestamp(0) without time zone,
    ip_address inet,
    user_agent text,
    request_id text,
    error_details jsonb DEFAULT '{}'::jsonb,
    oban_job_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT format_check CHECK ((requested_format = ANY (ARRAY['json'::text, 'csv'::text, 'pdf'::text]))),
    CONSTRAINT status_check CHECK ((status = ANY (ARRAY['requested'::text, 'processing'::text, 'completed'::text, 'expired'::text, 'failed'::text])))
);


--
-- Name: gdpr_exports; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.gdpr_exports (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    request_id uuid NOT NULL,
    format character varying(255) NOT NULL,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    file_path character varying(255),
    file_size integer,
    download_count integer DEFAULT 0,
    max_downloads integer DEFAULT 3,
    expires_at timestamp without time zone NOT NULL,
    metadata jsonb,
    error_message text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: gdpr_legal_holds; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.gdpr_legal_holds (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    case_reference character varying(255) NOT NULL,
    reason text,
    status character varying(255) DEFAULT 'active'::character varying NOT NULL,
    placed_by uuid NOT NULL,
    released_by uuid,
    released_at timestamp without time zone,
    scope jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: gdpr_requests; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.gdpr_requests (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    type character varying(255) NOT NULL,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    reason character varying(255),
    actor_id uuid,
    data jsonb,
    expires_at timestamp without time zone,
    completed_at timestamp without time zone,
    error_message text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: gdpr_retention_policies; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.gdpr_retention_policies (
    id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    entity_type character varying(255) NOT NULL,
    retention_days integer DEFAULT 365 NOT NULL,
    action character varying(255) DEFAULT 'anonymize'::character varying NOT NULL,
    legal_hold boolean DEFAULT false,
    legal_hold_reason character varying(255),
    legal_hold_until timestamp without time zone,
    conditions jsonb DEFAULT '{}'::jsonb,
    priority integer DEFAULT 100,
    active boolean DEFAULT true,
    description character varying(255),
    last_processed_at timestamp without time zone,
    processing_frequency_hours integer DEFAULT 24,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: gdpr_retention_schedules; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.gdpr_retention_schedules (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    data_category character varying(255) NOT NULL,
    retention_days integer NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    action character varying(255) NOT NULL,
    status character varying(255) DEFAULT 'scheduled'::character varying NOT NULL,
    priority character varying(255) DEFAULT 'normal'::character varying,
    legal_hold boolean DEFAULT false,
    processed_at timestamp without time zone,
    error_message text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: image_types; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.image_types (
    value text NOT NULL,
    label text NOT NULL,
    max_file_size integer,
    allowed_mime_types text[],
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    created_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- Name: images; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.images (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_type text NOT NULL,
    owner_id uuid NOT NULL,
    image_type text,
    storage_provider text DEFAULT 's3'::text,
    storage_bucket text NOT NULL,
    storage_key text NOT NULL,
    filename text NOT NULL,
    mime_type text NOT NULL,
    file_size integer NOT NULL,
    width integer,
    height integer,
    alt_text text,
    public_url text,
    is_public boolean DEFAULT false,
    is_processed boolean DEFAULT false,
    thumbnails jsonb DEFAULT '{}'::jsonb,
    sort_order integer DEFAULT 0,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: notes; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.notes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_type text NOT NULL,
    owner_id uuid NOT NULL,
    related_to_type text,
    related_to_id uuid,
    title text,
    content text NOT NULL,
    category text,
    tags text[],
    is_private boolean DEFAULT true,
    is_pinned boolean DEFAULT false,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: payment_charges; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.payment_charges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    amount bigint NOT NULL,
    currency text NOT NULL,
    status text DEFAULT 'pending'::text,
    provider text NOT NULL,
    provider_ref text,
    failure_reason text,
    captured_at timestamp without time zone,
    inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    updated_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    customer_id uuid,
    payment_method_id uuid
);


--
-- Name: payment_customers; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.payment_customers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    name text,
    phone text,
    provider_refs jsonb,
    inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    updated_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL
);


--
-- Name: payment_gateway_transactions; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.payment_gateway_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider text NOT NULL,
    provider_ref text,
    type text,
    amount bigint,
    currency text,
    status text,
    raw_response jsonb,
    inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    updated_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    charge_id uuid
);


--
-- Name: payment_gateways; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.payment_gateways (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    provider text NOT NULL,
    api_version text,
    supported_countries text[],
    supported_currencies text[],
    supported_payment_methods text[],
    supports_auth boolean DEFAULT true,
    supports_capture boolean DEFAULT true,
    supports_refund boolean DEFAULT true,
    supports_void boolean DEFAULT true,
    supports_recurring boolean DEFAULT false,
    supports_3ds boolean DEFAULT false,
    credentials jsonb DEFAULT '{}'::jsonb,
    fee_structure jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'active'::text NOT NULL,
    is_default boolean DEFAULT false,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone DEFAULT now() NOT NULL,
    updated_at timestamp(0) without time zone DEFAULT now() NOT NULL,
    CONSTRAINT payment_gateways_provider_check CHECK ((provider = ANY (ARRAY['stripe'::text, 'authorize_net'::text, 'braintree'::text, 'paypal'::text, 'square'::text, 'adyen'::text]))),
    CONSTRAINT payment_gateways_status_check CHECK ((status = ANY (ARRAY['active'::text, 'maintenance'::text, 'deprecated'::text])))
);


--
-- Name: payment_methods; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.payment_methods (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type text,
    provider text NOT NULL,
    provider_token text,
    last4 text,
    brand text,
    exp_month bigint,
    exp_year bigint,
    inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    updated_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    customer_id uuid,
    bank_name character varying(255),
    account_holder_name character varying(255),
    account_type character varying(255),
    last4_account character varying(255)
);


--
-- Name: payment_refunds; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.payment_refunds (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    amount bigint NOT NULL,
    currency text NOT NULL,
    status text DEFAULT 'pending'::text,
    provider_ref text,
    reason text,
    inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    updated_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    charge_id uuid
);


--
-- Name: phone_types; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.phone_types (
    value text NOT NULL,
    label text NOT NULL,
    is_active boolean DEFAULT true,
    supports_sms boolean DEFAULT false,
    sort_order integer DEFAULT 0,
    created_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- Name: phones; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.phones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_type text NOT NULL,
    owner_id uuid NOT NULL,
    phone_type text,
    label text,
    phone text NOT NULL,
    country_code text DEFAULT 'US'::text,
    extension text,
    is_verified boolean DEFAULT false,
    verified_at timestamp(0) without time zone,
    verification_code text,
    verification_sent_at timestamp(0) without time zone,
    can_sms boolean DEFAULT false,
    can_voice boolean DEFAULT true,
    is_primary boolean DEFAULT false,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: plan_types; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.plan_types (
    value text NOT NULL,
    label text NOT NULL,
    description text,
    features jsonb DEFAULT '{}'::jsonb,
    pricing jsonb DEFAULT '{}'::jsonb,
    limits jsonb DEFAULT '{}'::jsonb,
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    inserted_at timestamp(0) without time zone DEFAULT now() NOT NULL,
    updated_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- Name: recent_metrics; Type: VIEW; Schema: platform; Owner: -
--

CREATE VIEW platform.recent_metrics AS
 SELECT tenant_id,
    category,
    metric_key,
    metric_type,
    avg(value) AS avg_value,
    max(value) AS max_value,
    min(value) AS min_value,
    count(*) AS count,
    max(recorded_at) AS last_recorded_at
   FROM platform.analytics_metrics
  WHERE (recorded_at >= (now() - '24:00:00'::interval))
  GROUP BY tenant_id, category, metric_key, metric_type;


--
-- Name: registration_requests; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.registration_requests (
    id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    type character varying(255) DEFAULT 'customer'::character varying NOT NULL,
    email public.citext NOT NULL,
    first_name character varying(255),
    last_name character varying(255),
    phone character varying(255),
    company_name character varying(255),
    registration_data jsonb,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    submitted_at timestamp without time zone,
    approved_at timestamp without time zone,
    rejected_at timestamp without time zone,
    approved_by_id uuid,
    rejection_reason character varying(255),
    context jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: registration_settings; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.registration_settings (
    id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    customer_registration_enabled boolean DEFAULT false NOT NULL,
    vendor_registration_enabled boolean DEFAULT false NOT NULL,
    customer_approval_required boolean DEFAULT false NOT NULL,
    vendor_approval_required boolean DEFAULT true NOT NULL,
    email_verification_required boolean DEFAULT true NOT NULL,
    business_verification_required boolean DEFAULT false NOT NULL,
    phone_verification_required boolean DEFAULT false NOT NULL,
    auto_approve_customers boolean DEFAULT true NOT NULL,
    auto_approve_vendors boolean DEFAULT false NOT NULL,
    registration_rate_limit integer DEFAULT 5 NOT NULL,
    approval_timeout_hours integer DEFAULT 72 NOT NULL,
    email_verification_timeout_hours integer DEFAULT 24 NOT NULL,
    password_min_length integer DEFAULT 8 NOT NULL,
    password_require_uppercase boolean DEFAULT true NOT NULL,
    password_require_lowercase boolean DEFAULT true NOT NULL,
    password_require_numbers boolean DEFAULT true NOT NULL,
    password_require_symbols boolean DEFAULT true NOT NULL,
    allowed_email_domains character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    blocked_email_domains character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    allowed_countries character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    blocked_countries character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    welcome_email_template character varying(255) DEFAULT 'welcome_customer'::character varying NOT NULL,
    verification_email_template character varying(255) DEFAULT 'email_verification'::character varying NOT NULL,
    approval_email_template character varying(255) DEFAULT 'registration_approved'::character varying NOT NULL,
    rejection_email_template character varying(255) DEFAULT 'registration_rejected'::character varying NOT NULL,
    custom_welcome_message text,
    terms_of_service_url character varying(255),
    privacy_policy_url character varying(255),
    gdpr_compliance_enabled boolean DEFAULT true NOT NULL,
    require_consent_for_marketing boolean DEFAULT true NOT NULL,
    require_consent_for_analytics boolean DEFAULT false NOT NULL,
    data_retention_days integer DEFAULT 365 NOT NULL,
    fraud_detection_enabled boolean DEFAULT true NOT NULL,
    fraud_score_threshold integer DEFAULT 50 NOT NULL,
    max_registrations_per_domain integer DEFAULT 10 NOT NULL,
    require_captcha boolean DEFAULT true NOT NULL,
    captcha_provider character varying(255) DEFAULT 'recaptcha'::character varying NOT NULL,
    notification_webhook_url character varying(255),
    webhook_secret character varying(255),
    custom_fields jsonb DEFAULT '{}'::jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: reseller_tenants; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.reseller_tenants (
    reseller_id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    status text DEFAULT 'active'::text,
    contract_details jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: resellers; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.resellers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    slug text NOT NULL,
    company_name text NOT NULL,
    subdomain text NOT NULL,
    custom_domain text,
    contact_name text NOT NULL,
    contact_email text NOT NULL,
    contact_phone text,
    developer_id uuid,
    commission_rate numeric(5,2) DEFAULT 0.0,
    revenue_share_model jsonb DEFAULT '{}'::jsonb,
    banking_info jsonb DEFAULT '{}'::jsonb,
    tax_id text,
    contract_start_date date,
    contract_end_date date,
    support_tier text DEFAULT 'standard'::text,
    branding jsonb DEFAULT '{}'::jsonb,
    settings jsonb DEFAULT '{}'::jsonb,
    max_merchants integer DEFAULT 50,
    status text DEFAULT 'active'::text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: resellers_versions; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.resellers_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    version_action_type text NOT NULL,
    version_source_id uuid NOT NULL,
    changes jsonb,
    version_inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    version_updated_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: social_platforms; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.social_platforms (
    value text NOT NULL,
    label text NOT NULL,
    icon text,
    url_pattern text,
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    created_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- Name: socials; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.socials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_type text NOT NULL,
    owner_id uuid NOT NULL,
    platform text NOT NULL,
    username text NOT NULL,
    url text NOT NULL,
    is_verified boolean DEFAULT false,
    verified_at timestamp(0) without time zone,
    is_public boolean DEFAULT true,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: status_types; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.status_types (
    value text NOT NULL,
    label text NOT NULL,
    category text,
    color text,
    is_final boolean DEFAULT false,
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    created_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- Name: team_members; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.team_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    team_id uuid NOT NULL,
    user_profile_id uuid NOT NULL,
    role text DEFAULT 'member'::text NOT NULL,
    permissions jsonb DEFAULT '{}'::jsonb,
    invited_by uuid,
    joined_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT team_members_role_check CHECK ((role = ANY (ARRAY['owner'::text, 'admin'::text, 'member'::text, 'viewer'::text])))
);


--
-- Name: teams; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.teams (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    description text,
    settings jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'active'::text NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT teams_status_check CHECK ((status = ANY (ARRAY['active'::text, 'archived'::text])))
);


--
-- Name: tenant_branding; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.tenant_branding (
    id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    logo_url character varying(255),
    logo_dark_url character varying(255),
    favicon_url character varying(255),
    primary_color character varying(255),
    secondary_color character varying(255),
    accent_color character varying(255),
    background_color character varying(255),
    text_color character varying(255),
    font_family character varying(255),
    theme character varying(255) DEFAULT 'light'::character varying NOT NULL,
    custom_css text,
    brand_assets jsonb DEFAULT '{}'::jsonb NOT NULL,
    email_template_branding jsonb DEFAULT '{}'::jsonb NOT NULL,
    mobile_branding jsonb DEFAULT '{}'::jsonb NOT NULL,
    portal_branding jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by uuid,
    updated_by uuid,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: tenant_settings; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.tenant_settings (
    id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    category character varying(255) NOT NULL,
    key character varying(255) NOT NULL,
    value jsonb,
    value_type character varying(255) DEFAULT 'string'::character varying NOT NULL,
    encrypted boolean DEFAULT false NOT NULL,
    public boolean DEFAULT false NOT NULL,
    validation_rules jsonb DEFAULT '{}'::jsonb NOT NULL,
    description character varying(255),
    last_updated_by uuid,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: tenant_table_templates; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.tenant_table_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text NOT NULL,
    create_sql text NOT NULL,
    description text,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: tenants; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.tenants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    name text NOT NULL,
    company_schema text NOT NULL,
    subdomain text NOT NULL,
    custom_domain text,
    plan text DEFAULT 'starter'::text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    trial_ends_at timestamp(0) without time zone,
    subscription_id text,
    settings jsonb DEFAULT '{}'::jsonb,
    branding jsonb DEFAULT '{}'::jsonb,
    assigned_gateway_ids uuid[] DEFAULT ARRAY[]::uuid[],
    max_developers integer DEFAULT 5,
    max_resellers integer DEFAULT 10,
    max_merchants integer DEFAULT 100,
    onboarding_completed_at timestamp(0) without time zone,
    onboarding_step text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT tenants_plan_check CHECK ((plan = ANY (ARRAY['starter'::text, 'professional'::text, 'enterprise'::text]))),
    CONSTRAINT tenants_slug_check CHECK ((slug ~ '^[a-z0-9-]+$'::text)),
    CONSTRAINT tenants_status_check CHECK ((status = ANY (ARRAY['active'::text, 'trial'::text, 'suspended'::text, 'canceled'::text, 'deleted'::text]))),
    CONSTRAINT tenants_subdomain_check CHECK ((subdomain ~ '^[a-z0-9-]+$'::text))
);


--
-- Name: todos; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.todos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_type text NOT NULL,
    owner_id uuid NOT NULL,
    related_to_type text,
    related_to_id uuid,
    title text NOT NULL,
    description text,
    status text DEFAULT 'pending'::text,
    priority text DEFAULT 'medium'::text,
    due_at timestamp(0) without time zone,
    completed_at timestamp(0) without time zone,
    assigned_to uuid,
    tags text[],
    checklist jsonb DEFAULT '[]'::jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: user_profiles; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.user_profiles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    nickname text,
    avatar_url text,
    bio text,
    title text,
    phone text,
    contact_email text,
    timezone text DEFAULT 'UTC'::text,
    preferences jsonb DEFAULT '{}'::jsonb,
    is_admin boolean DEFAULT false,
    is_developer boolean DEFAULT false,
    status text DEFAULT 'active'::text NOT NULL,
    invited_by uuid,
    invitation_token text,
    invitation_sent_at timestamp(0) without time zone,
    invitation_expires_at timestamp(0) without time zone,
    joined_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT user_profiles_bio_length_check CHECK ((length(bio) <= 1000)),
    CONSTRAINT user_profiles_entity_type_check CHECK ((entity_type = ANY (ARRAY['platform'::text, 'tenant'::text, 'developer'::text, 'reseller'::text, 'merchant'::text, 'store'::text]))),
    CONSTRAINT user_profiles_status_check CHECK ((status = ANY (ARRAY['active'::text, 'suspended'::text, 'invited'::text, 'pending'::text])))
);


--
-- Name: oban_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oban_jobs (
    id bigint NOT NULL,
    state public.oban_job_state DEFAULT 'available'::public.oban_job_state NOT NULL,
    queue text DEFAULT 'default'::text NOT NULL,
    worker text NOT NULL,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    errors jsonb[] DEFAULT ARRAY[]::jsonb[] NOT NULL,
    attempt integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 20 NOT NULL,
    inserted_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    scheduled_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    attempted_at timestamp without time zone,
    completed_at timestamp without time zone,
    attempted_by text[],
    discarded_at timestamp without time zone,
    priority integer DEFAULT 0 NOT NULL,
    tags text[] DEFAULT ARRAY[]::text[],
    meta jsonb DEFAULT '{}'::jsonb,
    cancelled_at timestamp without time zone,
    CONSTRAINT attempt_range CHECK (((attempt >= 0) AND (attempt <= max_attempts))),
    CONSTRAINT positive_max_attempts CHECK ((max_attempts > 0)),
    CONSTRAINT queue_length CHECK (((char_length(queue) > 0) AND (char_length(queue) < 128))),
    CONSTRAINT worker_length CHECK (((char_length(worker) > 0) AND (char_length(worker) < 128)))
);


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oban_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oban_jobs_id_seq OWNED BY public.oban_jobs.id;


--
-- Name: oban_peers; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.oban_peers (
    name text NOT NULL,
    node text NOT NULL,
    started_at timestamp without time zone NOT NULL,
    expires_at timestamp without time zone NOT NULL
);


--
-- Name: transfers_default; Type: TABLE ATTACH; Schema: finance; Owner: -
--

ALTER TABLE ONLY finance.transfers ATTACH PARTITION finance.transfers_default DEFAULT;


--
-- Name: transfers_p2025_11; Type: TABLE ATTACH; Schema: finance; Owner: -
--

ALTER TABLE ONLY finance.transfers ATTACH PARTITION finance.transfers_p2025_11 FOR VALUES FROM ('2025-11-01 00:00:00') TO ('2025-12-01 00:00:00');


--
-- Name: transfers_p2025_12; Type: TABLE ATTACH; Schema: finance; Owner: -
--

ALTER TABLE ONLY finance.transfers ATTACH PARTITION finance.transfers_p2025_12 FOR VALUES FROM ('2025-12-01 00:00:00') TO ('2026-01-01 00:00:00');


--
-- Name: oban_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_jobs ALTER COLUMN id SET DEFAULT nextval('public.oban_jobs_id_seq'::regclass);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: finance; Owner: -
--

ALTER TABLE ONLY finance.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: balances balances_pkey; Type: CONSTRAINT; Schema: finance; Owner: -
--

ALTER TABLE ONLY finance.balances
    ADD CONSTRAINT balances_pkey PRIMARY KEY (id);


--
-- Name: transfers transfers_pkey; Type: CONSTRAINT; Schema: finance; Owner: -
--

ALTER TABLE ONLY finance.transfers
    ADD CONSTRAINT transfers_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: transfers_default transfers_default_pkey; Type: CONSTRAINT; Schema: finance; Owner: -
--

ALTER TABLE ONLY finance.transfers_default
    ADD CONSTRAINT transfers_default_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: transfers_p2025_11 transfers_p2025_11_pkey; Type: CONSTRAINT; Schema: finance; Owner: -
--

ALTER TABLE ONLY finance.transfers_p2025_11
    ADD CONSTRAINT transfers_p2025_11_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: transfers_p2025_12 transfers_p2025_12_pkey; Type: CONSTRAINT; Schema: finance; Owner: -
--

ALTER TABLE ONLY finance.transfers_p2025_12
    ADD CONSTRAINT transfers_p2025_12_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: address_types address_types_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.address_types
    ADD CONSTRAINT address_types_pkey PRIMARY KEY (value);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: analytics_alerts analytics_alerts_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.analytics_alerts
    ADD CONSTRAINT analytics_alerts_pkey PRIMARY KEY (id);


--
-- Name: analytics_dashboards analytics_dashboards_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.analytics_dashboards
    ADD CONSTRAINT analytics_dashboards_pkey PRIMARY KEY (id);


--
-- Name: analytics_metrics analytics_metrics_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.analytics_metrics
    ADD CONSTRAINT analytics_metrics_pkey PRIMARY KEY (id);


--
-- Name: analytics_reports analytics_reports_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.analytics_reports
    ADD CONSTRAINT analytics_reports_pkey PRIMARY KEY (id);


--
-- Name: analytics_widgets analytics_widgets_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.analytics_widgets
    ADD CONSTRAINT analytics_widgets_pkey PRIMARY KEY (id);


--
-- Name: api_keys api_keys_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.api_keys
    ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: auth_tokens auth_tokens_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.auth_tokens
    ADD CONSTRAINT auth_tokens_pkey PRIMARY KEY (id);


--
-- Name: data_migration_logs data_migration_logs_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.data_migration_logs
    ADD CONSTRAINT data_migration_logs_pkey PRIMARY KEY (id);


--
-- Name: data_migration_records data_migration_records_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.data_migration_records
    ADD CONSTRAINT data_migration_records_pkey PRIMARY KEY (id);


--
-- Name: data_migrations data_migrations_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.data_migrations
    ADD CONSTRAINT data_migrations_pkey PRIMARY KEY (id);


--
-- Name: data_retention_schedule data_retention_schedule_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.data_retention_schedule
    ADD CONSTRAINT data_retention_schedule_pkey PRIMARY KEY (id);


--
-- Name: developer_tenants developer_tenants_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.developer_tenants
    ADD CONSTRAINT developer_tenants_pkey PRIMARY KEY (developer_id, tenant_id);


--
-- Name: developers developers_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.developers
    ADD CONSTRAINT developers_pkey PRIMARY KEY (id);


--
-- Name: developers_versions developers_versions_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.developers_versions
    ADD CONSTRAINT developers_versions_pkey PRIMARY KEY (id);


--
-- Name: document_types document_types_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.document_types
    ADD CONSTRAINT document_types_pkey PRIMARY KEY (value);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: email_types email_types_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.email_types
    ADD CONSTRAINT email_types_pkey PRIMARY KEY (value);


--
-- Name: emails emails_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.emails
    ADD CONSTRAINT emails_pkey PRIMARY KEY (id);


--
-- Name: entity_types entity_types_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.entity_types
    ADD CONSTRAINT entity_types_pkey PRIMARY KEY (value);


--
-- Name: feature_toggles feature_toggles_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.feature_toggles
    ADD CONSTRAINT feature_toggles_pkey PRIMARY KEY (id);


--
-- Name: gdpr_anonymization_records gdpr_anonymization_records_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.gdpr_anonymization_records
    ADD CONSTRAINT gdpr_anonymization_records_pkey PRIMARY KEY (id);


--
-- Name: gdpr_audit_logs gdpr_audit_logs_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.gdpr_audit_logs
    ADD CONSTRAINT gdpr_audit_logs_pkey PRIMARY KEY (id);


--
-- Name: gdpr_audit_trail gdpr_audit_trail_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.gdpr_audit_trail
    ADD CONSTRAINT gdpr_audit_trail_pkey PRIMARY KEY (id);


--
-- Name: gdpr_consent_records gdpr_consent_records_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.gdpr_consent_records
    ADD CONSTRAINT gdpr_consent_records_pkey PRIMARY KEY (id);


--
-- Name: gdpr_consents gdpr_consents_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.gdpr_consents
    ADD CONSTRAINT gdpr_consents_pkey PRIMARY KEY (id);


--
-- Name: gdpr_data_export_requests gdpr_data_export_requests_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.gdpr_data_export_requests
    ADD CONSTRAINT gdpr_data_export_requests_pkey PRIMARY KEY (id);


--
-- Name: gdpr_exports gdpr_exports_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.gdpr_exports
    ADD CONSTRAINT gdpr_exports_pkey PRIMARY KEY (id);


--
-- Name: gdpr_legal_holds gdpr_legal_holds_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.gdpr_legal_holds
    ADD CONSTRAINT gdpr_legal_holds_pkey PRIMARY KEY (id);


--
-- Name: gdpr_requests gdpr_requests_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.gdpr_requests
    ADD CONSTRAINT gdpr_requests_pkey PRIMARY KEY (id);


--
-- Name: gdpr_retention_policies gdpr_retention_policies_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.gdpr_retention_policies
    ADD CONSTRAINT gdpr_retention_policies_pkey PRIMARY KEY (id);


--
-- Name: gdpr_retention_schedules gdpr_retention_schedules_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.gdpr_retention_schedules
    ADD CONSTRAINT gdpr_retention_schedules_pkey PRIMARY KEY (id);


--
-- Name: image_types image_types_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.image_types
    ADD CONSTRAINT image_types_pkey PRIMARY KEY (value);


--
-- Name: images images_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.images
    ADD CONSTRAINT images_pkey PRIMARY KEY (id);


--
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


--
-- Name: payment_charges payment_charges_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.payment_charges
    ADD CONSTRAINT payment_charges_pkey PRIMARY KEY (id);


--
-- Name: payment_customers payment_customers_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.payment_customers
    ADD CONSTRAINT payment_customers_pkey PRIMARY KEY (id);


--
-- Name: payment_gateway_transactions payment_gateway_transactions_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.payment_gateway_transactions
    ADD CONSTRAINT payment_gateway_transactions_pkey PRIMARY KEY (id);


--
-- Name: payment_gateways payment_gateways_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.payment_gateways
    ADD CONSTRAINT payment_gateways_pkey PRIMARY KEY (id);


--
-- Name: payment_methods payment_methods_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.payment_methods
    ADD CONSTRAINT payment_methods_pkey PRIMARY KEY (id);


--
-- Name: payment_refunds payment_refunds_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.payment_refunds
    ADD CONSTRAINT payment_refunds_pkey PRIMARY KEY (id);


--
-- Name: phone_types phone_types_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.phone_types
    ADD CONSTRAINT phone_types_pkey PRIMARY KEY (value);


--
-- Name: phones phones_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.phones
    ADD CONSTRAINT phones_pkey PRIMARY KEY (id);


--
-- Name: plan_types plan_types_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.plan_types
    ADD CONSTRAINT plan_types_pkey PRIMARY KEY (value);


--
-- Name: registration_requests registration_requests_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.registration_requests
    ADD CONSTRAINT registration_requests_pkey PRIMARY KEY (id);


--
-- Name: registration_settings registration_settings_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.registration_settings
    ADD CONSTRAINT registration_settings_pkey PRIMARY KEY (id);


--
-- Name: reseller_tenants reseller_tenants_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.reseller_tenants
    ADD CONSTRAINT reseller_tenants_pkey PRIMARY KEY (reseller_id, tenant_id);


--
-- Name: resellers resellers_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.resellers
    ADD CONSTRAINT resellers_pkey PRIMARY KEY (id);


--
-- Name: resellers_versions resellers_versions_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.resellers_versions
    ADD CONSTRAINT resellers_versions_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: social_platforms social_platforms_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.social_platforms
    ADD CONSTRAINT social_platforms_pkey PRIMARY KEY (value);


--
-- Name: socials socials_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.socials
    ADD CONSTRAINT socials_pkey PRIMARY KEY (id);


--
-- Name: status_types status_types_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.status_types
    ADD CONSTRAINT status_types_pkey PRIMARY KEY (value);


--
-- Name: team_members team_members_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.team_members
    ADD CONSTRAINT team_members_pkey PRIMARY KEY (id);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: tenant_branding tenant_branding_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.tenant_branding
    ADD CONSTRAINT tenant_branding_pkey PRIMARY KEY (id);


--
-- Name: tenant_settings tenant_settings_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.tenant_settings
    ADD CONSTRAINT tenant_settings_pkey PRIMARY KEY (id);


--
-- Name: tenant_table_templates tenant_table_templates_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.tenant_table_templates
    ADD CONSTRAINT tenant_table_templates_pkey PRIMARY KEY (id);


--
-- Name: tenant_table_templates tenant_table_templates_table_name_key; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.tenant_table_templates
    ADD CONSTRAINT tenant_table_templates_table_name_key UNIQUE (table_name);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);


--
-- Name: todos todos_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.todos
    ADD CONSTRAINT todos_pkey PRIMARY KEY (id);


--
-- Name: user_profiles user_profiles_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: oban_jobs non_negative_priority; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.oban_jobs
    ADD CONSTRAINT non_negative_priority CHECK ((priority >= 0)) NOT VALID;


--
-- Name: oban_jobs oban_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_jobs
    ADD CONSTRAINT oban_jobs_pkey PRIMARY KEY (id);


--
-- Name: oban_peers oban_peers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_peers
    ADD CONSTRAINT oban_peers_pkey PRIMARY KEY (name);


--
-- Name: accounts_identifier_index; Type: INDEX; Schema: finance; Owner: -
--

CREATE UNIQUE INDEX accounts_identifier_index ON finance.accounts USING btree (identifier);


--
-- Name: accounts_merchant_id_index; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX accounts_merchant_id_index ON finance.accounts USING btree (merchant_id);


--
-- Name: accounts_mid_id_index; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX accounts_mid_id_index ON finance.accounts USING btree (mid_id);


--
-- Name: accounts_tenant_id_index; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX accounts_tenant_id_index ON finance.accounts USING btree (tenant_id);


--
-- Name: balances_account_id_index; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX balances_account_id_index ON finance.balances USING btree (account_id);


--
-- Name: transfers_from_account_id_index; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX transfers_from_account_id_index ON ONLY finance.transfers USING btree (from_account_id);


--
-- Name: transfers_default_from_account_id_idx; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX transfers_default_from_account_id_idx ON finance.transfers_default USING btree (from_account_id);


--
-- Name: transfers_inserted_at_index; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX transfers_inserted_at_index ON ONLY finance.transfers USING btree (inserted_at);


--
-- Name: transfers_default_inserted_at_idx; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX transfers_default_inserted_at_idx ON finance.transfers_default USING btree (inserted_at);


--
-- Name: transfers_to_account_id_index; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX transfers_to_account_id_index ON ONLY finance.transfers USING btree (to_account_id);


--
-- Name: transfers_default_to_account_id_idx; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX transfers_default_to_account_id_idx ON finance.transfers_default USING btree (to_account_id);


--
-- Name: transfers_p2025_11_from_account_id_idx; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX transfers_p2025_11_from_account_id_idx ON finance.transfers_p2025_11 USING btree (from_account_id);


--
-- Name: transfers_p2025_11_inserted_at_idx; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX transfers_p2025_11_inserted_at_idx ON finance.transfers_p2025_11 USING btree (inserted_at);


--
-- Name: transfers_p2025_11_to_account_id_idx; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX transfers_p2025_11_to_account_id_idx ON finance.transfers_p2025_11 USING btree (to_account_id);


--
-- Name: transfers_p2025_12_from_account_id_idx; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX transfers_p2025_12_from_account_id_idx ON finance.transfers_p2025_12 USING btree (from_account_id);


--
-- Name: transfers_p2025_12_inserted_at_idx; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX transfers_p2025_12_inserted_at_idx ON finance.transfers_p2025_12 USING btree (inserted_at);


--
-- Name: transfers_p2025_12_to_account_id_idx; Type: INDEX; Schema: finance; Owner: -
--

CREATE INDEX transfers_p2025_12_to_account_id_idx ON finance.transfers_p2025_12 USING btree (to_account_id);


--
-- Name: addresses_address_type_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX addresses_address_type_index ON platform.addresses USING btree (address_type);


--
-- Name: addresses_owner_type_owner_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX addresses_owner_type_owner_id_index ON platform.addresses USING btree (owner_type, owner_id);


--
-- Name: addresses_owner_type_owner_id_is_primary_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX addresses_owner_type_owner_id_is_primary_index ON platform.addresses USING btree (owner_type, owner_id, is_primary) WHERE (is_primary = true);


--
-- Name: analytics_alerts_metric_id_is_enabled_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_alerts_metric_id_is_enabled_index ON platform.analytics_alerts USING btree (metric_id, is_enabled);


--
-- Name: analytics_alerts_tenant_id_is_enabled_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_alerts_tenant_id_is_enabled_index ON platform.analytics_alerts USING btree (tenant_id, is_enabled);


--
-- Name: analytics_alerts_tenant_id_is_triggered_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_alerts_tenant_id_is_triggered_index ON platform.analytics_alerts USING btree (tenant_id, is_triggered);


--
-- Name: analytics_alerts_tenant_id_metric_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_alerts_tenant_id_metric_id_index ON platform.analytics_alerts USING btree (tenant_id, metric_id);


--
-- Name: analytics_alerts_tenant_id_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_alerts_tenant_id_status_index ON platform.analytics_alerts USING btree (tenant_id, status);


--
-- Name: analytics_dashboards_tenant_id_category_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_dashboards_tenant_id_category_index ON platform.analytics_dashboards USING btree (tenant_id, category);


--
-- Name: analytics_dashboards_tenant_id_is_default_role_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_dashboards_tenant_id_is_default_role_index ON platform.analytics_dashboards USING btree (tenant_id, is_default, role);


--
-- Name: analytics_dashboards_tenant_id_is_public_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_dashboards_tenant_id_is_public_index ON platform.analytics_dashboards USING btree (tenant_id, is_public);


--
-- Name: analytics_dashboards_tenant_id_role_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_dashboards_tenant_id_role_index ON platform.analytics_dashboards USING btree (tenant_id, role);


--
-- Name: analytics_dashboards_tenant_id_slug_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX analytics_dashboards_tenant_id_slug_index ON platform.analytics_dashboards USING btree (tenant_id, slug);


--
-- Name: analytics_metrics_daily_tenant_id_category_time_bucket_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_metrics_daily_tenant_id_category_time_bucket_index ON platform.analytics_metrics_daily USING btree (tenant_id, category, time_bucket);


--
-- Name: analytics_metrics_daily_tenant_id_metric_key_time_bucket_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_metrics_daily_tenant_id_metric_key_time_bucket_index ON platform.analytics_metrics_daily USING btree (tenant_id, metric_key, time_bucket);


--
-- Name: analytics_metrics_daily_tenant_id_time_bucket_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_metrics_daily_tenant_id_time_bucket_index ON platform.analytics_metrics_daily USING btree (tenant_id, time_bucket);


--
-- Name: analytics_metrics_hourly_tenant_id_category_time_bucket_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_metrics_hourly_tenant_id_category_time_bucket_index ON platform.analytics_metrics_hourly USING btree (tenant_id, category, time_bucket);


--
-- Name: analytics_metrics_hourly_tenant_id_metric_key_time_bucket_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_metrics_hourly_tenant_id_metric_key_time_bucket_index ON platform.analytics_metrics_hourly USING btree (tenant_id, metric_key, time_bucket);


--
-- Name: analytics_metrics_hourly_tenant_id_time_bucket_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_metrics_hourly_tenant_id_time_bucket_index ON platform.analytics_metrics_hourly USING btree (tenant_id, time_bucket);


--
-- Name: analytics_metrics_metric_key_recorded_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_metrics_metric_key_recorded_at_index ON platform.analytics_metrics USING btree (metric_key, recorded_at);


--
-- Name: analytics_metrics_source_recorded_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_metrics_source_recorded_at_index ON platform.analytics_metrics USING btree (source, recorded_at);


--
-- Name: analytics_metrics_tenant_id_category_recorded_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_metrics_tenant_id_category_recorded_at_index ON platform.analytics_metrics USING btree (tenant_id, category, recorded_at);


--
-- Name: analytics_metrics_tenant_id_metric_key_recorded_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_metrics_tenant_id_metric_key_recorded_at_index ON platform.analytics_metrics USING btree (tenant_id, metric_key, recorded_at);


--
-- Name: analytics_metrics_tenant_id_recorded_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_metrics_tenant_id_recorded_at_index ON platform.analytics_metrics USING btree (tenant_id, recorded_at);


--
-- Name: analytics_reports_tenant_id_next_run_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_reports_tenant_id_next_run_at_index ON platform.analytics_reports USING btree (tenant_id, next_run_at);


--
-- Name: analytics_reports_tenant_id_report_type_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_reports_tenant_id_report_type_index ON platform.analytics_reports USING btree (tenant_id, report_type);


--
-- Name: analytics_reports_tenant_id_slug_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX analytics_reports_tenant_id_slug_index ON platform.analytics_reports USING btree (tenant_id, slug);


--
-- Name: analytics_reports_tenant_id_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_reports_tenant_id_status_index ON platform.analytics_reports USING btree (tenant_id, status);


--
-- Name: analytics_widgets_dashboard_id_is_visible_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_widgets_dashboard_id_is_visible_index ON platform.analytics_widgets USING btree (dashboard_id, is_visible);


--
-- Name: analytics_widgets_dashboard_id_widget_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX analytics_widgets_dashboard_id_widget_id_index ON platform.analytics_widgets USING btree (dashboard_id, widget_id);


--
-- Name: analytics_widgets_dashboard_id_widget_type_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX analytics_widgets_dashboard_id_widget_type_index ON platform.analytics_widgets USING btree (dashboard_id, widget_type);


--
-- Name: api_keys_expires_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX api_keys_expires_at_index ON platform.api_keys USING btree (expires_at) WHERE (expires_at IS NOT NULL);


--
-- Name: api_keys_key_prefix_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX api_keys_key_prefix_index ON platform.api_keys USING btree (key_prefix);


--
-- Name: api_keys_owner_type_owner_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX api_keys_owner_type_owner_id_index ON platform.api_keys USING btree (owner_type, owner_id);


--
-- Name: api_keys_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX api_keys_status_index ON platform.api_keys USING btree (status);


--
-- Name: audit_logs_action_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX audit_logs_action_index ON platform.audit_logs USING btree (action);


--
-- Name: audit_logs_actor_type_actor_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX audit_logs_actor_type_actor_id_index ON platform.audit_logs USING btree (actor_type, actor_id);


--
-- Name: audit_logs_created_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX audit_logs_created_at_index ON platform.audit_logs USING btree (created_at);


--
-- Name: audit_logs_request_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX audit_logs_request_id_index ON platform.audit_logs USING btree (request_id);


--
-- Name: audit_logs_target_type_target_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX audit_logs_target_type_target_id_index ON platform.audit_logs USING btree (target_type, target_id);


--
-- Name: auth_tokens_device_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX auth_tokens_device_id_index ON platform.auth_tokens USING btree (device_id);


--
-- Name: auth_tokens_expires_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX auth_tokens_expires_at_index ON platform.auth_tokens USING btree (expires_at);


--
-- Name: auth_tokens_jti_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX auth_tokens_jti_index ON platform.auth_tokens USING btree (jti) WHERE (jti IS NOT NULL);


--
-- Name: auth_tokens_revoked_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX auth_tokens_revoked_at_index ON platform.auth_tokens USING btree (revoked_at);


--
-- Name: auth_tokens_session_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX auth_tokens_session_id_index ON platform.auth_tokens USING btree (session_id);


--
-- Name: auth_tokens_token_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX auth_tokens_token_index ON platform.auth_tokens USING btree (token);


--
-- Name: auth_tokens_type_expires_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX auth_tokens_type_expires_at_index ON platform.auth_tokens USING btree (type, expires_at);


--
-- Name: auth_tokens_type_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX auth_tokens_type_index ON platform.auth_tokens USING btree (type);


--
-- Name: auth_tokens_user_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX auth_tokens_user_id_index ON platform.auth_tokens USING btree (user_id);


--
-- Name: auth_tokens_user_id_type_revoked_at_expires_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX auth_tokens_user_id_type_revoked_at_expires_at_index ON platform.auth_tokens USING btree (user_id, type, revoked_at, expires_at);


--
-- Name: data_migration_logs_inserted_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_logs_inserted_at_index ON platform.data_migration_logs USING btree (inserted_at);


--
-- Name: data_migration_logs_log_level_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_logs_log_level_index ON platform.data_migration_logs USING btree (log_level);


--
-- Name: data_migration_logs_log_level_inserted_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_logs_log_level_inserted_at_index ON platform.data_migration_logs USING btree (log_level, inserted_at);


--
-- Name: data_migration_logs_migration_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_logs_migration_id_index ON platform.data_migration_logs USING btree (migration_id);


--
-- Name: data_migration_logs_migration_id_inserted_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_logs_migration_id_inserted_at_index ON platform.data_migration_logs USING btree (migration_id, inserted_at);


--
-- Name: data_migration_logs_migration_id_log_level_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_logs_migration_id_log_level_index ON platform.data_migration_logs USING btree (migration_id, log_level);


--
-- Name: data_migration_logs_migration_id_log_level_inserted_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_logs_migration_id_log_level_inserted_at_index ON platform.data_migration_logs USING btree (migration_id, log_level, inserted_at);


--
-- Name: data_migration_records_batch_number_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_records_batch_number_index ON platform.data_migration_records USING btree (batch_number);


--
-- Name: data_migration_records_inserted_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_records_inserted_at_index ON platform.data_migration_records USING btree (inserted_at);


--
-- Name: data_migration_records_migration_id_batch_number_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_records_migration_id_batch_number_index ON platform.data_migration_records USING btree (migration_id, batch_number);


--
-- Name: data_migration_records_migration_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_records_migration_id_index ON platform.data_migration_records USING btree (migration_id);


--
-- Name: data_migration_records_migration_id_status_batch_number_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_records_migration_id_status_batch_number_index ON platform.data_migration_records USING btree (migration_id, status, batch_number);


--
-- Name: data_migration_records_migration_id_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_records_migration_id_status_index ON platform.data_migration_records USING btree (migration_id, status);


--
-- Name: data_migration_records_migration_id_target_table_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_records_migration_id_target_table_status_index ON platform.data_migration_records USING btree (migration_id, target_table, status);


--
-- Name: data_migration_records_source_record_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_records_source_record_id_index ON platform.data_migration_records USING btree (source_record_id);


--
-- Name: data_migration_records_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_records_status_index ON platform.data_migration_records USING btree (status);


--
-- Name: data_migration_records_status_inserted_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_records_status_inserted_at_index ON platform.data_migration_records USING btree (status, inserted_at);


--
-- Name: data_migration_records_target_record_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_records_target_record_id_index ON platform.data_migration_records USING btree (target_record_id);


--
-- Name: data_migration_records_target_table_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migration_records_target_table_index ON platform.data_migration_records USING btree (target_table);


--
-- Name: data_migrations_inserted_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migrations_inserted_at_index ON platform.data_migrations USING btree (inserted_at);


--
-- Name: data_migrations_migration_type_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migrations_migration_type_index ON platform.data_migrations USING btree (migration_type);


--
-- Name: data_migrations_priority_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migrations_priority_index ON platform.data_migrations USING btree (priority);


--
-- Name: data_migrations_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migrations_status_index ON platform.data_migrations USING btree (status);


--
-- Name: data_migrations_status_inserted_at_priority_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migrations_status_inserted_at_priority_index ON platform.data_migrations USING btree (status, inserted_at, priority);


--
-- Name: data_migrations_status_priority_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migrations_status_priority_index ON platform.data_migrations USING btree (status, priority);


--
-- Name: data_migrations_tenant_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migrations_tenant_id_index ON platform.data_migrations USING btree (tenant_id);


--
-- Name: data_migrations_tenant_id_migration_type_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migrations_tenant_id_migration_type_status_index ON platform.data_migrations USING btree (tenant_id, migration_type, status);


--
-- Name: data_migrations_tenant_id_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_migrations_tenant_id_status_index ON platform.data_migrations USING btree (tenant_id, status);


--
-- Name: data_retention_schedule_data_category_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_retention_schedule_data_category_index ON platform.data_retention_schedule USING btree (data_category);


--
-- Name: data_retention_schedule_expires_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_retention_schedule_expires_at_index ON platform.data_retention_schedule USING btree (expires_at);


--
-- Name: data_retention_schedule_oban_job_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX data_retention_schedule_oban_job_id_index ON platform.data_retention_schedule USING btree (oban_job_id) WHERE (oban_job_id IS NOT NULL);


--
-- Name: data_retention_schedule_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_retention_schedule_status_index ON platform.data_retention_schedule USING btree (status);


--
-- Name: data_retention_schedule_user_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX data_retention_schedule_user_id_index ON platform.data_retention_schedule USING btree (user_id);


--
-- Name: developer_tenants_developer_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX developer_tenants_developer_id_index ON platform.developer_tenants USING btree (developer_id);


--
-- Name: developer_tenants_tenant_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX developer_tenants_tenant_id_index ON platform.developer_tenants USING btree (tenant_id);


--
-- Name: developers_contact_email_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX developers_contact_email_index ON platform.developers USING btree (contact_email);


--
-- Name: developers_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX developers_status_index ON platform.developers USING btree (status);


--
-- Name: developers_user_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX developers_user_id_index ON platform.developers USING btree (user_id);


--
-- Name: documents_document_type_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX documents_document_type_index ON platform.documents USING btree (document_type);


--
-- Name: documents_expires_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX documents_expires_at_index ON platform.documents USING btree (expires_at) WHERE (expires_at IS NOT NULL);


--
-- Name: documents_owner_type_owner_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX documents_owner_type_owner_id_index ON platform.documents USING btree (owner_type, owner_id);


--
-- Name: emails_email_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX emails_email_index ON platform.emails USING btree (email);


--
-- Name: emails_email_type_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX emails_email_type_index ON platform.emails USING btree (email_type);


--
-- Name: emails_owner_type_owner_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX emails_owner_type_owner_id_index ON platform.emails USING btree (owner_type, owner_id);


--
-- Name: emails_owner_type_owner_id_is_primary_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX emails_owner_type_owner_id_is_primary_index ON platform.emails USING btree (owner_type, owner_id, is_primary) WHERE (is_primary = true);


--
-- Name: entity_types_category_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX entity_types_category_index ON platform.entity_types USING btree (category);


--
-- Name: entity_types_is_active_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX entity_types_is_active_index ON platform.entity_types USING btree (is_active) WHERE (is_active = true);


--
-- Name: feature_toggles_feature_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX feature_toggles_feature_index ON platform.feature_toggles USING btree (feature);


--
-- Name: feature_toggles_tenant_id_enabled_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX feature_toggles_tenant_id_enabled_index ON platform.feature_toggles USING btree (tenant_id, enabled);


--
-- Name: feature_toggles_tenant_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX feature_toggles_tenant_id_index ON platform.feature_toggles USING btree (tenant_id);


--
-- Name: gdpr_anonymization_records_table_name_column_name_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_anonymization_records_table_name_column_name_index ON platform.gdpr_anonymization_records USING btree (table_name, column_name);


--
-- Name: gdpr_anonymization_records_user_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_anonymization_records_user_id_index ON platform.gdpr_anonymization_records USING btree (user_id);


--
-- Name: gdpr_audit_logs_action_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_audit_logs_action_index ON platform.gdpr_audit_logs USING btree (action);


--
-- Name: gdpr_audit_logs_actor_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_audit_logs_actor_id_index ON platform.gdpr_audit_logs USING btree (actor_id);


--
-- Name: gdpr_audit_logs_resource_type_resource_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_audit_logs_resource_type_resource_id_index ON platform.gdpr_audit_logs USING btree (resource_type, resource_id);


--
-- Name: gdpr_audit_logs_timestamp_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_audit_logs_timestamp_index ON platform.gdpr_audit_logs USING btree ("timestamp");


--
-- Name: gdpr_audit_logs_user_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_audit_logs_user_id_index ON platform.gdpr_audit_logs USING btree (user_id);


--
-- Name: gdpr_audit_trail_action_type_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_audit_trail_action_type_index ON platform.gdpr_audit_trail USING btree (action_type);


--
-- Name: gdpr_audit_trail_actor_type_actor_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_audit_trail_actor_type_actor_id_index ON platform.gdpr_audit_trail USING btree (actor_type, actor_id);


--
-- Name: gdpr_audit_trail_inserted_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_audit_trail_inserted_at_index ON platform.gdpr_audit_trail USING btree (inserted_at);


--
-- Name: gdpr_audit_trail_processed_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_audit_trail_processed_at_index ON platform.gdpr_audit_trail USING btree (processed_at);


--
-- Name: gdpr_audit_trail_user_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_audit_trail_user_id_index ON platform.gdpr_audit_trail USING btree (user_id);


--
-- Name: gdpr_consent_records_consent_type_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_consent_records_consent_type_index ON platform.gdpr_consent_records USING btree (consent_type);


--
-- Name: gdpr_consent_records_expires_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_consent_records_expires_at_index ON platform.gdpr_consent_records USING btree (expires_at);


--
-- Name: gdpr_consent_records_granted_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_consent_records_granted_at_index ON platform.gdpr_consent_records USING btree (granted_at);


--
-- Name: gdpr_consent_records_is_current_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_consent_records_is_current_index ON platform.gdpr_consent_records USING btree (is_current);


--
-- Name: gdpr_consent_records_user_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_consent_records_user_id_index ON platform.gdpr_consent_records USING btree (user_id);


--
-- Name: gdpr_consents_purpose_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_consents_purpose_status_index ON platform.gdpr_consents USING btree (purpose, status);


--
-- Name: gdpr_consents_user_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_consents_user_id_index ON platform.gdpr_consents USING btree (user_id);


--
-- Name: gdpr_consents_user_id_purpose_version_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX gdpr_consents_user_id_purpose_version_index ON platform.gdpr_consents USING btree (user_id, purpose, version);


--
-- Name: gdpr_data_export_requests_expires_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_data_export_requests_expires_at_index ON platform.gdpr_data_export_requests USING btree (expires_at);


--
-- Name: gdpr_data_export_requests_export_token_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX gdpr_data_export_requests_export_token_index ON platform.gdpr_data_export_requests USING btree (export_token);


--
-- Name: gdpr_data_export_requests_oban_job_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX gdpr_data_export_requests_oban_job_id_index ON platform.gdpr_data_export_requests USING btree (oban_job_id) WHERE (oban_job_id IS NOT NULL);


--
-- Name: gdpr_data_export_requests_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_data_export_requests_status_index ON platform.gdpr_data_export_requests USING btree (status);


--
-- Name: gdpr_data_export_requests_user_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_data_export_requests_user_id_index ON platform.gdpr_data_export_requests USING btree (user_id);


--
-- Name: gdpr_exports_request_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_exports_request_id_index ON platform.gdpr_exports USING btree (request_id);


--
-- Name: gdpr_exports_status_expires_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_exports_status_expires_at_index ON platform.gdpr_exports USING btree (status, expires_at);


--
-- Name: gdpr_exports_user_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_exports_user_id_index ON platform.gdpr_exports USING btree (user_id);


--
-- Name: gdpr_legal_holds_case_reference_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_legal_holds_case_reference_index ON platform.gdpr_legal_holds USING btree (case_reference);


--
-- Name: gdpr_legal_holds_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_legal_holds_status_index ON platform.gdpr_legal_holds USING btree (status);


--
-- Name: gdpr_legal_holds_user_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_legal_holds_user_id_index ON platform.gdpr_legal_holds USING btree (user_id);


--
-- Name: gdpr_requests_expires_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_requests_expires_at_index ON platform.gdpr_requests USING btree (expires_at);


--
-- Name: gdpr_requests_type_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_requests_type_status_index ON platform.gdpr_requests USING btree (type, status);


--
-- Name: gdpr_requests_user_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_requests_user_id_index ON platform.gdpr_requests USING btree (user_id);


--
-- Name: gdpr_retention_policies_active_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_retention_policies_active_index ON platform.gdpr_retention_policies USING btree (active);


--
-- Name: gdpr_retention_policies_active_legal_hold_last_processed_at_ind; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_retention_policies_active_legal_hold_last_processed_at_ind ON platform.gdpr_retention_policies USING btree (active, legal_hold, last_processed_at);


--
-- Name: gdpr_retention_policies_entity_type_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_retention_policies_entity_type_index ON platform.gdpr_retention_policies USING btree (entity_type);


--
-- Name: gdpr_retention_policies_last_processed_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_retention_policies_last_processed_at_index ON platform.gdpr_retention_policies USING btree (last_processed_at);


--
-- Name: gdpr_retention_policies_legal_hold_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_retention_policies_legal_hold_index ON platform.gdpr_retention_policies USING btree (legal_hold);


--
-- Name: gdpr_retention_policies_tenant_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_retention_policies_tenant_id_index ON platform.gdpr_retention_policies USING btree (tenant_id);


--
-- Name: gdpr_retention_schedules_expires_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_retention_schedules_expires_at_index ON platform.gdpr_retention_schedules USING btree (expires_at);


--
-- Name: gdpr_retention_schedules_status_priority_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_retention_schedules_status_priority_index ON platform.gdpr_retention_schedules USING btree (status, priority);


--
-- Name: gdpr_retention_schedules_user_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX gdpr_retention_schedules_user_id_index ON platform.gdpr_retention_schedules USING btree (user_id);


--
-- Name: idx_documents_tags; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX idx_documents_tags ON platform.documents USING gin (tags);


--
-- Name: idx_notes_content_search; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX idx_notes_content_search ON platform.notes USING gin (to_tsvector('english'::regconfig, content));


--
-- Name: idx_notes_tags; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX idx_notes_tags ON platform.notes USING gin (tags);


--
-- Name: images_image_type_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX images_image_type_index ON platform.images USING btree (image_type);


--
-- Name: images_is_public_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX images_is_public_index ON platform.images USING btree (is_public) WHERE (is_public = true);


--
-- Name: images_owner_type_owner_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX images_owner_type_owner_id_index ON platform.images USING btree (owner_type, owner_id);


--
-- Name: images_storage_provider_storage_bucket_storage_key_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX images_storage_provider_storage_bucket_storage_key_index ON platform.images USING btree (storage_provider, storage_bucket, storage_key);


--
-- Name: notes_is_pinned_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX notes_is_pinned_index ON platform.notes USING btree (is_pinned) WHERE (is_pinned = true);


--
-- Name: notes_owner_type_owner_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX notes_owner_type_owner_id_index ON platform.notes USING btree (owner_type, owner_id);


--
-- Name: notes_related_to_type_related_to_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX notes_related_to_type_related_to_id_index ON platform.notes USING btree (related_to_type, related_to_id);


--
-- Name: payment_gateways_is_default_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX payment_gateways_is_default_index ON platform.payment_gateways USING btree (is_default) WHERE (is_default = true);


--
-- Name: payment_gateways_provider_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX payment_gateways_provider_index ON platform.payment_gateways USING btree (provider);


--
-- Name: payment_gateways_slug_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX payment_gateways_slug_index ON platform.payment_gateways USING btree (slug);


--
-- Name: payment_gateways_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX payment_gateways_status_index ON platform.payment_gateways USING btree (status);


--
-- Name: phones_can_sms_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX phones_can_sms_index ON platform.phones USING btree (can_sms) WHERE (can_sms = true);


--
-- Name: phones_owner_type_owner_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX phones_owner_type_owner_id_index ON platform.phones USING btree (owner_type, owner_id);


--
-- Name: phones_phone_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX phones_phone_index ON platform.phones USING btree (phone);


--
-- Name: phones_phone_type_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX phones_phone_type_index ON platform.phones USING btree (phone_type);


--
-- Name: registration_requests_approved_by_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX registration_requests_approved_by_id_index ON platform.registration_requests USING btree (approved_by_id);


--
-- Name: registration_requests_email_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX registration_requests_email_index ON platform.registration_requests USING btree (email);


--
-- Name: registration_requests_status_inserted_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX registration_requests_status_inserted_at_index ON platform.registration_requests USING btree (status, inserted_at);


--
-- Name: registration_requests_tenant_id_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX registration_requests_tenant_id_status_index ON platform.registration_requests USING btree (tenant_id, status);


--
-- Name: registration_settings_tenant_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX registration_settings_tenant_id_index ON platform.registration_settings USING btree (tenant_id);


--
-- Name: reseller_tenants_reseller_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX reseller_tenants_reseller_id_index ON platform.reseller_tenants USING btree (reseller_id);


--
-- Name: reseller_tenants_tenant_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX reseller_tenants_tenant_id_index ON platform.reseller_tenants USING btree (tenant_id);


--
-- Name: resellers_custom_domain_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX resellers_custom_domain_index ON platform.resellers USING btree (custom_domain) WHERE (custom_domain IS NOT NULL);


--
-- Name: resellers_developer_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX resellers_developer_id_index ON platform.resellers USING btree (developer_id);


--
-- Name: resellers_slug_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX resellers_slug_index ON platform.resellers USING btree (slug);


--
-- Name: resellers_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX resellers_status_index ON platform.resellers USING btree (status);


--
-- Name: resellers_subdomain_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX resellers_subdomain_index ON platform.resellers USING btree (subdomain);


--
-- Name: resellers_user_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX resellers_user_id_index ON platform.resellers USING btree (user_id);


--
-- Name: socials_is_public_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX socials_is_public_index ON platform.socials USING btree (is_public) WHERE (is_public = true);


--
-- Name: socials_owner_type_owner_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX socials_owner_type_owner_id_index ON platform.socials USING btree (owner_type, owner_id);


--
-- Name: socials_owner_type_owner_id_platform_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX socials_owner_type_owner_id_platform_index ON platform.socials USING btree (owner_type, owner_id, platform);


--
-- Name: socials_platform_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX socials_platform_index ON platform.socials USING btree (platform);


--
-- Name: team_members_team_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX team_members_team_id_index ON platform.team_members USING btree (team_id);


--
-- Name: team_members_team_id_user_profile_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX team_members_team_id_user_profile_id_index ON platform.team_members USING btree (team_id, user_profile_id);


--
-- Name: team_members_user_profile_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX team_members_user_profile_id_index ON platform.team_members USING btree (user_profile_id);


--
-- Name: teams_entity_type_entity_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX teams_entity_type_entity_id_index ON platform.teams USING btree (entity_type, entity_id);


--
-- Name: teams_entity_type_entity_id_slug_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX teams_entity_type_entity_id_slug_index ON platform.teams USING btree (entity_type, entity_id, slug);


--
-- Name: teams_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX teams_status_index ON platform.teams USING btree (status);


--
-- Name: tenant_branding_tenant_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX tenant_branding_tenant_id_index ON platform.tenant_branding USING btree (tenant_id);


--
-- Name: tenant_branding_tenant_id_is_active_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX tenant_branding_tenant_id_is_active_index ON platform.tenant_branding USING btree (tenant_id, is_active);


--
-- Name: tenant_settings_tenant_id_category_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX tenant_settings_tenant_id_category_index ON platform.tenant_settings USING btree (tenant_id, category);


--
-- Name: tenant_settings_tenant_id_category_public_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX tenant_settings_tenant_id_category_public_index ON platform.tenant_settings USING btree (tenant_id, category, public);


--
-- Name: tenant_settings_tenant_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX tenant_settings_tenant_id_index ON platform.tenant_settings USING btree (tenant_id);


--
-- Name: tenants_company_schema_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX tenants_company_schema_index ON platform.tenants USING btree (company_schema);


--
-- Name: tenants_custom_domain_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX tenants_custom_domain_index ON platform.tenants USING btree (custom_domain) WHERE (custom_domain IS NOT NULL);


--
-- Name: tenants_plan_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX tenants_plan_index ON platform.tenants USING btree (plan);


--
-- Name: tenants_slug_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX tenants_slug_index ON platform.tenants USING btree (slug);


--
-- Name: tenants_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX tenants_status_index ON platform.tenants USING btree (status);


--
-- Name: tenants_subdomain_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX tenants_subdomain_index ON platform.tenants USING btree (subdomain);


--
-- Name: todos_assigned_to_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX todos_assigned_to_index ON platform.todos USING btree (assigned_to) WHERE (assigned_to IS NOT NULL);


--
-- Name: todos_due_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX todos_due_at_index ON platform.todos USING btree (due_at) WHERE (due_at IS NOT NULL);


--
-- Name: todos_owner_type_owner_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX todos_owner_type_owner_id_index ON platform.todos USING btree (owner_type, owner_id);


--
-- Name: todos_related_to_type_related_to_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX todos_related_to_type_related_to_id_index ON platform.todos USING btree (related_to_type, related_to_id);


--
-- Name: todos_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX todos_status_index ON platform.todos USING btree (status);


--
-- Name: unique_daily_metric_bucket; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX unique_daily_metric_bucket ON platform.analytics_metrics_daily USING btree (tenant_id, metric_key, time_bucket);


--
-- Name: unique_hourly_metric_bucket; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX unique_hourly_metric_bucket ON platform.analytics_metrics_hourly USING btree (tenant_id, metric_key, time_bucket);


--
-- Name: unique_tenant_branding_name; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX unique_tenant_branding_name ON platform.tenant_branding USING btree (tenant_id, name);


--
-- Name: unique_tenant_feature; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX unique_tenant_feature ON platform.feature_toggles USING btree (tenant_id, feature);


--
-- Name: unique_tenant_setting; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX unique_tenant_setting ON platform.tenant_settings USING btree (tenant_id, category, key);


--
-- Name: user_profiles_entity_type_entity_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX user_profiles_entity_type_entity_id_index ON platform.user_profiles USING btree (entity_type, entity_id);


--
-- Name: user_profiles_invitation_token_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX user_profiles_invitation_token_index ON platform.user_profiles USING btree (invitation_token) WHERE (invitation_token IS NOT NULL);


--
-- Name: user_profiles_is_admin_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX user_profiles_is_admin_index ON platform.user_profiles USING btree (is_admin) WHERE (is_admin = true);


--
-- Name: user_profiles_is_developer_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX user_profiles_is_developer_index ON platform.user_profiles USING btree (is_developer) WHERE (is_developer = true);


--
-- Name: user_profiles_status_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX user_profiles_status_index ON platform.user_profiles USING btree (status);


--
-- Name: user_profiles_user_id_entity_type_entity_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX user_profiles_user_id_entity_type_entity_id_index ON platform.user_profiles USING btree (user_id, entity_type, entity_id);


--
-- Name: user_profiles_user_id_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX user_profiles_user_id_index ON platform.user_profiles USING btree (user_id);


--
-- Name: users_email_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX users_email_index ON platform.users USING btree (email);


--
-- Name: users_failed_attempts_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX users_failed_attempts_index ON platform.users USING btree (failed_attempts);


--
-- Name: users_gdpr_anonymized_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX users_gdpr_anonymized_at_index ON platform.users USING btree (gdpr_anonymized_at);


--
-- Name: users_gdpr_data_export_token_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX users_gdpr_data_export_token_index ON platform.users USING btree (gdpr_data_export_token) WHERE (gdpr_data_export_token IS NOT NULL);


--
-- Name: users_gdpr_deletion_requested_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX users_gdpr_deletion_requested_at_index ON platform.users USING btree (gdpr_deletion_requested_at);


--
-- Name: users_gdpr_retention_expires_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX users_gdpr_retention_expires_at_index ON platform.users USING btree (gdpr_retention_expires_at);


--
-- Name: users_inserted_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX users_inserted_at_index ON platform.users USING btree (inserted_at);


--
-- Name: users_locked_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX users_locked_at_index ON platform.users USING btree (locked_at);


--
-- Name: users_password_change_required_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX users_password_change_required_index ON platform.users USING btree (password_change_required);


--
-- Name: users_unlock_token_expires_at_index; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX users_unlock_token_expires_at_index ON platform.users USING btree (unlock_token_expires_at) WHERE (unlock_token_expires_at IS NOT NULL);


--
-- Name: oban_jobs_args_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_args_index ON public.oban_jobs USING gin (args);


--
-- Name: oban_jobs_meta_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_meta_index ON public.oban_jobs USING gin (meta);


--
-- Name: oban_jobs_state_cancelled_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_state_cancelled_at_index ON public.oban_jobs USING btree (state, cancelled_at);


--
-- Name: oban_jobs_state_discarded_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_state_discarded_at_index ON public.oban_jobs USING btree (state, discarded_at);


--
-- Name: oban_jobs_state_queue_priority_scheduled_at_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_state_queue_priority_scheduled_at_id_index ON public.oban_jobs USING btree (state, queue, priority, scheduled_at, id);


--
-- Name: transfers_default_from_account_id_idx; Type: INDEX ATTACH; Schema: finance; Owner: -
--

ALTER INDEX finance.transfers_from_account_id_index ATTACH PARTITION finance.transfers_default_from_account_id_idx;


--
-- Name: transfers_default_inserted_at_idx; Type: INDEX ATTACH; Schema: finance; Owner: -
--

ALTER INDEX finance.transfers_inserted_at_index ATTACH PARTITION finance.transfers_default_inserted_at_idx;


--
-- Name: transfers_default_pkey; Type: INDEX ATTACH; Schema: finance; Owner: -
--

ALTER INDEX finance.transfers_pkey ATTACH PARTITION finance.transfers_default_pkey;


--
-- Name: transfers_default_to_account_id_idx; Type: INDEX ATTACH; Schema: finance; Owner: -
--

ALTER INDEX finance.transfers_to_account_id_index ATTACH PARTITION finance.transfers_default_to_account_id_idx;


--
-- Name: transfers_p2025_11_from_account_id_idx; Type: INDEX ATTACH; Schema: finance; Owner: -
--

ALTER INDEX finance.transfers_from_account_id_index ATTACH PARTITION finance.transfers_p2025_11_from_account_id_idx;


--
-- Name: transfers_p2025_11_inserted_at_idx; Type: INDEX ATTACH; Schema: finance; Owner: -
--

ALTER INDEX finance.transfers_inserted_at_index ATTACH PARTITION finance.transfers_p2025_11_inserted_at_idx;


--
-- Name: transfers_p2025_11_pkey; Type: INDEX ATTACH; Schema: finance; Owner: -
--

ALTER INDEX finance.transfers_pkey ATTACH PARTITION finance.transfers_p2025_11_pkey;


--
-- Name: transfers_p2025_11_to_account_id_idx; Type: INDEX ATTACH; Schema: finance; Owner: -
--

ALTER INDEX finance.transfers_to_account_id_index ATTACH PARTITION finance.transfers_p2025_11_to_account_id_idx;


--
-- Name: transfers_p2025_12_from_account_id_idx; Type: INDEX ATTACH; Schema: finance; Owner: -
--

ALTER INDEX finance.transfers_from_account_id_index ATTACH PARTITION finance.transfers_p2025_12_from_account_id_idx;


--
-- Name: transfers_p2025_12_inserted_at_idx; Type: INDEX ATTACH; Schema: finance; Owner: -
--

ALTER INDEX finance.transfers_inserted_at_index ATTACH PARTITION finance.transfers_p2025_12_inserted_at_idx;


--
-- Name: transfers_p2025_12_pkey; Type: INDEX ATTACH; Schema: finance; Owner: -
--

ALTER INDEX finance.transfers_pkey ATTACH PARTITION finance.transfers_p2025_12_pkey;


--
-- Name: transfers_p2025_12_to_account_id_idx; Type: INDEX ATTACH; Schema: finance; Owner: -
--

ALTER INDEX finance.transfers_to_account_id_index ATTACH PARTITION finance.transfers_p2025_12_to_account_id_idx;


--
-- Name: gdpr_consent_records consent_record_update_trigger; Type: TRIGGER; Schema: platform; Owner: -
--

CREATE TRIGGER consent_record_update_trigger AFTER INSERT ON platform.gdpr_consent_records FOR EACH ROW EXECUTE FUNCTION platform.update_consent_records();


--
-- Name: tenants tenant_settings_schema_trigger; Type: TRIGGER; Schema: platform; Owner: -
--

CREATE TRIGGER tenant_settings_schema_trigger AFTER INSERT ON platform.tenants FOR EACH ROW EXECUTE FUNCTION platform.trigger_tenant_settings_schema();


--
-- Name: accounts accounts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: -
--

ALTER TABLE ONLY finance.accounts
    ADD CONSTRAINT accounts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES platform.tenants(id);


--
-- Name: balances balances_account_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: -
--

ALTER TABLE ONLY finance.balances
    ADD CONSTRAINT balances_account_id_fkey FOREIGN KEY (account_id) REFERENCES finance.accounts(id);


--
-- Name: transfers transfers_from_account_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: -
--

ALTER TABLE finance.transfers
    ADD CONSTRAINT transfers_from_account_id_fkey FOREIGN KEY (from_account_id) REFERENCES finance.accounts(id);


--
-- Name: transfers transfers_to_account_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: -
--

ALTER TABLE finance.transfers
    ADD CONSTRAINT transfers_to_account_id_fkey FOREIGN KEY (to_account_id) REFERENCES finance.accounts(id);


--
-- Name: addresses addresses_address_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.addresses
    ADD CONSTRAINT addresses_address_type_fkey FOREIGN KEY (address_type) REFERENCES platform.address_types(value);


--
-- Name: addresses addresses_owner_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.addresses
    ADD CONSTRAINT addresses_owner_type_fkey FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value);


--
-- Name: analytics_alerts analytics_alerts_metric_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.analytics_alerts
    ADD CONSTRAINT analytics_alerts_metric_id_fkey FOREIGN KEY (metric_id) REFERENCES platform.analytics_metrics(id) ON DELETE CASCADE;


--
-- Name: analytics_alerts analytics_alerts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.analytics_alerts
    ADD CONSTRAINT analytics_alerts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES platform.tenants(id) ON DELETE CASCADE;


--
-- Name: analytics_dashboards analytics_dashboards_tenant_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.analytics_dashboards
    ADD CONSTRAINT analytics_dashboards_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES platform.tenants(id) ON DELETE CASCADE;


--
-- Name: analytics_reports analytics_reports_tenant_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.analytics_reports
    ADD CONSTRAINT analytics_reports_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES platform.tenants(id) ON DELETE CASCADE;


--
-- Name: analytics_widgets analytics_widgets_dashboard_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.analytics_widgets
    ADD CONSTRAINT analytics_widgets_dashboard_id_fkey FOREIGN KEY (dashboard_id) REFERENCES platform.analytics_dashboards(id) ON DELETE CASCADE;


--
-- Name: api_keys api_keys_owner_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.api_keys
    ADD CONSTRAINT api_keys_owner_type_fkey FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value);


--
-- Name: audit_logs audit_logs_actor_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.audit_logs
    ADD CONSTRAINT audit_logs_actor_type_fkey FOREIGN KEY (actor_type) REFERENCES platform.entity_types(value);


--
-- Name: audit_logs audit_logs_target_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.audit_logs
    ADD CONSTRAINT audit_logs_target_type_fkey FOREIGN KEY (target_type) REFERENCES platform.entity_types(value);


--
-- Name: auth_tokens auth_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.auth_tokens
    ADD CONSTRAINT auth_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES platform.users(id) ON DELETE CASCADE;


--
-- Name: data_migration_logs data_migration_logs_migration_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.data_migration_logs
    ADD CONSTRAINT data_migration_logs_migration_id_fkey FOREIGN KEY (migration_id) REFERENCES platform.data_migrations(id) ON DELETE CASCADE;


--
-- Name: data_migration_records data_migration_records_migration_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.data_migration_records
    ADD CONSTRAINT data_migration_records_migration_id_fkey FOREIGN KEY (migration_id) REFERENCES platform.data_migrations(id) ON DELETE CASCADE;


--
-- Name: data_migrations data_migrations_tenant_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.data_migrations
    ADD CONSTRAINT data_migrations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES platform.tenants(id);


--
-- Name: developer_tenants developer_tenants_developer_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.developer_tenants
    ADD CONSTRAINT developer_tenants_developer_id_fkey FOREIGN KEY (developer_id) REFERENCES platform.developers(id) ON DELETE CASCADE;


--
-- Name: developer_tenants developer_tenants_tenant_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.developer_tenants
    ADD CONSTRAINT developer_tenants_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES platform.tenants(id) ON DELETE CASCADE;


--
-- Name: developers developers_user_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.developers
    ADD CONSTRAINT developers_user_id_fkey FOREIGN KEY (user_id) REFERENCES platform.users(id) ON DELETE SET NULL;


--
-- Name: developers_versions developers_versions_version_source_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.developers_versions
    ADD CONSTRAINT developers_versions_version_source_id_fkey FOREIGN KEY (version_source_id) REFERENCES platform.developers(id);


--
-- Name: documents documents_approved_by_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.documents
    ADD CONSTRAINT documents_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES platform.users(id);


--
-- Name: documents documents_document_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.documents
    ADD CONSTRAINT documents_document_type_fkey FOREIGN KEY (document_type) REFERENCES platform.document_types(value);


--
-- Name: documents documents_owner_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.documents
    ADD CONSTRAINT documents_owner_type_fkey FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value);


--
-- Name: emails emails_email_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.emails
    ADD CONSTRAINT emails_email_type_fkey FOREIGN KEY (email_type) REFERENCES platform.email_types(value);


--
-- Name: emails emails_owner_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.emails
    ADD CONSTRAINT emails_owner_type_fkey FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value);


--
-- Name: feature_toggles feature_toggles_enabled_by_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.feature_toggles
    ADD CONSTRAINT feature_toggles_enabled_by_fkey FOREIGN KEY (enabled_by) REFERENCES platform.users(id) ON DELETE SET NULL;


--
-- Name: feature_toggles feature_toggles_tenant_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.feature_toggles
    ADD CONSTRAINT feature_toggles_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES platform.tenants(id) ON DELETE CASCADE;


--
-- Name: images images_image_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.images
    ADD CONSTRAINT images_image_type_fkey FOREIGN KEY (image_type) REFERENCES platform.image_types(value);


--
-- Name: images images_owner_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.images
    ADD CONSTRAINT images_owner_type_fkey FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value);


--
-- Name: notes notes_owner_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.notes
    ADD CONSTRAINT notes_owner_type_fkey FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value);


--
-- Name: notes notes_related_to_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.notes
    ADD CONSTRAINT notes_related_to_type_fkey FOREIGN KEY (related_to_type) REFERENCES platform.entity_types(value);


--
-- Name: payment_charges payment_charges_customer_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.payment_charges
    ADD CONSTRAINT payment_charges_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES platform.payment_customers(id);


--
-- Name: payment_charges payment_charges_payment_method_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.payment_charges
    ADD CONSTRAINT payment_charges_payment_method_id_fkey FOREIGN KEY (payment_method_id) REFERENCES platform.payment_methods(id);


--
-- Name: payment_gateway_transactions payment_gateway_transactions_charge_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.payment_gateway_transactions
    ADD CONSTRAINT payment_gateway_transactions_charge_id_fkey FOREIGN KEY (charge_id) REFERENCES platform.payment_charges(id);


--
-- Name: payment_methods payment_methods_customer_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.payment_methods
    ADD CONSTRAINT payment_methods_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES platform.payment_customers(id);


--
-- Name: payment_refunds payment_refunds_charge_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.payment_refunds
    ADD CONSTRAINT payment_refunds_charge_id_fkey FOREIGN KEY (charge_id) REFERENCES platform.payment_charges(id);


--
-- Name: phones phones_owner_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.phones
    ADD CONSTRAINT phones_owner_type_fkey FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value);


--
-- Name: phones phones_phone_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.phones
    ADD CONSTRAINT phones_phone_type_fkey FOREIGN KEY (phone_type) REFERENCES platform.phone_types(value);


--
-- Name: registration_requests registration_requests_tenant_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.registration_requests
    ADD CONSTRAINT registration_requests_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES platform.tenants(id);


--
-- Name: reseller_tenants reseller_tenants_reseller_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.reseller_tenants
    ADD CONSTRAINT reseller_tenants_reseller_id_fkey FOREIGN KEY (reseller_id) REFERENCES platform.resellers(id) ON DELETE CASCADE;


--
-- Name: reseller_tenants reseller_tenants_tenant_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.reseller_tenants
    ADD CONSTRAINT reseller_tenants_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES platform.tenants(id) ON DELETE CASCADE;


--
-- Name: resellers resellers_developer_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.resellers
    ADD CONSTRAINT resellers_developer_id_fkey FOREIGN KEY (developer_id) REFERENCES platform.developers(id) ON DELETE SET NULL;


--
-- Name: resellers resellers_user_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.resellers
    ADD CONSTRAINT resellers_user_id_fkey FOREIGN KEY (user_id) REFERENCES platform.users(id) ON DELETE SET NULL;


--
-- Name: resellers_versions resellers_versions_version_source_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.resellers_versions
    ADD CONSTRAINT resellers_versions_version_source_id_fkey FOREIGN KEY (version_source_id) REFERENCES platform.resellers(id);


--
-- Name: socials socials_owner_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.socials
    ADD CONSTRAINT socials_owner_type_fkey FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value);


--
-- Name: socials socials_platform_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.socials
    ADD CONSTRAINT socials_platform_fkey FOREIGN KEY (platform) REFERENCES platform.social_platforms(value);


--
-- Name: team_members team_members_invited_by_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.team_members
    ADD CONSTRAINT team_members_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES platform.user_profiles(id);


--
-- Name: team_members team_members_team_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.team_members
    ADD CONSTRAINT team_members_team_id_fkey FOREIGN KEY (team_id) REFERENCES platform.teams(id) ON DELETE CASCADE;


--
-- Name: team_members team_members_user_profile_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.team_members
    ADD CONSTRAINT team_members_user_profile_id_fkey FOREIGN KEY (user_profile_id) REFERENCES platform.user_profiles(id) ON DELETE CASCADE;


--
-- Name: teams teams_entity_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.teams
    ADD CONSTRAINT teams_entity_type_fkey FOREIGN KEY (entity_type) REFERENCES platform.entity_types(value);


--
-- Name: tenant_branding tenant_branding_created_by_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.tenant_branding
    ADD CONSTRAINT tenant_branding_created_by_fkey FOREIGN KEY (created_by) REFERENCES platform.users(id) ON DELETE SET NULL;


--
-- Name: tenant_branding tenant_branding_tenant_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.tenant_branding
    ADD CONSTRAINT tenant_branding_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES platform.tenants(id) ON DELETE CASCADE;


--
-- Name: tenant_branding tenant_branding_updated_by_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.tenant_branding
    ADD CONSTRAINT tenant_branding_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES platform.users(id) ON DELETE SET NULL;


--
-- Name: tenant_settings tenant_settings_last_updated_by_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.tenant_settings
    ADD CONSTRAINT tenant_settings_last_updated_by_fkey FOREIGN KEY (last_updated_by) REFERENCES platform.users(id) ON DELETE SET NULL;


--
-- Name: tenant_settings tenant_settings_tenant_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.tenant_settings
    ADD CONSTRAINT tenant_settings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES platform.tenants(id) ON DELETE CASCADE;


--
-- Name: todos todos_assigned_to_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.todos
    ADD CONSTRAINT todos_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES platform.users(id);


--
-- Name: todos todos_owner_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.todos
    ADD CONSTRAINT todos_owner_type_fkey FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value);


--
-- Name: todos todos_related_to_type_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.todos
    ADD CONSTRAINT todos_related_to_type_fkey FOREIGN KEY (related_to_type) REFERENCES platform.entity_types(value);


--
-- Name: todos todos_status_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.todos
    ADD CONSTRAINT todos_status_fkey FOREIGN KEY (status) REFERENCES platform.status_types(value);


--
-- Name: user_profiles user_profiles_invited_by_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.user_profiles
    ADD CONSTRAINT user_profiles_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES platform.users(id);


--
-- Name: user_profiles user_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.user_profiles
    ADD CONSTRAINT user_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES platform.users(id) ON DELETE CASCADE;


--
-- Name: addresses; Type: ROW SECURITY; Schema: platform; Owner: -
--

ALTER TABLE platform.addresses ENABLE ROW LEVEL SECURITY;

--
-- Name: documents; Type: ROW SECURITY; Schema: platform; Owner: -
--

ALTER TABLE platform.documents ENABLE ROW LEVEL SECURITY;

--
-- Name: emails; Type: ROW SECURITY; Schema: platform; Owner: -
--

ALTER TABLE platform.emails ENABLE ROW LEVEL SECURITY;

--
-- Name: images; Type: ROW SECURITY; Schema: platform; Owner: -
--

ALTER TABLE platform.images ENABLE ROW LEVEL SECURITY;

--
-- Name: notes; Type: ROW SECURITY; Schema: platform; Owner: -
--

ALTER TABLE platform.notes ENABLE ROW LEVEL SECURITY;

--
-- Name: phones; Type: ROW SECURITY; Schema: platform; Owner: -
--

ALTER TABLE platform.phones ENABLE ROW LEVEL SECURITY;

--
-- Name: socials; Type: ROW SECURITY; Schema: platform; Owner: -
--

ALTER TABLE platform.socials ENABLE ROW LEVEL SECURITY;

--
-- Name: todos; Type: ROW SECURITY; Schema: platform; Owner: -
--

ALTER TABLE platform.todos ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--


