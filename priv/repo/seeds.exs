# Ensure the app is started
[:telemetry, :ash, :mcp]
|> Enum.each(fn app ->
  case Application.ensure_all_started(app) do
    {:ok, _} -> :ok
    {:error, {:already_started, _}} -> :ok
    {:error, reason} -> IO.warn("Failed to start #{app}: #{inspect(reason)}")
  end
end)

IO.puts("DATABASE_URL: #{System.get_env("DATABASE_URL")}")
IO.puts("Checking Mcp.Repo...")

case Process.whereis(Mcp.Repo) do
  nil -> IO.puts("Mcp.Repo is NOT running!")
  pid -> IO.puts("Mcp.Repo is running at #{inspect(pid)}")
end

Mcp.Seeder.run()
