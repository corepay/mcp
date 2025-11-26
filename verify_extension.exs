# Script to verify Mcp.Graph.Extension
try do
  {:ok, _} = Application.ensure_all_started(:spark)

  # Try to load the module
  case Code.ensure_compiled(Mcp.Graph.Extension) do
    {:module, mod} ->
      IO.puts("Module #{mod} compiled successfully.")

      if function_exported?(mod, :dsl, 0) do
        IO.puts("dsl/0 function exported.")
        IO.inspect(mod.dsl(), label: "DSL Config")
      else
        IO.puts("dsl/0 function NOT exported.")
      end

    {:error, reason} ->
      IO.puts("Failed to compile module: #{inspect(reason)}")
  end
rescue
  e -> IO.inspect(e, label: "Error")
end
