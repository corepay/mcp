defmodule Mcp.Repo.TenantMigrations.UnderwritingRemediationV2 do
  @moduledoc """
  Adds policy_hash to risk_assessments for logic attribution.
  """
  use Ecto.Migration

  def up do
    alter table(:risk_assessments, prefix: prefix()) do
      add :policy_hash, :text
    end
  end

  def down do
    alter table(:risk_assessments, prefix: prefix()) do
      remove :policy_hash
    end
  end
end
