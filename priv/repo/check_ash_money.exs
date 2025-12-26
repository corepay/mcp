alias AshMoney.Types
IO.puts "Checking AshMoney Types..."
try do
  IO.puts "Money: #{inspect(AshMoney.Types.Money)}"
  IO.puts "MoneyMap: #{inspect(AshMoney.Types.MoneyMap)}" # Guessing name
rescue
  e -> IO.puts "Error: #{inspect(e)}"
end
