defmodule Mix.Tasks.Db.Analyze do
  @moduledoc """
  Analyzes a SQL query using the Supabase Index Advisor and suggests indexes.

  ## Usage

      mix db.analyze "SELECT * FROM my_table WHERE some_column = 'value'"

  """
  use Mix.Task

  def run(args) do
    # Ensure the app is fully started
    {:ok, _} = Application.ensure_all_started(:mcp)

    query = List.first(args)

    if is_nil(query) or String.trim(query) == "" do
      Mix.raise("Please provide a SQL query to analyze.")
    end

    IO.puts("\n🔍 Analyzing query with Supabase Index Advisor...\n")
    IO.puts("Query: #{query}\n")

    case Mcp.Repo.query("SELECT * FROM index_advisor($1)", [query]) do
      {:ok, result} ->
        print_results(result)

      {:error, error} ->
        IO.puts("❌ Error running analysis: #{inspect(error)}")
    end
  end

  defp print_results(%Postgrex.Result{rows: rows, columns: columns}) do
    if Enum.empty?(rows) do
      IO.puts("✅ No index recommendations found. The query might already be optimal or no indexes can improve it.")
    else
      # Map columns to rows
      results =
        Enum.map(rows, fn row ->
          Enum.zip(columns, row) |> Enum.into(%{})
        end)

      Enum.each(results, fn row ->
        startup_cost_before = row["startup_cost_before"]
        total_cost_before = row["total_cost_before"]
        total_cost_after = row["total_cost_after"]
        index_statements = row["index_statements"]
        errors = row["errors"]

        improvement = calculate_improvement(total_cost_before, total_cost_after)

        IO.puts("---------------------------------------------------")
        IO.puts("📊 Cost Analysis:")
        IO.puts("   Before: #{total_cost_before} (Startup: #{startup_cost_before})")
        IO.puts("   After:  #{total_cost_after}")
        IO.puts("   Improvement: #{improvement}%")

        if errors && errors != [] do
          IO.puts("\n⚠️ Errors:")
          Enum.each(errors, &IO.puts("   - #{&1}"))
        end

        if index_statements && index_statements != [] do
          IO.puts("\n💡 Suggested Indexes:")
          Enum.each(index_statements, fn stmt ->
            IO.puts("\n   #{stmt}")
          end)
        end
        IO.puts("---------------------------------------------------\n")
      end)
    end
  end

  defp calculate_improvement(before_cost, after_cost) do
    if before_cost > 0 do
      diff = before_cost - after_cost
      (diff / before_cost * 100) |> Float.round(2)
    else
      0.0
    end
  end
end
