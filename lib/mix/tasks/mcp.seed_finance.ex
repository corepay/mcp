defmodule Mix.Tasks.Mcp.SeedFinance do
  @moduledoc """
  Mix task to seed financial data.
  """
  use Mix.Task

  alias Mcp.Finance.Seeder

  @shortdoc "Seeds finance accounts for GAAP tracking"
  def run(_) do
    {:ok, _} = Application.ensure_all_started(:mcp)
    Seeder.seed()
  end
end
