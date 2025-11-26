defmodule Mcp.Repo.Migrations.CreateApiKeysAndTeams do
  use Ecto.Migration

  def up do
    # ========================================
    # API KEYS
    # ========================================
    create table(:api_keys, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Owner (user_profile or developer)
      add :owner_type, :text, null: false
      add :owner_id, :uuid, null: false

      # Key data
      add :name, :text, null: false
      add :key_prefix, :text, null: false
      add :hashed_key, :text, null: false

      # Permissions
      add :scopes, {:array, :text}, default: []
      add :permissions, :jsonb, default: "{}"

      # Usage tracking
      add :last_used_at, :utc_datetime
      add :usage_count, :integer, default: 0

      # Limits
      add :rate_limit, :integer
      add :daily_quota, :integer
      add :monthly_quota, :integer

      # Expiration
      add :expires_at, :utc_datetime

      # Status
      add :status, :text, null: false, default: "active"

      # IP restrictions
      add :allowed_ips, {:array, :text}

      timestamps(type: :utc_datetime)
    end

    # FK constraint
    execute """
    ALTER TABLE platform.api_keys
    ADD CONSTRAINT api_keys_owner_type_fkey
    FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value)
    """

    # Indexes
    create unique_index(:api_keys, [:key_prefix], prefix: "platform")
    create index(:api_keys, [:owner_type, :owner_id], prefix: "platform")
    create index(:api_keys, [:status], prefix: "platform")
    create index(:api_keys, [:expires_at], where: "expires_at IS NOT NULL", prefix: "platform")

    # Add constraint
    execute """
    ALTER TABLE platform.api_keys
    ADD CONSTRAINT api_keys_status_check
    CHECK (status IN ('active', 'revoked', 'expired'))
    """

    # ========================================
    # TEAMS
    # ========================================
    create table(:teams, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Entity reference
      add :entity_type, :text, null: false
      add :entity_id, :uuid, null: false

      # Team data
      add :name, :text, null: false
      add :slug, :text, null: false
      add :description, :text

      # Settings
      add :settings, :jsonb, default: "{}"

      # Status
      add :status, :text, null: false, default: "active"

      timestamps(type: :utc_datetime)
    end

    # FK constraint
    execute """
    ALTER TABLE platform.teams
    ADD CONSTRAINT teams_entity_type_fkey
    FOREIGN KEY (entity_type) REFERENCES platform.entity_types(value)
    """

    # Indexes
    create index(:teams, [:entity_type, :entity_id], prefix: "platform")
    create unique_index(:teams, [:entity_type, :entity_id, :slug], prefix: "platform")
    create index(:teams, [:status], prefix: "platform")

    # Add constraint
    execute """
    ALTER TABLE platform.teams
    ADD CONSTRAINT teams_status_check
    CHECK (status IN ('active', 'archived'))
    """

    # ========================================
    # TEAM MEMBERS
    # ========================================
    create table(:team_members, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :team_id, references(:teams, type: :uuid, on_delete: :delete_all, prefix: "platform"),
        null: false

      add :user_profile_id,
          references(:user_profiles, type: :uuid, on_delete: :delete_all, prefix: "platform"),
          null: false

      # Role
      add :role, :text, null: false, default: "member"

      # Permissions
      add :permissions, :jsonb, default: "{}"

      # Invitation
      add :invited_by, references(:user_profiles, type: :uuid, prefix: "platform")
      add :joined_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Indexes
    create index(:team_members, [:team_id], prefix: "platform")
    create index(:team_members, [:user_profile_id], prefix: "platform")
    create unique_index(:team_members, [:team_id, :user_profile_id], prefix: "platform")

    # Add constraint
    execute """
    ALTER TABLE platform.team_members
    ADD CONSTRAINT team_members_role_check
    CHECK (role IN ('owner', 'admin', 'member', 'viewer'))
    """
  end

  def down do
    drop table(:team_members, prefix: "platform")
    drop table(:teams, prefix: "platform")
    drop table(:api_keys, prefix: "platform")
  end
end
