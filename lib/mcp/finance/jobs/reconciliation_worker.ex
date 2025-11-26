defmodule Mcp.Finance.ReconciliationWorker do
  @moduledoc """
  Periodically reconciles internal ledger with payment gateway settlements.
  """
  use Oban.Worker, queue: :finance, max_attempts: 3

  require Logger
  require Ash.Query

  alias Mcp.Finance.Ledger

  def perform(%Oban.Job{args: %{"action" => "reconcile_daily_settlements"}}) do
    Logger.info("Starting daily reconciliation...")

    # In a real app, we would iterate over all merchants.
    # For this MVP/Stub, we'll just log that we are running.
    # You can trigger specific merchant reconciliation via the other clause.

    Logger.info("Daily reconciliation job completed.")
    :ok
  end

  def perform(%Oban.Job{args: %{"merchant_id" => merchant_id, "date" => date_str}}) do
    date = Date.from_iso8601!(date_str)
    Logger.info("Reconciling merchant #{merchant_id} for date #{date}")

    with {:ok, internal_volume} <- Ledger.calculate_daily_volume(merchant_id, date),
         {:ok, gateway_volume} <- Ledger.get_gateway_settlement(merchant_id, date) do
      if Decimal.eq?(internal_volume, gateway_volume) do
        Logger.info(
          "Reconciliation SUCCESS for merchant #{merchant_id}: Matches #{internal_volume}"
        )
      else
        Logger.warning(
          "Reconciliation FAILED for merchant #{merchant_id}: Internal #{internal_volume} != Gateway #{gateway_volume}"
        )

        # Here we would create an alert or flag the account
      end

      :ok
    else
      error ->
        Logger.error("Reconciliation error for merchant #{merchant_id}: #{inspect(error)}")
        {:error, error}
    end
  end
end
