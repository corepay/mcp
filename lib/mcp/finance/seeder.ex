defmodule Mcp.Finance.Seeder do
  @moduledoc """
  Seeds initial finance accounts for system operations.
  """
  
  require Ash.Query
  require Logger

  def seed do
    # Ensure necessary applications are started
    {:ok, _} = Application.ensure_all_started(:telemetry)
    {:ok, _} = Application.ensure_all_started(:mcp)

    Logger.info("Seeding Finance Accounts...")
    # Ensure System Tenant exists (or use a global scope)
    # For simplicity, we'll create global accounts not tied to a specific tenant if allowed,
    # or attached to a "System" tenant.
    
    # 1. Expense: AI Compute
    ensure_account("Expense: AI Compute", "EXP_AI_COMPUTE", :expense)
    
    # 2. Liability: AI Providers
    ensure_account("Liability: AI Providers", "LIA_AI_PROVIDERS", :liability)
  end

  defp ensure_account(name, identifier, type) do
    # Check if account exists
    case Mcp.Finance.Account
         |> Ash.Query.filter(identifier == ^identifier)
         |> Ash.read_one() do
      {:ok, account} ->
        Logger.info("Account #{name} already exists.")
        account

      {:error, error} ->
        Logger.error("Error checking account #{name}: #{inspect(error)}")
        nil
        
      nil ->
        Logger.info("Creating Account #{name}...")
        Mcp.Finance.Account.create!(%{
          name: name,
          identifier: identifier,
          currency: :USD,
          type: type
        })
    end
  end
end
