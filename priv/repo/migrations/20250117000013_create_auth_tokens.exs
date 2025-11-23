defmodule Mcp.Repo.Migrations.CreateAuthTokens do
  use Ecto.Migration

  def up do
    create table(:auth_tokens, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :user_id, references(:users, type: :uuid, on_delete: :delete_all, prefix: "platform"),
        null: false

      add :token, :text, null: false
      add :type, :text, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :revoked_at, :utc_datetime_usec
      add :used_at, :utc_datetime_usec
      add :context, :jsonb, default: "{}"
      add :device_info, :jsonb, default: "{}"

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes
    create unique_index(:auth_tokens, [:token], prefix: "platform")
    create index(:auth_tokens, [:user_id], prefix: "platform")
    create index(:auth_tokens, [:type], prefix: "platform")
    create index(:auth_tokens, [:expires_at], prefix: "platform")
    create index(:auth_tokens, [:revoked_at], prefix: "platform")

    # Add constraint for token types
    execute """
    ALTER TABLE platform.auth_tokens
    ADD CONSTRAINT auth_tokens_type_check
    CHECK (type IN ('access', 'refresh', 'reset', 'verification', 'session'))
    """
  end

  def down do
    drop table(:auth_tokens, prefix: "platform")
  end
end
