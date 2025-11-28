defmodule Mcp.Repo.Migrations.AddEncryptedColumnsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users, prefix: "platform") do
      add :encrypted_backup_codes, :binary
      add :encrypted_totp_secret, :binary
      add :encrypted_oauth_tokens, :binary
    end
  end
end
