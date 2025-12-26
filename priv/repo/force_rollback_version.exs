alias Mcp.Repo
version = 20251226030136
IO.puts "Deleting version #{version} from schema_migrations..."
Ecto.Adapters.SQL.query!(Repo, "DELETE FROM schema_migrations WHERE version = $1", [version])
IO.puts "Deleted."
