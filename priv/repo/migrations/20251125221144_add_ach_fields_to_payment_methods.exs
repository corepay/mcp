defmodule Mcp.Repo.Migrations.AddAchFieldsToPaymentMethods do
  use Ecto.Migration

  def change do
    alter table(:payment_methods) do
      add :bank_name, :string
      add :account_holder_name, :string
      add :account_type, :string
      add :last4_account, :string
    end
  end
end
