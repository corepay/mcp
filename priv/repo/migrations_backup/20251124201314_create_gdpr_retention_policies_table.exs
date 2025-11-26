defmodule Mcp.Repo.Migrations.CreateGdprRetentionPoliciesTable do
  use Ecto.Migration

  def change do
    create table(:gdpr_retention_policies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :entity_type, :string, null: false
      add :retention_days, :integer, null: false, default: 365
      add :action, :string, null: false, default: "anonymize"
      add :legal_hold, :boolean, default: false
      add :legal_hold_reason, :string
      add :legal_hold_until, :utc_datetime_usec
      add :conditions, :map, default: %{}
      add :priority, :integer, default: 100
      add :active, :boolean, default: true
      add :description, :string
      add :last_processed_at, :utc_datetime_usec
      add :processing_frequency_hours, :integer, default: 24

      timestamps()
    end

    create index(:gdpr_retention_policies, [:tenant_id])
    create index(:gdpr_retention_policies, [:entity_type])
    create index(:gdpr_retention_policies, [:active])
    create index(:gdpr_retention_policies, [:legal_hold])
    create index(:gdpr_retention_policies, [:last_processed_at])

    # Compound index for finding policies that need processing
    create index(:gdpr_retention_policies, [:active, :legal_hold, :last_processed_at])
  end
end
