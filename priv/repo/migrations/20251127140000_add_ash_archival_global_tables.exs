defmodule Mcp.Repo.Migrations.AddAshArchivalGlobalTables do
  use Ecto.Migration

  def up do
    # Platform Addresses
    alter table(:addresses, prefix: "platform") do
      add :archived_at, :utc_datetime_usec
    end

    # Platform Emails
    alter table(:emails, prefix: "platform") do
      add :archived_at, :utc_datetime_usec
    end

    # Platform Phones
    alter table(:phones, prefix: "platform") do
      add :archived_at, :utc_datetime_usec
    end
  end

  def down do
    alter table(:addresses, prefix: "platform") do
      remove :archived_at
    end

    alter table(:emails, prefix: "platform") do
      remove :archived_at
    end

    alter table(:phones, prefix: "platform") do
      remove :archived_at
    end
  end
end
