defmodule Mcp.Repo.Migrations.InitialSchema do
  use Ecto.Migration

  def up do
    # Execute the initial schema dump
    execute_sql_file("initial_schema.sql")

    # Execute the initial seeds (lookup tables)
    execute_sql_file("initial_seeds.sql")

    execute "CREATE EXTENSION IF NOT EXISTS age"
    execute("CREATE EXTENSION IF NOT EXISTS pgsodium")
    execute("CREATE EXTENSION IF NOT EXISTS supabase_vault")
    # execute "CREATE EXTENSION IF NOT EXISTS pg_cron"
    execute "CREATE EXTENSION IF NOT EXISTS pg_graphql"
    execute "CREATE EXTENSION IF NOT EXISTS pgmq"
    execute "LOAD 'age'"
    execute "SET search_path = ag_catalog, \"$user\", public, platform"
  end

  def down do
    # Drop everything
    execute "DROP SCHEMA IF EXISTS platform CASCADE"
    execute "DROP SCHEMA IF EXISTS shared CASCADE"
    execute "DROP EXTENSION IF EXISTS age CASCADE"
  end

  defp execute_sql_file(filename) do
    path = Path.join(:code.priv_dir(:mcp), "repo/structure/#{filename}")

    if File.exists?(path) do
      # Get connection config from Repo
      config = Mcp.Repo.config()
      username = config[:username] || System.get_env("POSTGRES_USER") || "postgres"
      password = config[:password] || System.get_env("POSTGRES_PASSWORD") || "postgres"
      database = config[:database] || System.get_env("POSTGRES_DB") || "mcp_dev"
      hostname = config[:hostname] || System.get_env("POSTGRES_HOST") || "localhost"
      port = config[:port] || System.get_env("POSTGRES_PORT") || "5432"

      # Set PGPASSWORD environment variable
      env = [{"PGPASSWORD", password}]

      args = [
        "-v",
        # "ON_ERROR_STOP=1",
        "-q",
        "-h",
        hostname,
        "-p",
        to_string(port),
        "-U",
        username,
        "-d",
        database,
        "-f",
        path
      ]

      {output, exit_code} = System.cmd("psql", args, env: env, stderr_to_stdout: true)

      if exit_code != 0 do
        raise "Failed to execute SQL file #{filename}: #{output}"
      end
    else
      raise "SQL file not found: #{path}"
    end
  end
end
