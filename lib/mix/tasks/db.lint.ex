defmodule Mix.Tasks.Db.Lint do
  use Mix.Task

  @shortdoc "Runs Supabase Splinter SQL linter against the database"
  @moduledoc """
  Runs the Supabase Splinter SQL linter against the configured database.
  It executes the SQL query found in `priv/repo/splinter.sql` and reports
  any issues found (ERROR, WARN, INFO).
  """

  def run(_args) do
    # Ensure the app is fully started
    {:ok, _} = Application.ensure_all_started(:mcp)

    repo = Mcp.Repo
    sql_path = Application.app_dir(:mcp, "priv/repo/splinter.sql")

    unless File.exists?(sql_path) do
      Mix.raise("Could not find splinter.sql at #{sql_path}")
    end

    IO.puts("Running Database Linter (Splinter)...")
    sql = File.read!(sql_path)

    # Splinter script might contain multiple statements or just one big query.
    # Based on the preview, it looks like a single complex SELECT statement.
    # However, sometimes SQL scripts have 'SET search_path' at the top.
    # Ecto.Adapters.SQL.query! runs a single statement.
    # If there are multiple, we might need to split them or use a transaction.
    # The preview showed `set local search_path = '';` then `( with ... )`.
    # This implies multiple statements. Ecto might complain.
    # Let's try running it as a single string. Postgres usually allows multiple statements in one query string
    # BUT Ecto might return the result of the *last* one, or all of them.
    # Actually, `Ecto.Adapters.SQL.query` usually executes a prepared statement which doesn't support multiple commands.
    # We should probably strip the `set local search_path` or run it separately.
    # Let's try to parse it simply: split by `;` if needed, or just run the main query.

    # Inspecting the file content logic:
    # The file starts with `set local search_path = '';`
    # Then `( with ... )` which is the main query.
    # We really only care about the main query.

    # Create Supabase-specific roles if they don't exist to prevent linter errors
    try do
      repo.query!("DO $$
      BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
          CREATE ROLE anon NOLOGIN;
        END IF;
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
          CREATE ROLE authenticated NOLOGIN;
        END IF;
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'service_role') THEN
          CREATE ROLE service_role NOLOGIN;
        END IF;
      END
      $$;")
    rescue
      _ -> IO.warn("Could not create Supabase roles. Linter might fail if they are missing.")
    end

    # Let's try to run it. If it fails, we will refine the splitting logic.
    try do
      result = repo.query!(sql)
      print_results(result)
    rescue
      _e ->
        IO.warn("Execution failed, attempting to split statements...")
        # Naive split, but Splinter seems to have 2 parts: setup and query.
        statements =
          sql
          |> String.split(";", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        # The last statement should be the query returning rows
        {query_stmts, [final_query]} = Enum.split(statements, -1)

        repo.transaction(fn ->
          for stmt <- query_stmts do
            repo.query!(stmt)
          end

          final_result = repo.query!(final_query)
          print_results(final_result)
        end)
    end
  end

  defp print_results(%Postgrex.Result{rows: rows, columns: columns}) do
    # Map columns to indices
    col_idx =
      columns
      |> Enum.with_index()
      |> Map.new()

    if Enum.empty?(rows) do
      IO.puts(IO.ANSI.green() <> "✅ No database issues found." <> IO.ANSI.reset())
    else
      IO.puts(IO.ANSI.yellow() <> "⚠️  Found #{length(rows)} issues:" <> IO.ANSI.reset())
      IO.puts("")

      Enum.each(rows, fn row ->
        name = Enum.at(row, col_idx["name"])
        title = Enum.at(row, col_idx["title"])
        level = Enum.at(row, col_idx["level"])
        description = Enum.at(row, col_idx["description"])
        detail = Enum.at(row, col_idx["detail"])
        remediation = Enum.at(row, col_idx["remediation"])

        color =
          case level do
            "ERROR" -> IO.ANSI.red()
            "WARN" -> IO.ANSI.yellow()
            _ -> IO.ANSI.cyan()
          end

        IO.puts("#{color}[#{level}] #{title} (#{name})#{IO.ANSI.reset()}")
        IO.puts("    #{detail}")
        IO.puts("    #{IO.ANSI.light_black()}#{description}#{IO.ANSI.reset()}")

        if remediation do
          IO.puts("    👉 Fix: #{remediation}")
        end

        IO.puts("")
      end)
    end
  end
end
