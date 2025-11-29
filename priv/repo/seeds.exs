# Load environment variables
{:ok, _} = Application.ensure_all_started(:dotenvy)
Dotenvy.source!([".env", ".env.example"])
|> Enum.each(fn {k, v} -> System.put_env(k, v) end)

# Ensure the app is started
[:telemetry, :ash, :db_connection, :ecto_sql, :postgrex, :mcp]
|> Enum.each(fn app ->
  case Application.ensure_all_started(app) do
    {:ok, _} -> :ok
    {:error, {:already_started, _}} -> :ok
    {:error, reason} -> IO.warn("Failed to start #{app}: #{inspect(reason)}")
  end
end)

# Ensure Repo is running
if Process.whereis(Mcp.Repo) == nil do
  {:ok, _} = Mcp.Repo.start_link()
end

Mcp.Seeder.run()
