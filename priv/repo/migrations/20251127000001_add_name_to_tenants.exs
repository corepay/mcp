defmodule Mcp.Repo.Migrations.AddNameToTenants do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE platform.tenants ADD COLUMN IF NOT EXISTS name text"
  end

  def down do
    alter table(:tenants, prefix: "platform") do
      remove :name
    end
  end
end
