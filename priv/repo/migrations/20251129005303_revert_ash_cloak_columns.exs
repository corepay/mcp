defmodule Mcp.Repo.Migrations.RevertAshCloakColumns do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE platform.users ALTER COLUMN totp_secret TYPE text USING convert_from(totp_secret, 'UTF8')"
    execute "ALTER TABLE platform.users ALTER COLUMN backup_codes TYPE text[] USING (convert_from(backup_codes, 'UTF8'))::text[]"
    execute "ALTER TABLE platform.users ALTER COLUMN oauth_tokens TYPE jsonb USING (convert_from(oauth_tokens, 'UTF8'))::jsonb"
    
    # Restore defaults if they were dropped
    alter table(:users, prefix: "platform") do
      modify :backup_codes, {:array, :text}, default: []
      modify :oauth_tokens, :map, default: %{}
    end
  end

  def down do
    execute "ALTER TABLE platform.users ALTER COLUMN totp_secret TYPE bytea USING totp_secret::bytea"
    execute "ALTER TABLE platform.users ALTER COLUMN backup_codes TYPE bytea USING backup_codes::text::bytea"
    execute "ALTER TABLE platform.users ALTER COLUMN oauth_tokens TYPE bytea USING oauth_tokens::text::bytea"
  end
end
