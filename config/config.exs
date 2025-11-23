# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mcp,
  ecto_repos: [Mcp.Repo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [Mcp.Accounts, Mcp.Platform, Mcp.Domains.Gdpr],
  base_domain: "localhost"

# Oban configuration
config :mcp, Oban,
  repo: Mcp.Repo,
  queues: [
    gdpr_exports: 10,     # Data export processing
    gdpr_cleanup: 5,      # Data retention cleanup
    gdpr_anonymize: 3,    # Data anonymization
    gdpr_compliance: 2    # Compliance monitoring
  ],
  plugins: [
    # Prune completed jobs after 24 hours
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24},
    # Cron job for daily retention cleanup
    {Oban.Plugins.Cron,
     crontab: [
       {"0 2 * * *", Mcp.Jobs.Gdpr.RetentionCleanup},  # Daily at 2 AM
       {"0 3 * * 0", Mcp.Jobs.Gdpr.WeeklyCompliance} # Weekly on Sunday at 3 AM
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
  metadata: [:request_id]

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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
