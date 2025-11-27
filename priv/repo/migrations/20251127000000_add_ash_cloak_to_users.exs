defmodule Mcp.Repo.Migrations.AddAshCloakToUsers do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE platform.users ALTER COLUMN backup_codes DROP DEFAULT"
    execute "ALTER TABLE platform.users ALTER COLUMN oauth_tokens DROP DEFAULT"
    execute "ALTER TABLE platform.users ALTER COLUMN totp_secret TYPE bytea USING totp_secret::bytea"
    execute "ALTER TABLE platform.users ALTER COLUMN backup_codes TYPE bytea USING backup_codes::text::bytea"
    execute "ALTER TABLE platform.users ALTER COLUMN oauth_tokens TYPE bytea USING oauth_tokens::text::bytea"
  end

  def down do
    execute "ALTER TABLE platform.users ALTER COLUMN totp_secret TYPE text USING totp_secret::text"
    execute "ALTER TABLE platform.users ALTER COLUMN backup_codes TYPE text[] USING backup_codes::text::text[]"
    execute "ALTER TABLE platform.users ALTER COLUMN oauth_tokens TYPE jsonb USING oauth_tokens::text::jsonb"
  end
end
