# Script to reset DB schemas regardless of locks
alias Mcp.Repo
IO.puts "Dropping schemas..."
try do
  Ecto.Adapters.SQL.query!(Repo, "DROP SCHEMA IF EXISTS public CASCADE;", [])
  Ecto.Adapters.SQL.query!(Repo, "CREATE SCHEMA public;", [])
  Ecto.Adapters.SQL.query!(Repo, "DROP SCHEMA IF EXISTS finance CASCADE;", [])
  Ecto.Adapters.SQL.query!(Repo, "DROP SCHEMA IF EXISTS platform CASCADE;", []) # If exists

  # Also delete schema_migrations data effectively (by dropping table implicitly via public drop or explicitly)
  # Public drop handles schema_migrations usually.
  IO.puts "Schemas dropped."
rescue
  e -> IO.puts "Error dropping schemas: #{inspect(e)}"
end
