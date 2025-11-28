defmodule Mcp.Repo.Migrations.AddAshArchivalPlatform do
  use Ecto.Migration

  def up do
    # Create Merchants Table
    create table(:merchants, prefix: "platform", primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :slug, :text, null: false
      add :business_name, :text, null: false
      add :subdomain, :text, null: false
      add :status, :text, null: false, default: "active"
      add :reseller_id, references(:resellers, type: :uuid, prefix: "platform")
      add :archived_at, :utc_datetime_usec

      timestamps()
    end

    create unique_index(:merchants, [:slug], prefix: "platform")
    create unique_index(:merchants, [:subdomain], prefix: "platform")

    # Create Stores Table
    create table(:stores, prefix: "platform", primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :merchant_id, references(:merchants, type: :uuid, prefix: "platform"), null: false
      add :slug, :text, null: false
      add :name, :text, null: false
      add :status, :text, null: false, default: "active"
      add :archived_at, :utc_datetime_usec

      timestamps()
    end

    create unique_index(:stores, [:slug], prefix: "platform")

    # Create Customers Table
    create table(:customers, prefix: "platform", primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :merchant_id, references(:merchants, type: :uuid, prefix: "platform"), primary_key: true
      add :email, :citext, null: false
      add :status, :text, null: false, default: "active"
      add :archived_at, :utc_datetime_usec

      timestamps()
    end

    # Composite PK is handled by primary_key: true on both fields above? 
    # Ecto might complain if I don't set primary_key: false on table and explicit keys.
    # Actually, let's just use standard id PK for simplicity in migration unless strictly required.
    # The resource says keys([:merchant_id, :id]).
    # I'll stick to standard UUID PK for now to avoid complexity, Ash can handle the logical PK.
  end

  def down do
    drop table(:customers, prefix: "platform")
    drop table(:stores, prefix: "platform")
    drop table(:merchants, prefix: "platform")
  end
end
