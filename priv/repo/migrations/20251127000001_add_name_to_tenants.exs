defmodule Mcp.Repo.Migrations.AddNameToTenants do
  use Ecto.Migration

  def up do
    alter table(:tenants, prefix: "platform") do
      add :name, :text
    end
  end

  def down do
    alter table(:tenants, prefix: "platform") do
      remove :name
    end
  end
end
