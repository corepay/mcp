ExUnit.start(
  max_failures: 1,
  seed: 0,
  timeout: 120_000,
  max_cases: 4,
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

# Configure test database
Application.put_env(:mcp, Mcp.Repo,
  username: "base_mcp_dev",
  password: "mcp_password",
  hostname: "localhost",
  port: 41_789,
  database: "mcp_test#{System.get_env("MIX_TEST_PARTITION", "")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 20,
  queue_target: 30_000,
  show_sensitive_data_on_connection_error: true,
  ownership_timeout: 180_000
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
  live_view: [signing_salt: "test_signing_salt"],
  secret_key_base: "test_secret_key_base_for_testing_purposes_only"
)

# Configure mocks
Application.put_env(:mcp, :dns_verifier, Mcp.Infrastructure.DnsVerifierMock)

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
    :performance,
    # OAuth integration tests pending full AshAuthentication OAuth2 plug setup
    :pending_oauth_implementation,
    # AtlasChat component not yet implemented
    :pending_atlas_chat,
    # Tests pending proper Mox behaviour/mock module setup
    :pending_mox_setup,
    # Tests pending migration from Accounts.ApiKey to Platform.ApiKey
    :pending_api_key_migration,
    # Skip tagged tests (for tests with known issues)
    :skip
  ]
)

# Before suite setup - Migrate before running tests
unless System.get_env("SKIP_MIGRATIONS", "false") == "true" do
  Mix.Task.run("ecto.create", ["--quiet"])
  Mix.Task.run("ecto.migrate", ["--quiet"])

  # Bootstrap Template Schema (if configured)
  # This serves as the single pre-migrated schema for all tests to avoid
  # runtime migration deadlocks inside sandbox transactions.
  if template_schema = Application.get_env(:mcp, :force_tenant_schema) do
    {:ok, _} = Application.ensure_all_started(:mcp)

    # Define a temporary Repo for setup that bypasses the Sandbox and its ownership issues
    defmodule SetupRepo do
      use Ecto.Repo,
        otp_app: :mcp,
        adapter: Ecto.Adapters.Postgres
    end

    # Configure SetupRepo using the same DB settings but standard pool
    main_repo_config = Application.get_env(:mcp, Mcp.Repo)

    setup_repo_config =
      main_repo_config
      |> Keyword.put(:pool, DBConnection.ConnectionPool)
      |> Keyword.put(:pool_size, 2)
      # Avoid name conflict
      |> Keyword.put(:name, nil)

    Application.put_env(:mcp, SetupRepo, setup_repo_config)

    # Start SetupRepo
    {:ok, _pid} = SetupRepo.start_link()

    try do
      IO.puts("Bootstrapping Template Schema: #{template_schema} via SetupRepo...")
      path = Application.app_dir(:mcp, "priv/repo/tenant_migrations")

      # 1. Drop (Clean Slate)
      SetupRepo.query!("DROP SCHEMA IF EXISTS \"#{template_schema}\" CASCADE")

      # 2. Create
      SetupRepo.query!("CREATE SCHEMA \"#{template_schema}\"")

      # 3. Migrate
      Ecto.Migrator.run(SetupRepo, path, :up, all: true, prefix: template_schema)
      IO.puts("Template Schema #{template_schema} ready.")
    after
      # Cleanup
      SetupRepo.stop()
    end
  end
end

# Note: ExUnit.after_suite/1 would be used here if needed for cleanup
