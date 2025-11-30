defmodule Mcp.Finance.Jobs.PostLlmCosts do
  use Oban.Worker, queue: :finance

  require Ash.Query
  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Starting LLM Cost Posting...")

    # 1. Find unposted usage
    unposted_query = 
      Mcp.Ai.LlmUsage
      |> Ash.Query.filter(is_nil(transfer_id))
    
    # We need to sum the cost. 
    # Ash.read!(query) would load all records. 
    # Let's use an aggregate if possible, or just read and sum in memory for simplicity (assuming volume isn't massive per 10 mins)
    # Better: Use Ash.sum aggregate query.
    
    case Ash.sum(unposted_query, :cost) do
      {:ok, total_cost} when not is_nil(total_cost) ->
        if Decimal.gt?(total_cost, 0) do
          post_costs(total_cost, unposted_query)
        else
          Logger.info("No LLM costs to post.")
          :ok
        end
      _ -> 
        Logger.info("No LLM costs to post.")
        :ok
    end
  end

  defp post_costs(amount, query) do
    # 2. Get Accounts
    expense_account = get_account("EXP_AI_COMPUTE")
    liability_account = get_account("LIA_AI_PROVIDERS")

    if expense_account && liability_account do
      # 3. Create Transfer (Credit Liability, Debit Expense)
      # Using AshDoubleEntry transfer logic if available, or creating a Transfer resource
      
      # Assuming Mcp.Finance.Transfer is the resource
      transfer_params = %{
        amount: amount,
        from_account_id: liability_account.id, # Credit Liability (Source) - Wait, Double Entry usually: From Asset/Expense -> To Liability/Equity?
        # Standard: Debit Expense (Increase), Credit Liability (Increase)
        # In AshDoubleEntry:
        # Transfer from Liability to Expense? 
        # No, usually "From" is the source of funds (Credit), "To" is the destination (Debit).
        # So From Liability Account -> To Expense Account.
        to_account_id: expense_account.id,
        description: "LLM Usage Posting - #{DateTime.utc_now()}"
      }
      
      Mcp.Repo.transaction(fn ->
        transfer = Mcp.Finance.Transfer.create!(transfer_params)
        
        # 4. Mark usages as posted
        # We need to update all records in the query with the new transfer_id
        # Ash.bulk_update is perfect here.
        
        query
        |> Ash.bulk_update!(:update_transfer, %{transfer_id: transfer.id}, strategy: :atomic)
        
        Logger.info("Posted #{amount} to Ledger. Transfer ID: #{transfer.id}")
      end)
      
      :ok
    else
      Logger.error("System accounts not found. Run Mcp.Finance.Seeder.seed/0")
      {:error, :accounts_missing}
    end
  end

  defp get_account(identifier) do
    Mcp.Finance.Account
    |> Ash.Query.filter(identifier == ^identifier)
    |> Ash.read_one!()
  end
end
