# Debug Script
alias Mcp.Repo
result = Ecto.Adapters.SQL.query!(Repo, "SELECT column_name, data_type, udt_name FROM information_schema.columns WHERE table_name = 'transfers'")
Enum.each(result.rows, fn [name, type, udt] ->
  IO.puts "#{name}: #{type} (#{udt})"
end)
