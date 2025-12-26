alias Mcp.Repo
IO.puts "Testing Cast..."
sql = "SELECT coalesce('{\"amount\": 100, \"currency\": \"USD\"}'::jsonb, row('USD', 1)::public.money_with_currency)::public.money_with_currency"
case Ecto.Adapters.SQL.query(Repo, sql, []) do
  {:ok, %{rows: rows}} -> IO.inspect(rows, label: "Result")
  {:error, err} -> IO.inspect(err, label: "Error")
end
