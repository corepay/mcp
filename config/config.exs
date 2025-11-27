# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Load .env file manually to ensure variables are available for config files
# This is necessary because dependencies (like Dotenvy) are not compiled
# when config files are evaluated during the initial mix run.
if File.exists?(".env") do
  File.stream!(".env")
  |> Stream.map(&String.trim/1)
  |> Stream.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  |> Enum.each(fn line ->
    case String.split(line, "=", parts: 2) do
      [key, value] -> System.put_env(String.trim(key), String.trim(value))
      _ -> :ok
    end
  end)
end

config :mcp,
  ecto_repos: [Mcp.Repo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [
    Mcp.Chat,
    Mcp.Accounts,
    Mcp.Platform,
    Mcp.Domains.Gdpr,
    Mcp.Payments,
    Mcp.Finance,
    Mcp.Audit,
    Mcp.Ai
  ],
  base_domain: "localhost"

config :ash_typescript,
  output_file: "assets/js/ash_generated.ts"

config :mcp, :qorpay,
  base_url: System.get_env("QORPAY_SANDBOX_URL", "https://api-sandbox.qorcommerce.io/v3"),
  app_key: System.get_env("QORPAY_SANDBOX_APP_KEY", "T6554252567241061980"),
  client_key: System.get_env("QORPAY_SANDBOX_CLIENT_KEY", "01dffeb784c64d098c8c691ea589eb82"),
  mid: System.get_env("QORPAY_SANDBOX_MID", "887728202")

# Oban configuration
config :mcp, Oban,
  repo: Mcp.Repo,
  queues: [
    # Data export processing
    gdpr_exports: 10,
    # Data anonymization
    gdpr_anonymize: 3,
    # Compliance monitoring
    gdpr_compliance: 2,
    # Data retention processing
    gdpr_retention: 5,
    chat_responses: [limit: 10],
    conversations: [limit: 10]
  ],
  plugins: [
    # Prune completed jobs after 24 hours
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24},
    # Cron job for GDPR data processing
    {Oban.Plugins.Cron,
     crontab: [
       # Daily at 1 AM
       {"0 1 * * *", Mcp.Jobs.Gdpr.RetentionCleanupWorker,
        args: %{"action" => "process_retention_policies"}},
       # Daily at 2 AM
       {"0 2 * * *", Mcp.Jobs.Gdpr.ComplianceWorker, args: %{"action" => "verify_compliance"}},
       # Weekly on Sunday at 3 AM
       {"0 3 * * 0", Mcp.Jobs.Gdpr.ComplianceWorker,
        args: %{"action" => "weekly_compliance_report"}},
       # Daily at 4 AM
       {"0 4 * * *", Mcp.Jobs.Gdpr.RetentionCleanupWorker,
        args: %{"action" => "cleanup_expired_exports"}}
     ]},
    # Lifeline for stuck jobs
    {Oban.Plugins.Lifeline, rescue_after: 30 * 60}
  ]

config :ex_cldr, default_backend: Mcp.Cldr

# Configures the endpoint
config :mcp, McpWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: McpWeb.ErrorHTML, json: McpWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Mcp.PubSub,
  live_view: [signing_salt: "uwayY1wB"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :mcp, Mcp.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  mcp: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  mcp: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :request_id,
    :tenant_id,
    :backup_id,
    :error,
    :config,
    :deleted,
    :retention_days,
    :exit_code,
    :output,
    :path,
    :size,
    :type,
    :since,
    :reason
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Finch HTTP client
config :finch,
  name: Mcp.Finch,
  pools: %{
    default: [size: 10, count: 2]
  }

# JWT Configuration
config :mcp, Mcp.Accounts.JWT,
  # Token lifespans
  access_token_ttl: {24, :hour},
  refresh_token_ttl: {30, :day},
  sliding_refresh_threshold: {12, :hour},

  # JWT settings
  issuer: "mcp-platform",
  audience: "mcp-users"

# AshAi Configuration
config :ash_ai,
  default_model: "llama3"

# Ash type compatibility configuration
config :ash, :compatible_foreign_key_types,
  [
    {Ash.Type.UUID, Ash.Type.String},
    {Ash.Type.UUID, AshDoubleEntry.ULID},
    {AshDoubleEntry.ULID, Ash.Type.UUID}
  ]

# Disable Tesla deprecation warning
config :tesla, disable_deprecated_builder_warning: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
