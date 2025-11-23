defmodule Mcp.Repo.Migrations.AddPasswordChangeRequiredField do
  use Ecto.Migration

  def up do
    alter table(:users, prefix: "platform") do
      add :password_change_required, :boolean, default: false, null: false
    end

    # Add index for performance
    create index(:users, [:password_change_required], prefix: "platform")
  end

  def down do
    alter table(:users, prefix: "platform") do
      remove :password_change_required
    end
  end
end
