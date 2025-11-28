defmodule Mcp.Repo.Migrations.AddAshArchivalFinanceAiChat do
  use Ecto.Migration

  def up do
    IO.puts("Running AddAshArchivalFinanceAiChat migration...")
    # Finance Accounts
    alter table(:accounts, prefix: "finance") do
      add :archived_at, :utc_datetime_usec
    end

    # AI Documents (platform schema)
    alter table(:documents, prefix: "platform") do
      add :archived_at, :utc_datetime_usec
    end

    # Chat Conversations (public schema)
    alter table(:conversations, prefix: "public") do
      add :archived_at, :utc_datetime_usec
    end

    # Chat Messages (public schema)
    alter table(:messages, prefix: "public") do
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
