defmodule Mcp.Repo.Migrations.CreateUserProfiles do
  use Ecto.Migration

  def up do
    create table(:user_profiles, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # User reference
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all, prefix: "platform"),
        null: false

      # Entity reference (polymorphic)
      add :entity_type, :text, null: false
      add :entity_id, :uuid, null: false

      # Profile data
      add :first_name, :text, null: false
      add :last_name, :text, null: false
      add :nickname, :text
      add :avatar_url, :text
      add :bio, :text
      add :title, :text

      # Contact info
      add :phone, :text
      add :contact_email, :text
      add :timezone, :text, default: "UTC"

      # Preferences
      add :preferences, :jsonb, default: "{}"

      # Role flags
      add :is_admin, :boolean, default: false
      add :is_developer, :boolean, default: false

      # Status
      add :status, :text, null: false, default: "active"

      # Invitation tracking
      add :invited_by, references(:users, type: :uuid, prefix: "platform")
      add :invitation_token, :text
      add :invitation_sent_at, :utc_datetime
      add :invitation_expires_at, :utc_datetime
      add :joined_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Indexes
    create index(:user_profiles, [:user_id], prefix: "platform")
    create index(:user_profiles, [:entity_type, :entity_id], prefix: "platform")
    create index(:user_profiles, [:status], prefix: "platform")
    create index(:user_profiles, [:is_admin], where: "is_admin = true", prefix: "platform")
    create index(:user_profiles, [:is_developer], where: "is_developer = true", prefix: "platform")

    create index(:user_profiles, [:invitation_token],
      where: "invitation_token IS NOT NULL",
      prefix: "platform"
    )

    create unique_index(:user_profiles, [:user_id, :entity_type, :entity_id], prefix: "platform")

    # Add constraints
    execute """
    ALTER TABLE platform.user_profiles
    ADD CONSTRAINT user_profiles_entity_type_check
    CHECK (entity_type IN ('platform', 'tenant', 'developer', 'reseller', 'merchant', 'store'))
    """

    execute """
    ALTER TABLE platform.user_profiles
    ADD CONSTRAINT user_profiles_status_check
    CHECK (status IN ('active', 'suspended', 'invited', 'pending'))
    """

    execute """
    ALTER TABLE platform.user_profiles
    ADD CONSTRAINT user_profiles_bio_length_check
    CHECK (LENGTH(bio) <= 1000)
    """
  end

  def down do
    drop table(:user_profiles, prefix: "platform")
  end
end
