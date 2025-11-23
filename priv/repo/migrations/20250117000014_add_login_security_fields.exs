defmodule Mcp.Repo.Migrations.AddLoginSecurityFields do
  use Ecto.Migration

  def up do
    alter table(:users, prefix: "platform") do
      add :failed_attempts, :integer, default: 0, null: false
      add :locked_at, :utc_datetime
      add :unlock_token, :text
      add :unlock_token_expires_at, :utc_datetime
    end

    # Add index for lockout management
    create index(:users, [:locked_at], prefix: "platform")
    create index(:users, [:failed_attempts], prefix: "platform")

    create index(:users, [:unlock_token_expires_at],
             where: "unlock_token_expires_at IS NOT NULL",
             prefix: "platform"
           )
  end

  def down do
    alter table(:users, prefix: "platform") do
      remove :failed_attempts
      remove :locked_at
      remove :unlock_token
      remove :unlock_token_expires_at
    end
  end
end
