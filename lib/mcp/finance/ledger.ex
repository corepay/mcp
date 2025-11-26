defmodule Mcp.Finance.Ledger do
  @moduledoc """
  Context module for financial ledger operations and calculations.
  """
  require Ash.Query
  alias Mcp.Finance.{Account, Transfer}

  @doc """
  Calculates the total incoming volume for a merchant's account on a specific date.
  """
  def calculate_daily_volume(merchant_id, date) do
    # 1. Find the merchant's account
    account = get_merchant_account(merchant_id)

    case account do
      nil ->
        {:error, :account_not_found}

      account ->
        # 2. Sum transfers to this account on the given date
        start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
        end_of_day = DateTime.new!(date, ~T[23:59:59.999999], "Etc/UTC")

        Transfer
        |> Ash.Query.filter(to_account_id == ^account.id)
        |> Ash.Query.filter(timestamp >= ^start_of_day and timestamp <= ^end_of_day)
        |> Ash.read!()
        |> Enum.reduce(Decimal.new(0), fn transfer, acc ->
          Decimal.add(acc, transfer.amount)
        end)
        |> then(&{:ok, &1})
    end
  end

  @doc """
  Fetches the settlement amount from the payment gateway for a merchant on a specific date.
  Currently a stub.
  """
  def get_gateway_settlement(_merchant_id, _date) do
    # In a real implementation, this would call QorPay API
    # For now, we return a random amount or 0
    {:ok, Decimal.new("1000.00")}
  end

  defp get_merchant_account(merchant_id) do
    Account
    |> Ash.Query.filter(merchant_id == ^merchant_id)
    |> Ash.read_one!()
  end
end
