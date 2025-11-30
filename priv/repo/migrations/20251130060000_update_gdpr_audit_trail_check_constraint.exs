defmodule Mcp.Repo.Migrations.UpdateGdprAuditTrailCheckConstraint do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE platform.gdpr_audit_trail DROP CONSTRAINT IF EXISTS action_type_check"
  end

  def down do
    # No-op or restore if known
  end
end
