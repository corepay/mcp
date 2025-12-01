defmodule Mcp.Repo.Migrations.AddUniqueIndexToTenantSettings do
  use Ecto.Migration

  def change do
    create unique_index(:tenant_settings, [:tenant_id, :category, :key],
             name: "tenant_settings_tenant_category_key_index"
           )
  end
end
