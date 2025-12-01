import Config
config :mcp, Oban, testing: :manual
config :mcp, :token_signing_secret, "test-secret-for-jwt-signing"
config :mcp, env: :test
config :mcp, :skip_dns_check, true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :mcp, Mcp.Repo,
  username: "base_mcp_dev",
  password: "mcp_password",
  hostname: "localhost",
  database: "mcp_test#{System.get_env("MIX_TEST_PARTITION")}",
  port: String.to_integer(System.get_env("POSTGRES_PORT") || "41789"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 20,
  queue_target: 5000,
  parameters: [search_path: "public,platform"]

config :mcp, :async_api_key_updates, false
config :mcp, :compliance_impl, ComplianceMock
config :mcp, :run_tenant_migrations, false
config :mcp, :agent_runner_adapter, :mock

config :mcp, :qorpay,
  base_url: "http://qorpay.test",
  app_key: "test_key",
  client_key: "test_client",
  mid: "test_mid"

config :mcp, :req_options, plug: {Req.Test, Mcp.Payments.Gateways.QorPay}

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mcp, McpWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "1aeJoqfyOp+mDaNf0xIjPek07T8oYgFVJ+ymrXbkOJMQYVkeMOJYQGu6uoviquaT",
  server: false

# In test we don't send emails
config :mcp, Mcp.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Mock OAuth module
config :mcp, :oauth_module, Mcp.Accounts.OAuthMock

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :ex_aws, :s3,
  scheme: "http://",
  host: "localhost",
  port: 9000,
  region: "local"

config :ex_aws,
  access_key_id: "minioadmin",
  secret_access_key: "minioadmin"

# Coverage configuration
if System.get_env("MIX_ENV") == "test" do
  config :excoveralls,
    default_output_dir: "cover",
    default_output_file: "coveralls.json",
    coveralls_json_file: "coveralls.json",
    coveralls_service_name: "github_actions",
    coveralls_send_on_exit: true

  config :excoveralls,
    # Coverage minimum thresholds
    coverage_minimum: 80

  config :excoveralls,
    coverage_threshold: %{
      "lib/mcp/core/" => 90,
      "lib/mcp/" => 80,
      "lib/mcp_web/" => 75
    }

  # Include only application source files
  config :excoveralls,
    files_included: ["lib/"],
    files_excluded: [
      "test/",
      "_build/",
      "deps/",
      "priv/",
      "lib/mcp_web/telemetry.ex",
      "lib/mcp_web/endpoint.ex",
      "lib/mcp_web/router.ex"
    ]

  # Console coverage report
  config :excoveralls,
    console_output: true,
    html_output: true,
    json_output: true
end
