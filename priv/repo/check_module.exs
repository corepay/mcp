IO.puts "Checking Money.Ecto.Composite.Type..."
try do
  case Code.ensure_loaded(Money.Ecto.Composite.Type) do
    {:module, mod} -> IO.puts "Loaded: #{inspect(mod)}"
    {:error, reason} -> IO.puts "Not Loaded: #{inspect(reason)}"
  end
rescue
  e -> IO.puts "Error: #{inspect(e)}"
end
