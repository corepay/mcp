defmodule Mcp.Repo.Migrations.AddAshArchivalFinanceAiChat do
  use Ecto.Migration

  def up do
    # Finance Accounts
    alter table(:accounts, prefix: "finance") do
      add :archived_at, :utc_datetime_usec
    end

    # AI Documents (public schema usually, but let's check resource def - it says table "documents", no schema, so public)
    alter table(:documents) do
      add :archived_at, :utc_datetime_usec
    end

    # Chat Conversations (public schema)
    alter table(:conversations) do
      add :archived_at, :utc_datetime_usec
    end

    # Chat Messages (public schema)
    alter table(:messages) do
      add :archived_at, :utc_datetime_usec
    end
  end

  def down do
    alter table(:accounts, prefix: "finance") do
      remove :archived_at
    end

    alter table(:documents) do
      remove :archived_at
    end

    alter table(:conversations) do
      remove :archived_at
    end

    alter table(:messages) do
      remove :archived_at
    end
  end
end
