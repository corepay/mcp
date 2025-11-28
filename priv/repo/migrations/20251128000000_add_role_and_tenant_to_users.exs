defmodule Mcp.Repo.Migrations.AddRoleAndTenantToUsers do
  use Ecto.Migration

  def up do
    alter table(:users, prefix: "platform") do
      add :role, :text, null: false, default: "user"
      add :tenant_id, :uuid
    end
  end

  def down do
    alter table(:users, prefix: "platform") do
      remove :role
      remove :tenant_id
    end
  end
end
