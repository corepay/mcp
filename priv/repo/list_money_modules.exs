# Debug Script
:application.load(:ex_money_sql)
:application.load(:ex_money)
:application.load(:ash_money)
modules = :code.all_loaded()
|> Enum.map(fn {m, _} -> Atom.to_string(m) end)
|> Enum.filter(&String.contains?(&1, "Money"))
|> Enum.sort()

IO.puts "Money Modules (All):"
Enum.each(modules, &IO.puts/1)
