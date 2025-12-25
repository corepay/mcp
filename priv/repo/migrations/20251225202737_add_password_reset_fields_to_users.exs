defmodule Mcp.Repo.Migrations.AddPasswordResetFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users, prefix: "platform") do
      add :reset_password_token, :string
      add :reset_password_sent_at, :utc_datetime
    end

    create index(:users, [:reset_password_token], prefix: "platform")
  end
end
