# Debug script
IO.puts "Attributes of Mcp.Finance.Transfer:"
Mcp.Finance.Transfer
|> Ash.Resource.Info.attributes()
|> Enum.each(fn attr ->
  IO.puts "#{attr.name}: #{inspect(attr.type)}"
end)
