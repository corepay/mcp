defmodule Mcp.Repo.Migrations.CreatePolymorphicSharedEntities do
  use Ecto.Migration

  def up do
    # ========================================
    # ADDRESSES
    # ========================================
    create table(:addresses, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Polymorphic association
      add :owner_type, :text, null: false
      add :owner_id, :uuid, null: false

      # Address type
      add :address_type, :text

      # Address data
      add :label, :text
      add :line1, :text, null: false
      add :line2, :text
      add :city, :text, null: false
      add :state, :text
      add :postal_code, :text, null: false
      add :country, :text, null: false, default: "US"

      # Geocoding (PostGIS)
      # add :location, :geometry

      # Validation
      add :is_verified, :boolean, default: false
      add :verified_at, :utc_datetime
      add :verification_method, :text

      # Default flags
      add :is_primary, :boolean, default: false

      # Metadata
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    # FK constraints
    execute """
    ALTER TABLE platform.addresses
    ADD CONSTRAINT addresses_owner_type_fkey
    FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value)
    """

    execute """
    ALTER TABLE platform.addresses
    ADD CONSTRAINT addresses_address_type_fkey
    FOREIGN KEY (address_type) REFERENCES platform.address_types(value)
    """

    # Indexes
    create index(:addresses, [:owner_type, :owner_id], prefix: "platform")
    create index(:addresses, [:address_type], prefix: "platform")

    create index(:addresses, [:owner_type, :owner_id, :is_primary],
             where: "is_primary = true",
             prefix: "platform"
           )

    # execute "CREATE INDEX idx_addresses_location ON platform.addresses USING GIST(location)"

    # Enable RLS
    execute "ALTER TABLE platform.addresses ENABLE ROW LEVEL SECURITY"

    # ========================================
    # EMAILS
    # ========================================
    create table(:emails, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Polymorphic association
      add :owner_type, :text, null: false
      add :owner_id, :uuid, null: false

      # Email type
      add :email_type, :text

      # Email data
      add :label, :text
      add :email, :citext, null: false

      # Verification
      add :is_verified, :boolean, default: false
      add :verified_at, :utc_datetime
      add :verification_token, :text
      add :verification_sent_at, :utc_datetime

      # Default flag
      add :is_primary, :boolean, default: false

      # Email preferences
      add :can_receive_marketing, :boolean, default: false
      add :can_receive_transactional, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    # FK constraints
    execute """
    ALTER TABLE platform.emails
    ADD CONSTRAINT emails_owner_type_fkey
    FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value)
    """

    execute """
    ALTER TABLE platform.emails
    ADD CONSTRAINT emails_email_type_fkey
    FOREIGN KEY (email_type) REFERENCES platform.email_types(value)
    """

    # Indexes
    create index(:emails, [:owner_type, :owner_id], prefix: "platform")
    create index(:emails, [:email], prefix: "platform")
    create index(:emails, [:email_type], prefix: "platform")

    create index(:emails, [:owner_type, :owner_id, :is_primary],
             where: "is_primary = true",
             prefix: "platform"
           )

    # Enable RLS
    execute "ALTER TABLE platform.emails ENABLE ROW LEVEL SECURITY"

    # ========================================
    # PHONES
    # ========================================
    create table(:phones, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Polymorphic association
      add :owner_type, :text, null: false
      add :owner_id, :uuid, null: false

      # Phone type
      add :phone_type, :text

      # Phone data
      add :label, :text
      add :phone, :text, null: false
      add :country_code, :text, default: "US"
      add :extension, :text

      # Verification
      add :is_verified, :boolean, default: false
      add :verified_at, :utc_datetime
      add :verification_code, :text
      add :verification_sent_at, :utc_datetime

      # Capabilities
      add :can_sms, :boolean, default: false
      add :can_voice, :boolean, default: true

      # Default flag
      add :is_primary, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    # FK constraints
    execute """
    ALTER TABLE platform.phones
    ADD CONSTRAINT phones_owner_type_fkey
    FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value)
    """

    execute """
    ALTER TABLE platform.phones
    ADD CONSTRAINT phones_phone_type_fkey
    FOREIGN KEY (phone_type) REFERENCES platform.phone_types(value)
    """

    # Indexes
    create index(:phones, [:owner_type, :owner_id], prefix: "platform")
    create index(:phones, [:phone], prefix: "platform")
    create index(:phones, [:phone_type], prefix: "platform")
    create index(:phones, [:can_sms], where: "can_sms = true", prefix: "platform")

    # Enable RLS
    execute "ALTER TABLE platform.phones ENABLE ROW LEVEL SECURITY"

    # ========================================
    # SOCIALS
    # ========================================
    create table(:socials, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Polymorphic association
      add :owner_type, :text, null: false
      add :owner_id, :uuid, null: false

      # Platform
      add :platform, :text, null: false

      # Social data
      add :username, :text, null: false
      add :url, :text, null: false

      # Verification
      add :is_verified, :boolean, default: false
      add :verified_at, :utc_datetime

      # Visibility
      add :is_public, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    # FK constraints
    execute """
    ALTER TABLE platform.socials
    ADD CONSTRAINT socials_owner_type_fkey
    FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value)
    """

    execute """
    ALTER TABLE platform.socials
    ADD CONSTRAINT socials_platform_fkey
    FOREIGN KEY (platform) REFERENCES platform.social_platforms(value)
    """

    # Indexes
    create index(:socials, [:owner_type, :owner_id], prefix: "platform")
    create index(:socials, [:platform], prefix: "platform")
    create index(:socials, [:is_public], where: "is_public = true", prefix: "platform")
    create unique_index(:socials, [:owner_type, :owner_id, :platform], prefix: "platform")

    # Enable RLS
    execute "ALTER TABLE platform.socials ENABLE ROW LEVEL SECURITY"

    # ========================================
    # IMAGES
    # ========================================
    create table(:images, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Polymorphic association
      add :owner_type, :text, null: false
      add :owner_id, :uuid, null: false

      # Image type
      add :image_type, :text

      # Storage (S3/MinIO)
      add :storage_provider, :text, default: "s3"
      add :storage_bucket, :text, null: false
      add :storage_key, :text, null: false

      # File metadata
      add :filename, :text, null: false
      add :mime_type, :text, null: false
      add :file_size, :integer, null: false
      add :width, :integer
      add :height, :integer
      add :alt_text, :text

      # CDN/Access
      add :public_url, :text
      add :is_public, :boolean, default: false

      # Processing
      add :is_processed, :boolean, default: false
      add :thumbnails, :jsonb, default: "{}"

      # Ordering
      add :sort_order, :integer, default: 0

      # Metadata
      add :metadata, :jsonb, default: "{}"

      timestamps(type: :utc_datetime)
    end

    # FK constraints
    execute """
    ALTER TABLE platform.images
    ADD CONSTRAINT images_owner_type_fkey
    FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value)
    """

    execute """
    ALTER TABLE platform.images
    ADD CONSTRAINT images_image_type_fkey
    FOREIGN KEY (image_type) REFERENCES platform.image_types(value)
    """

    # Indexes
    create index(:images, [:owner_type, :owner_id], prefix: "platform")
    create index(:images, [:image_type], prefix: "platform")
    create index(:images, [:is_public], where: "is_public = true", prefix: "platform")
    create index(:images, [:storage_provider, :storage_bucket, :storage_key], prefix: "platform")

    # Enable RLS
    execute "ALTER TABLE platform.images ENABLE ROW LEVEL SECURITY"

    # ========================================
    # DOCUMENTS
    # ========================================
    create table(:documents, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Polymorphic association
      add :owner_type, :text, null: false
      add :owner_id, :uuid, null: false

      # Document type
      add :document_type, :text

      # Storage (encrypted)
      add :storage_provider, :text, default: "s3"
      add :storage_bucket, :text, null: false
      add :storage_key, :text, null: false
      add :encryption_key_id, :text

      # File metadata
      add :filename, :text, null: false
      add :mime_type, :text, null: false
      add :file_size, :integer, null: false

      # Classification
      add :category, :text
      add :tags, {:array, :text}

      # Security
      add :is_sensitive, :boolean, default: true
      add :requires_approval, :boolean, default: false
      add :approved_by, references(:users, type: :uuid, prefix: "platform")
      add :approved_at, :utc_datetime

      # Retention
      add :retention_policy, :text
      add :expires_at, :utc_datetime

      # Metadata
      add :metadata, :jsonb, default: "{}"

      timestamps(type: :utc_datetime)
    end

    # FK constraints
    execute """
    ALTER TABLE platform.documents
    ADD CONSTRAINT documents_owner_type_fkey
    FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value)
    """

    execute """
    ALTER TABLE platform.documents
    ADD CONSTRAINT documents_document_type_fkey
    FOREIGN KEY (document_type) REFERENCES platform.document_types(value)
    """

    # Indexes
    create index(:documents, [:owner_type, :owner_id], prefix: "platform")
    create index(:documents, [:document_type], prefix: "platform")
    create index(:documents, [:expires_at], where: "expires_at IS NOT NULL", prefix: "platform")

    execute "CREATE INDEX idx_documents_tags ON platform.documents USING GIN(tags)"

    # Enable RLS
    execute "ALTER TABLE platform.documents ENABLE ROW LEVEL SECURITY"

    # ========================================
    # TODOS
    # ========================================
    create table(:todos, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Owner
      add :owner_type, :text, null: false
      add :owner_id, :uuid, null: false

      # Related entity
      add :related_to_type, :text
      add :related_to_id, :uuid

      # Todo data
      add :title, :text, null: false
      add :description, :text
      add :status, :text, default: "pending"
      add :priority, :text, default: "medium"

      # Dates
      add :due_at, :utc_datetime
      add :completed_at, :utc_datetime

      # Assignment
      add :assigned_to, references(:users, type: :uuid, prefix: "platform")

      # Metadata
      add :tags, {:array, :text}
      add :checklist, :jsonb, default: "[]"

      timestamps(type: :utc_datetime)
    end

    # FK constraints
    execute """
    ALTER TABLE platform.todos
    ADD CONSTRAINT todos_owner_type_fkey
    FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value)
    """

    execute """
    ALTER TABLE platform.todos
    ADD CONSTRAINT todos_related_to_type_fkey
    FOREIGN KEY (related_to_type) REFERENCES platform.entity_types(value)
    """

    execute """
    ALTER TABLE platform.todos
    ADD CONSTRAINT todos_status_fkey
    FOREIGN KEY (status) REFERENCES platform.status_types(value)
    """

    # Indexes
    create index(:todos, [:owner_type, :owner_id], prefix: "platform")
    create index(:todos, [:related_to_type, :related_to_id], prefix: "platform")
    create index(:todos, [:status], prefix: "platform")
    create index(:todos, [:due_at], where: "due_at IS NOT NULL", prefix: "platform")
    create index(:todos, [:assigned_to], where: "assigned_to IS NOT NULL", prefix: "platform")

    # Enable RLS
    execute "ALTER TABLE platform.todos ENABLE ROW LEVEL SECURITY"

    # ========================================
    # NOTES
    # ========================================
    create table(:notes, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Owner
      add :owner_type, :text, null: false
      add :owner_id, :uuid, null: false

      # Related entity
      add :related_to_type, :text
      add :related_to_id, :uuid

      # Note data
      add :title, :text
      add :content, :text, null: false

      # Classification
      add :category, :text
      add :tags, {:array, :text}

      # Privacy
      add :is_private, :boolean, default: true

      # Pinning
      add :is_pinned, :boolean, default: false

      # Metadata
      add :metadata, :jsonb, default: "{}"

      timestamps(type: :utc_datetime)
    end

    # FK constraints
    execute """
    ALTER TABLE platform.notes
    ADD CONSTRAINT notes_owner_type_fkey
    FOREIGN KEY (owner_type) REFERENCES platform.entity_types(value)
    """

    execute """
    ALTER TABLE platform.notes
    ADD CONSTRAINT notes_related_to_type_fkey
    FOREIGN KEY (related_to_type) REFERENCES platform.entity_types(value)
    """

    # Indexes
    create index(:notes, [:owner_type, :owner_id], prefix: "platform")
    create index(:notes, [:related_to_type, :related_to_id], prefix: "platform")
    create index(:notes, [:is_pinned], where: "is_pinned = true", prefix: "platform")

    execute "CREATE INDEX idx_notes_tags ON platform.notes USING GIN(tags)"

    execute "CREATE INDEX idx_notes_content_search ON platform.notes USING GIN(to_tsvector('english', content))"

    # Enable RLS
    execute "ALTER TABLE platform.notes ENABLE ROW LEVEL SECURITY"
  end

  def down do
    drop table(:notes, prefix: "platform")
    drop table(:todos, prefix: "platform")
    drop table(:documents, prefix: "platform")
    drop table(:images, prefix: "platform")
    drop table(:socials, prefix: "platform")
    drop table(:phones, prefix: "platform")
    drop table(:emails, prefix: "platform")
    drop table(:addresses, prefix: "platform")
  end
end
