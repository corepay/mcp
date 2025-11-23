defmodule Mcp.Repo.TenantMigrations.AddAuditColumns do
  @moduledoc """
  Migration to add audit columns to all tenant tables.
  """

  use Ecto.Migration

  def up do
    # Add audit columns to merchants table
    alter table(:merchants) do
      add :created_by, :uuid
      add :updated_by, :uuid
    end

    # Add audit columns to resellers table
    alter table(:resellers) do
      add :created_by, :uuid
      add :updated_by, :uuid
    end

    # Add audit columns to developers table
    alter table(:developers) do
      add :created_by, :uuid
      add :updated_by, :uuid
    end

    # Create audit log table for tenant
    create table(:audit_logs) do
      add :table_name, :string, null: false
      add :record_id, :uuid, null: false
      add :action, :string, null: false
      add :changed_fields, :jsonb
      add :user_id, :uuid
      add :ip_address, :string
      add :user_agent, :string
      add :timestamp, :utc_datetime, null: false, default: fragment("NOW()")
    end

    create index(:audit_logs, [:table_name, :record_id])
    create index(:audit_logs, [:timestamp])
    create index(:audit_logs, [:user_id])
  end

  def down do
    drop table(:audit_logs)

    alter table(:merchants) do
      remove :created_by
      remove :updated_by
    end

    alter table(:resellers) do
      remove :created_by
      remove :updated_by
    end

    alter table(:developers) do
      remove :created_by
      remove :updated_by
    end
  end
end