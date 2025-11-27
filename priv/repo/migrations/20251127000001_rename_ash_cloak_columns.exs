defmodule Mcp.Repo.Migrations.RenameAshCloakColumns do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE platform.users RENAME COLUMN totp_secret TO encrypted_totp_secret"
    execute "ALTER TABLE platform.users RENAME COLUMN backup_codes TO encrypted_backup_codes"
    execute "ALTER TABLE platform.users RENAME COLUMN oauth_tokens TO encrypted_oauth_tokens"
  end

  def down do
    execute "ALTER TABLE platform.users RENAME COLUMN encrypted_totp_secret TO totp_secret"
    execute "ALTER TABLE platform.users RENAME COLUMN encrypted_backup_codes TO backup_codes"
    execute "ALTER TABLE platform.users RENAME COLUMN encrypted_oauth_tokens TO oauth_tokens"
  end
end
