alias Mcp.Repo
try do
  result = Ecto.Adapters.SQL.query!(Repo, "SELECT n.nspname, t.typname FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid WHERE t.typname = 'money_with_currency'")
  if Enum.empty?(result.rows) do
    IO.puts "Type money_with_currency DOES NOT exist."
  else
    Enum.each(result.rows, fn [schema, type] ->
      IO.puts "Type #{schema}.#{type} EXISTS."
    end)
  end
rescue
  e -> IO.puts "Error: #{inspect(e)}"
end
