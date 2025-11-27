defmodule Mcp.Repo do
  @moduledoc """
  Core domain repository with full technology stack support.
  Handles TimescaleDB, PostGIS, pgvector, Apache AGE operations.
  """

  use AshPostgres.Repo,
    otp_app: :mcp,
    adapter: Ecto.Adapters.Postgres

  # Advanced features for AI-powered MSP platform

  # Advanced query helpers for full technology stack

  def tenant_query(tenant_schema_name, query) do
    with_tenant_schema(tenant_schema_name, fn ->
      __MODULE__.all(query)
    end)
  end

  def with_tenant_schema(tenant_schema_name, fun) when is_function(fun, 0) do
    schema_name = "acq_" <> tenant_schema_name
    original_search_path = get_search_path()

    try do
      __MODULE__.query("SET search_path TO #{schema_name}, public, platform, shared, ag_catalog")
      fun.()
    after
      if original_search_path do
        __MODULE__.query("SET search_path TO #{original_search_path}")
      end
    end
  end

  # TimescaleDB helper
  def create_hypertable(table_name, time_column, opts \\ []) do
    chunk_time = Keyword.get(opts, :chunk_time, "1 day")
    query = "SELECT create_hypertable($1, $2, chunk_time_interval => INTERVAL $3)"
    __MODULE__.query(query, [table_name, time_column, chunk_time])
  end

  # PostGIS helper
  def postgis_version do
    query = "SELECT PostGIS_Lib_Version()"
    __MODULE__.query(query, [])
  end

  # pgvector helper
  def vector_version do
    query = "SELECT extversion FROM pg_extension WHERE extname = 'vector'"
    __MODULE__.query(query, [])
  end

  # Apache AGE helper
  def age_version do
    query = "SELECT * FROM ag_version()"
    __MODULE__.query(query, [])
  end

  # Performance monitoring
  def database_stats do
    query = """
    SELECT
      schemaname,
      tablename,
      attname,
      n_distinct,
      correlation
    FROM pg_stats
    """

    __MODULE__.query(query, [])
  end

  def get_search_path do
    case __MODULE__.query("SHOW search_path") do
      {:ok, %{rows: [[search_path]]}} -> search_path
      {:error, _} -> nil
    end
  end

  # Ash PostgreSQL support
  @impl true
  def disable_atomic_actions? do
    System.get_env("DISABLE_ATOMIC_ACTIONS", "false") == "true"
  end

  @impl true
  def prefer_transaction? do
    System.get_env("PREFER_TRANSACTION", "true") == "true"
  end

  # Ash callback for transaction tracking
  @impl true
  def on_transaction_begin(_context) do
    # No-op for now - can be used for telemetry later
    :ok
  end

  # Ash callback for installed extensions
  @impl true
  def installed_extensions do
    # Return list of installed PostgreSQL extensions
    # This can be dynamic by querying the database
    ["uuid-ossp", "pgcrypto", "btree_gist", "citext", "ash-functions"]
  end

  @impl true
  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end

  # Ash callback for expression errors
  @impl true
  def disable_expr_error? do
    # Return whether to disable expression errors
    System.get_env("DISABLE_EXPR_ERROR", "false") == "true"
  end

  # Ash callback for constraint matching
  @impl true
  def default_constraint_match_type(:custom, _constraint_name) do
    :exact
  end

  @impl true
  def default_constraint_match_type(_type, _constraint_name) do
    :exact
  end
end
