defmodule Mcp.Billing.ApiUsage do
  @moduledoc """
  Service for verifying and charging API usage credits.
  """
  require Logger
  require Ash.Query
  alias Mcp.Finance.Account
  alias Mcp.Finance.Transfer

  @revenue_account_identifier "REV_API_USAGE"
  @default_cost Money.new(:USD, "1.00")

  def charge_usage(tenant_id) do
    # 1. Ensure Revenue Account
    with {:ok, revenue_account} <- ensure_revenue_account(),
         # 2. Ensure Tenant Wallet
         {:ok, tenant_wallet} <- ensure_tenant_wallet(tenant_id) do
      # 3. Create Transfer
      Transfer.create(
        %{
          from_account_id: tenant_wallet.id,
          to_account_id: revenue_account.id,
          amount: @default_cost,
          description: "API Usage Charge"
        },
        authorize?: false
      )
    else
      error ->
        Logger.error("Billing logic failed: #{inspect(error)}")
        # For M2M alpha, we log error but don't crash caller if possible (async task)
        {:error, error}
    end
  end

  defp ensure_revenue_account do
    case Account.get_by_identifier(@revenue_account_identifier, authorize?: false) do
      {:ok, account} ->
        {:ok, account}

      {:error, _} ->
        Account.create(
          %{
            name: "API Usage Revenue",
            identifier: @revenue_account_identifier,
            type: :revenue,
            currency: :USD
          },
          authorize?: false
        )
    end
  end

  defp ensure_tenant_wallet(tenant_id) do
    identifier = "tenant_wallet_#{tenant_id}"

    case Account.get_by_identifier(identifier, authorize?: false) do
      {:ok, account} ->
        {:ok, account}

      {:error, _} ->
        Account.create(
          %{
            name: "Tenant Wallet",
            identifier: identifier,
            type: :liability,
            currency: :USD,
            tenant_id: tenant_id
          },
          authorize?: false
        )
    end
  end
end
