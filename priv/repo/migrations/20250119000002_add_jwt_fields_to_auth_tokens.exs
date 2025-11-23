defmodule Mcp.Repo.Migrations.AddJwtFieldsToAuthTokens do
  @moduledoc """
  Migration to add JWT-specific fields to the auth_tokens table.

  This migration adds support for:
  - JWT token identification (jti)
  - Session grouping (session_id)
  - Device fingerprinting (device_id)
  - Sliding refresh tracking (last_used_at)
  - JWT revocation tracking (type: :revoked_jwt)
  """

  use Ecto.Migration

  def up do
    alter table("platform.auth_tokens") do
      # JWT-specific fields
      add :jti, :string, null: true, comment: "JWT ID for token identification and revocation"
      add :session_id, :string, null: true, comment: "Session identifier for token grouping"

      add :device_id, :string,
        null: true,
        comment: "Device fingerprint for device-specific tokens"

      add :last_used_at, :utc_datetime_usec,
        null: true,
        comment: "Last time the token was used for sliding refresh"
    end

    # Create indexes for performance after adding columns
    create unique_index("auth_tokens", [:jti], where: "jti IS NOT NULL")
    create index("auth_tokens", [:session_id])
    create index("auth_tokens", [:device_id])
    create index("auth_tokens", [:user_id, :type, :revoked_at, :expires_at])
    create index("auth_tokens", [:type, :expires_at])

    # Update the type constraint to include revoked_jwt
    execute """
            ALTER TABLE auth_tokens
            DROP CONSTRAINT IF EXISTS auth_tokens_type_check
            """,
            ""

    execute """
            ALTER TABLE auth_tokens
            ADD CONSTRAINT auth_tokens_type_check
            CHECK (type IN ('access', 'refresh', 'reset', 'verification', 'session', 'revoked_jwt'))
            """,
            ""
  end

  def down do
    alter table("platform.auth_tokens") do
      remove :jti
      remove :session_id
      remove :device_id
      remove :last_used_at
    end

    # Update the type constraint to remove revoked_jwt
    execute """
            ALTER TABLE auth_tokens
            DROP CONSTRAINT IF EXISTS auth_tokens_type_check
            """,
            ""

    execute """
            ALTER TABLE auth_tokens
            ADD CONSTRAINT auth_tokens_type_check
            CHECK (type IN ('access', 'refresh', 'reset', 'verification', 'session'))
            """,
            ""
  end
end
