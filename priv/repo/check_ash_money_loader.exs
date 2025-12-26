IO.puts "Checking AshMoney Loader..."
tuple = {"USD", Decimal.new("1.0")}
# AshMoney uses @composite_type.load. We can't access attribute.
# But we can call AshMoney.Types.Money.load(tuple, [], nil) (constraints=[], context=nil)
case AshMoney.Types.Money.cast_stored(tuple, []) do
  {:ok, val} -> IO.inspect(val, label: "Loaded")
  other -> IO.inspect(other, label: "Result")
end
