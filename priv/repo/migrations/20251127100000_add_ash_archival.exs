defmodule Mcp.Repo.Migrations.AddAshArchival do
  use Ecto.Migration

  def up do
    # Users table
    alter table(:users, prefix: "platform") do
      add :archived_at, :utc_datetime_usec
    end

    # Backfill archived_at for deleted users
    execute("UPDATE platform.users SET archived_at = NOW() WHERE status = 'deleted'")

    # Tenants table
    alter table(:tenants, prefix: "platform") do
      add :archived_at, :utc_datetime_usec
    end

    # Backfill archived_at for deleted tenants
    execute("UPDATE platform.tenants SET archived_at = NOW() WHERE status = 'deleted'")
  end

  def down do
    alter table(:users, prefix: "platform") do
      remove :archived_at
    end

    alter table(:tenants, prefix: "platform") do
      remove :archived_at
    end
  end
end
