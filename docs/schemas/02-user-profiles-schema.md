# User Profiles Schema

**Entity:** `platform.user_profiles`
**Purpose:** Entity-scoped user identity (name, avatar, role per entity)
**Ash Resource:** `Mcp.Auth.UserProfile`

---

## Database Schema

```sql
CREATE TABLE platform.user_profiles (
  -- Primary Key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- User reference (global auth)
  user_id UUID NOT NULL REFERENCES platform.users(id) ON DELETE CASCADE,

  -- Entity reference (polymorphic)
  entity_type TEXT NOT NULL CHECK (entity_type IN ('platform', 'tenant', 'developer', 'reseller', 'merchant', 'store')),
  entity_id UUID NOT NULL,

  -- Profile data (entity-specific identity)
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  nickname TEXT,  -- ✅ Optional display name (defaults to first name if empty)
  avatar_url TEXT,  -- ✅ S3/MinIO URL or external URL (Gravatar, social media)
  bio TEXT CHECK (LENGTH(bio) <= 1000),  -- ✅ Max 1000 characters (LinkedIn-style)
  title TEXT,  -- Job title (e.g., "Senior Developer", "Store Manager")

  -- Contact info (entity-specific)
  phone TEXT,  -- ✅ E.164 format validation (+1234567890)
  contact_email TEXT,  -- Different from login email
  timezone TEXT DEFAULT 'UTC',

  -- Preferences (entity-specific UI settings)
  preferences JSONB DEFAULT '{}',

  -- Role flags
  is_admin BOOLEAN DEFAULT false,  -- Entity admin
  is_developer BOOLEAN DEFAULT false,  -- Developer portal access

  -- Status
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'invited', 'pending')),

  -- Invitation tracking
  invited_by UUID REFERENCES platform.users(id),
  invitation_token TEXT,
  invitation_sent_at TIMESTAMP,
  invitation_expires_at TIMESTAMP,
  joined_at TIMESTAMP,

  -- Timestamps
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

  -- Constraints
  UNIQUE(user_id, entity_type, entity_id)  -- One profile per user per entity
);

-- Indexes
CREATE INDEX idx_user_profiles_user_id ON platform.user_profiles(user_id);
CREATE INDEX idx_user_profiles_entity ON platform.user_profiles(entity_type, entity_id);
CREATE INDEX idx_user_profiles_status ON platform.user_profiles(status);
CREATE INDEX idx_user_profiles_is_admin ON platform.user_profiles(is_admin) WHERE is_admin = true;
CREATE INDEX idx_user_profiles_is_developer ON platform.user_profiles(is_developer) WHERE is_developer = true;
CREATE INDEX idx_user_profiles_invitation_token ON platform.user_profiles(invitation_token) WHERE invitation_token IS NOT NULL;
```

---

## Ash Resource Definition

```elixir
defmodule Mcp.Auth.UserProfile do
  use Ash.Resource,
    domain: Mcp.Auth,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPaperTrail]

  postgres do
    table "user_profiles"
    repo Mcp.Repo
    schema "platform"
  end

  attributes do
    uuid_primary_key :id

    attribute :user_id, :uuid, allow_nil?: false

    attribute :entity_type, :atom do
      constraints one_of: [:platform, :tenant, :developer, :reseller, :merchant, :store]
      allow_nil? false
    end

    attribute :entity_id, :uuid, allow_nil?: false

    # Profile data
    attribute :first_name, :string, allow_nil?: false, public?: true
    attribute :last_name, :string, allow_nil?: false, public?: true
    attribute :nickname, :string, public?: true
    attribute :avatar_url, :string, public?: true
    attribute :bio, :string, public?: true
    attribute :title, :string, public?: true

    # Contact
    attribute :phone, :string, public?: true
    attribute :contact_email, :string, public?: true
    attribute :timezone, :string, default: "UTC", public?: true

    # Preferences
    attribute :preferences, :map, default: %{}, public?: true

    # Role flags
    attribute :is_admin, :boolean, default: false, public?: true
    attribute :is_developer, :boolean, default: false, public?: true

    # Status
    attribute :status, :atom do
      constraints one_of: [:active, :suspended, :invited, :pending]
      default :active
    end

    # Invitation
    attribute :invited_by, :uuid
    attribute :invitation_token, :string, sensitive?: true
    attribute :invitation_sent_at, :utc_datetime_usec
    attribute :invitation_expires_at, :utc_datetime_usec
    attribute :joined_at, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :user, Mcp.Auth.User
    has_many :team_memberships, Mcp.Teams.TeamMember
    has_many :teams, Mcp.Teams.Team do
      through [:team_memberships, :team]
    end
  end

  identities do
    identity :unique_user_per_entity, [:user_id, :entity_type, :entity_id]
  end

  actions do
    defaults [:read, :destroy]

    create :invite do
      accept [:entity_type, :entity_id, :first_name, :last_name, :contact_email, :is_admin, :is_developer]
      argument :invited_by_user_id, :uuid, allow_nil?: false

      change fn changeset, context ->
        changeset
        |> Ash.Changeset.change_attribute(:status, :invited)
        |> Ash.Changeset.change_attribute(:invitation_token, generate_token())
        |> Ash.Changeset.change_attribute(:invitation_sent_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:invitation_expires_at, DateTime.add(DateTime.utc_now(), 86_400, :second))
        |> Ash.Changeset.change_attribute(:invited_by, context[:invited_by_user_id])
      end
    end

    update :accept_invitation do
      accept [:first_name, :last_name, :nickname, :avatar_url, :phone, :timezone]
      argument :user_id, :uuid, allow_nil?: false

      change fn changeset, context ->
        changeset
        |> Ash.Changeset.change_attribute(:user_id, context[:user_id])
        |> Ash.Changeset.change_attribute(:status, :active)
        |> Ash.Changeset.change_attribute(:joined_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:invitation_token, nil)
      end
    end

    update :update_profile do
      accept [:first_name, :last_name, :nickname, :avatar_url, :bio, :title, :phone, :contact_email, :timezone, :preferences]
    end

    update :toggle_admin do
      accept []
      argument :is_admin, :boolean, allow_nil?: false
      change set_attribute(:is_admin, arg(:is_admin))
    end

    update :toggle_developer do
      accept []
      argument :is_developer, :boolean, allow_nil?: false
      change set_attribute(:is_developer, arg(:is_developer))
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor(:user)
    end

    policy action_type(:update) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if entity_admin?()
    end

    policy action(:toggle_admin) do
      authorize_if entity_admin?()
    end

    policy action(:toggle_developer) do
      authorize_if entity_admin?()
    end
  end

  code_interface do
    define :invite, args: [:entity_type, :entity_id, :first_name, :last_name, :contact_email]
    define :accept_invitation, args: [:user_id]
    define :update_profile
    define :toggle_admin, args: [:is_admin]
    define :toggle_developer, args: [:is_developer]
  end
end
```

---

## Relationships

**Belongs To:**
- `user` → Global authentication record

**Has Many:**
- `team_memberships` → Teams this profile belongs to
- `api_keys` → API keys created or assigned to this profile (if developer/admin)

---

## Business Rules

1. **One profile per user per entity:** User can have multiple profiles (one per tenant, merchant, etc.)
2. **Profile isolation:** Tenant A admin cannot see user's profile in Merchant B
3. **✅ Nickname defaults:** If nickname is empty, display name = first_name (e.g., "Alice")
4. **✅ Avatar storage:** Support both S3/MinIO uploads AND external URLs (Gravatar, social media). Validate URLs for SSRF protection.
5. **✅ Bio character limit:** Maximum 1000 characters (enforced at database and application level)
6. **✅ Phone format:** E.164 international format (+1234567890). Requires country code dropdown in UI.
7. **Admin designation:** Only entity admin can promote/demote other users to admin
8. **Developer access:** Only entity admin can toggle developer portal access
9. **Invitation expiry:** 24 hours from sent_at
10. **Status transitions:** invited → active (on acceptance), active ↔ suspended (by admin)
11. **Profile deletion:** When user leaves entity, profile is soft-deleted (status: deleted)

---

## Data Privacy

- **Profile data is entity-scoped:** Merchant A sees "Chef Alice", Tenant B sees "Alice Smith"
- **No cross-entity leakage:** Avatar URL, bio, title are all separate per entity
- **Contact email optional:** Different from login email, used for entity-specific communication
- **Preferences per entity:** UI settings, notifications, language preferences are context-specific

---

## Invitation Flow

1. Entity admin invites user → Profile created with status: 'invited'
2. Invitation email sent with token (24-hour expiry)
3. User clicks link → Redirected to acceptance page
4. User completes profile (first/last name, avatar, etc.)
5. Profile status: 'invited' → 'active'
6. User can now access entity

---

## ✅ Preferences Schema (JSONB)

The `preferences` column stores entity-specific user preferences in three categories:

### UI Preferences
```json
{
  "ui": {
    "theme": "dark",              // "light", "dark", "system"
    "language": "en",             // ISO 639-1 language code
    "timezone": "America/New_York",  // IANA timezone
    "date_format": "MM/DD/YYYY"   // User's preferred date format
  }
}
```

### Notification Preferences
```json
{
  "notifications": {
    "email": true,                // Email notifications enabled
    "sms": false,                 // SMS notifications enabled
    "in_app": true,               // In-app notifications enabled
    "digest_frequency": "daily"   // "realtime", "hourly", "daily", "weekly"
  }
}
```

### Accessibility Preferences
```json
{
  "accessibility": {
    "screen_reader": false,       // Screen reader optimization
    "font_size": "medium",        // "small", "medium", "large", "x-large"
    "high_contrast": false,       // High contrast mode
    "reduced_motion": false       // Reduce animations/transitions
  }
}
```

### Full Example
```json
{
  "ui": {
    "theme": "dark",
    "language": "en",
    "timezone": "America/New_York",
    "date_format": "MM/DD/YYYY"
  },
  "notifications": {
    "email": true,
    "sms": false,
    "in_app": true,
    "digest_frequency": "daily"
  },
  "accessibility": {
    "screen_reader": false,
    "font_size": "medium",
    "high_contrast": false,
    "reduced_motion": false
  }
}
```
