ExUnit.start(
  max_failures: 1,
  seed: 0,
  timeout: 60_000,
  trace: System.get_env("TRACE", "false") == "true"
)

Ecto.Adapters.SQL.Sandbox.mode(Mcp.Repo, :manual)

# Start ExCoveralls if coverage is enabled
if System.get_env("MIX_ENV") == "test" && System.get_env("COVERALLS", "false") != "false" do
  ExCoveralls.start()
end

# Configure ExUnit for parallel testing where safe
ExUnit.configure(exclude: [:slow, :integration])

# Test utilities
alias Mcp.TestFixtures
alias Mcp.IntegrationHelpers

# Configure test database
Application.put_env(:mcp, Mcp.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mcp_test#{System.get_env("MIX_TEST_PARTITION", "")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  show_sensitive_data_on_connection_error: true,
  ownership_timeout: 60_000
)

# Configure test environment
Application.ensure_all_started(:logger)

# Configure test logger
Logger.configure(level: :warning)

# Test-specific application configuration
Application.put_env(:mcp, McpWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false,
  live_view: [signing_salt: "test_signing_salt"],
  secret_key_base: "test_secret_key_base_for_testing_purposes_only"
)

# Configure email testing
Application.put_env(:mcp, Mcp.Mailer, adapter: Swoosh.Adapters.Test)

# Configure Swoosh for testing
Application.put_env(:swoosh, :api_client, false)

# Configure Bandit for testing
Application.put_env(:bandit, :check_origin, false)

# Configure telemetry for testing
Application.put_env(:telemetry_poller, :default, [])
Application.put_env(:telemetry_poller, :metrics, [])

# Custom ExUnit formatters for better output
ExUnit.configure(formatters: [ExUnit.CLIFormatter])

# Test tags configuration
ExUnit.configure(
  exclude: [
    # Slow tests that should be run separately
    :slow,
    # Integration tests that require full setup
    :integration,
    # Tests that hit external APIs
    :external_api,
    # Performance benchmarks
    :performance
  ]
)

# Before suite setup - Migrate before running tests
unless System.get_env("SKIP_MIGRATIONS", "false") == "true" do
  Mix.Task.run("ecto.create", ["--quiet"])
  Mix.Task.run("ecto.migrate", ["--quiet"])
end

# Note: ExUnit.after_suite/1 would be used here if needed for cleanup
