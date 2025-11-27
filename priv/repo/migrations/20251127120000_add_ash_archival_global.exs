defmodule Mcp.Repo.Migrations.AddAshArchivalGlobal do
  use Ecto.Migration

  def up do
    # Resellers table (Exists)
    alter table(:resellers, prefix: "platform") do
      add :archived_at, :utc_datetime_usec
    end

    # Developers table (Exists)
    alter table(:developers, prefix: "platform") do
      add :archived_at, :utc_datetime_usec
    end

    # MIDs table (Missing - Create)
    create table(:mids, prefix: "platform", primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :merchant_id, references(:merchants, type: :uuid, prefix: "platform"), null: false
      add :provider, :text, null: false
      add :mid_code, :text, null: false
      add :status, :text, null: false, default: "active"
      add :archived_at, :utc_datetime_usec

      timestamps()
    end

    # Vendors table (Missing - Create)
    create table(:vendors, prefix: "platform", primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :text, null: false
      add :slug, :text, null: false
      add :status, :text, null: false, default: "active"
      add :archived_at, :utc_datetime_usec

      timestamps()
    end

    create unique_index(:vendors, [:slug], prefix: "platform")
  end

  def down do
    alter table(:resellers, prefix: "platform") do
      remove :archived_at
    end

    alter table(:developers, prefix: "platform") do
      remove :archived_at
    end

    drop table(:mids, prefix: "platform")
    drop table(:vendors, prefix: "platform")
  end
end
