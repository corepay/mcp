[:telemetry, :ecto, :postgrex, :ash, :ash_postgres]
|> Enum.each(&Application.ensure_all_started/1)

{:ok, _} = Mcp.Repo.start_link()
{:ok, _} = Mcp.Secrets.start_link()

Mcp.Seeder.run()
