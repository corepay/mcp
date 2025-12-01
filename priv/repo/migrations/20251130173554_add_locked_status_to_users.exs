defmodule Mcp.Repo.Migrations.AddLockedStatusToUsers do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE platform.users DROP CONSTRAINT IF EXISTS users_status_check"

    execute "ALTER TABLE platform.users ADD CONSTRAINT users_status_check CHECK (status IN ('active', 'suspended', 'deleted', 'anonymized', 'locked'))"
  end

  def down do
    execute "ALTER TABLE platform.users DROP CONSTRAINT IF EXISTS users_status_check"

    execute "ALTER TABLE platform.users ADD CONSTRAINT users_status_check CHECK (status IN ('active', 'suspended', 'deleted', 'anonymized'))"
  end
end
