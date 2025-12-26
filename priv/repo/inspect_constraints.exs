IO.puts "Inspecting Mcp.Finance.Balance.balance constraints..."
attr = Ash.Resource.Info.attribute(Mcp.Finance.Balance, :balance)
IO.inspect(attr.constraints, label: "Constraints")
