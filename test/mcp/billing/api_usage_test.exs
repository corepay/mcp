defmodule Mcp.Billing.ApiUsageTest do
  @moduledoc false
  use Mcp.DataCase

  alias Mcp.Billing.ApiUsage
  alias Mcp.Finance.Account
  alias Mcp.Platform.Tenant

  describe "charge_usage/1" do
    setup do
      # Create isolated test tenant
      unique_id = System.unique_integer([:positive])

      tenant =
        Mcp.Repo.insert!(%Tenant{
          id: Ecto.UUID.generate(),
          name: "Test Tenant #{unique_id}",
          slug: "test-tenant-#{unique_id}",
          subdomain: "test-#{unique_id}",
          company_schema: "acq_test_#{unique_id}",
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        })

      {:ok, tenant: tenant}
    end

    test "creates a transfer from tenant wallet to revenue", %{tenant: tenant} do
      # 1. Charge
      assert {:ok, transfer} = ApiUsage.charge_usage(tenant.id)

      # 2. Verify Transfer
      assert transfer.amount == Money.new(:USD, "1.00")
      assert transfer.description == "API Usage Charge"

      # 3. Verify Accounts created
      wallet = Account.get_by_identifier!("tenant_wallet_#{tenant.id}", authorize?: false)
      revenue = Account.get_by_identifier!("REV_API_USAGE", authorize?: false)

      assert transfer.from_account_id == wallet.id
      assert transfer.to_account_id == revenue.id

      # 4. Verify Wallet Type (Liability)
      assert wallet.type == :liability
    end
  end
end
