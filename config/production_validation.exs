import Config

# Production validation configuration
# This file contains production-specific settings and validation checks

# Database configuration validation
config :mcp, Mcp.Repo,
  # SSL should be enabled in production
  ssl: true,
  # Strong pool settings for production
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20"),
  # Enable connection ownership tracking for better debugging
  ownership_timeout: 60_000,
  # Set stack size for database connections
  stack_size: 5_000,
  # Enable prepared statements for better performance
  prepare: :unnamed,
  # Connection timeout
  connect_timeout: 15_000,
  # Transaction timeout
  transaction_timeout: 15_000

# Production-specific endpoint configuration
config :mcp, McpWeb.Endpoint,
  # Force SSL in production
  force_ssl: [
    hsts: true,
    max_age: 31536000,
    include_subdomains: true,
    preload: true
  ],
  # Production server settings
  server: true,
  # HTTP/2 enabled for better performance
  http: [
    transport_options: [max_connections: 10_000]
  ],
  # Logging configuration
  pubsub_server: Mcp.PubSub,
  live_view: [
    signing_salt: System.get_env("LIVE_VIEW_SIGNING_SALT")
  ]

# Security hardening configuration
config :mcp, :security,
  # Enable all security features in production
  audit_trail_enabled: true,
  rate_limiting_enabled: true,
  encryption_enabled: true,
  compliance_monitoring: true,
  # Production rate limits
  rate_limits: %{
    gdpr_api: %{limit: 100, window: 3600},  # 100 requests per hour
    auth_api: %{limit: 20, window: 3600},   # 20 auth attempts per hour
    export_api: %{limit: 10, window: 86400}   # 10 exports per day
  }

# GDPR production configuration
config :mcp, :gdpr,
  # Enable all GDPR features in production
  audit_trail_enabled: true,
  rate_limiting_enabled: true,
  encryption_enabled: true,
  compliance_monitoring: true,
  # Production retention settings
  data_retention: %{
    export_files: 30,          # days
    audit_entries: 365,         # days
    consent_records: 2555,      # days (7 years)
    anonymization_delay: 30     # days
  }

# Logging configuration for production
config :logger, level: :info

# Oban production configuration
config :mcp, Oban,
  repo: Mcp.Repo,
  queues: [
    default: 10,
    gdpr_exports: 5,
    gdpr_cleanup: 2,
    compliance: 3,
    mailers: 5
  ],
  # Production-specific plugins
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron, crontab: [
      {"0 2 * * *", Mcp.Jobs.Gdpr.ComplianceWorker},       # Daily at 2 AM
      {"0 3 * * 0", Mcp.Jobs.Gdpr.RetentionCleanupWorker}, # Weekly on Sunday at 3 AM
      {"0 4 * * *", Mcp.Jobs.Gdpr.AuditWorker}            # Daily at 4 AM
    ]}
  ],
  # Production safety settings
  stage_prefix: "oban",
  verbose: false

# Swoosh email configuration for production
config :swoosh, :api_client, Swoosh.ApiClient.Req

# Production monitoring configuration
config :mcp, :monitoring,
  # Health check settings
  health_check_interval: 30_000,  # 30 seconds
  readiness_timeout: 5_000,       # 5 seconds
  # Metrics collection
  metrics_enabled: true,
  metrics_interval: 60_000,       # 1 minute
  # Alerting thresholds
  alert_thresholds: %{
    memory_usage: 0.85,           # 85% memory usage
    cpu_usage: 0.80,              # 80% CPU usage
    response_time_p95: 2000,      # 2 seconds
    error_rate: 0.05              # 5% error rate
  }

# Runtime production configuration
config :runtime,
  # Enable Telemetry
  telemetry_enabled: true,
  # Performance monitoring
  performance_monitoring: true,
  # Error tracking
  error_tracking: true