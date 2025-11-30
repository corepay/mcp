defmodule Mix.Tasks.Mcp.SeedFinance do
  use Mix.Task

  @shortdoc "Seeds finance accounts for GAAP tracking"
  def run(_) do
    {:ok, _} = Application.ensure_all_started(:mcp)
    Mcp.Finance.Seeder.seed()
  end
end
