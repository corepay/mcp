defmodule Mcp.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def up do
    create table(:users, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Authentication (ash_authentication)
      add :email, :citext, null: false
      add :hashed_password, :text, null: false

      # 2FA (ash_authentication)
      add :totp_secret, :text
      add :backup_codes, {:array, :text}
      add :confirmed_at, :utc_datetime

      # OAuth (ash_authentication)
      add :oauth_tokens, :jsonb, default: "{}"

      # Session tracking
      add :last_sign_in_at, :utc_datetime
      add :last_sign_in_ip, :inet
      add :sign_in_count, :integer, default: 0

      # Account status
      add :status, :text, null: false, default: "active"

      timestamps(type: :utc_datetime)
    end

    # Indexes
    create unique_index(:users, [:email], prefix: "platform")
    create index(:users, [:status], prefix: "platform")
    create index(:users, [:created_at], prefix: "platform")

    # Add status check constraint
    execute """
    ALTER TABLE platform.users
    ADD CONSTRAINT users_status_check
    CHECK (status IN ('active', 'suspended', 'deleted'))
    """
  end

  def down do
    drop table(:users, prefix: "platform")
  end
end
