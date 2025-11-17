# Platform Users Schema

**Entity:** `platform.users`
**Purpose:** Global authentication layer (email, password, 2FA)
**Ash Resource:** `Mcp.Auth.User`

---

## Database Schema

```sql
CREATE TABLE platform.users (
  -- Primary Key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Authentication (ash_authentication)
  email CITEXT NOT NULL UNIQUE,
  hashed_password TEXT NOT NULL,

  -- 2FA (ash_authentication)
  totp_secret TEXT,  -- Encrypted TOTP secret for authenticator apps
  backup_codes TEXT[], -- Encrypted array of backup codes
  confirmed_at TIMESTAMP,

  -- OAuth (ash_authentication)
  oauth_tokens JSONB DEFAULT '{}',  -- {google: {...}, github: {...}}

  -- Session tracking
  last_sign_in_at TIMESTAMP,
  last_sign_in_ip INET,
  sign_in_count INTEGER DEFAULT 0,

  -- Account status
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')),

  -- Timestamps
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_users_email ON platform.users(email);
CREATE INDEX idx_users_status ON platform.users(status);
CREATE INDEX idx_users_created_at ON platform.users(created_at);
```

---

## Ash Resource Definition

```elixir
defmodule Mcp.Auth.User do
  use Ash.Resource,
    domain: Mcp.Auth,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  postgres do
    table "users"
    repo Mcp.Repo
    schema "platform"
  end

  authentication do
    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
        hash_provider AshAuthentication.BcryptProvider
        confirmation_required? true
      end

      oauth2 :google do
        client_id &get_config/2
        client_secret &get_config/2
        redirect_uri &get_config/2
      end

      oauth2 :github do
        client_id &get_config/2
        client_secret &get_config/2
        redirect_uri &get_config/2
      end
    end

    tokens do
      enabled? true
      token_resource Mcp.Auth.Token
      signing_secret &get_config/2
    end

    add_ons do
      confirmation :confirm do
        monitor_fields [:email]
        sender Mcp.Auth.ConfirmationSender
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :totp_secret, :string do
      sensitive? true
    end

    attribute :backup_codes, {:array, :string} do
      sensitive? true
    end

    attribute :confirmed_at, :utc_datetime_usec
    attribute :oauth_tokens, :map, default: %{}
    attribute :last_sign_in_at, :utc_datetime_usec
    attribute :last_sign_in_ip, :string
    attribute :sign_in_count, :integer, default: 0

    attribute :status, :atom do
      constraints one_of: [:active, :suspended, :deleted]
      default :active
    end

    timestamps()
  end

  relationships do
    has_many :user_profiles, Mcp.Auth.UserProfile
  end

  actions do
    defaults [:read]

    read :get_by_email do
      argument :email, :ci_string, allow_nil?: false
      filter expr(email == ^arg(:email))
    end

    create :register do
      accept [:email]
      argument :password, :string, allow_nil?: false, sensitive?: true
      argument :password_confirmation, :string, allow_nil?: false, sensitive?: true
      change AshAuthentication.Strategy.Password.HashPasswordChange
    end

    update :suspend do
      accept []
      change set_attribute(:status, :suspended)
    end
  end

  code_interface do
    define :get_by_email, args: [:email]
    define :register, args: [:email, :password, :password_confirmation]
    define :suspend
  end
end
```

---

## Relationships

**Has Many:**
- `user_profiles` → Entity-scoped profiles (one per entity user belongs to)

**Has Many Through:**
- `contexts` → All entities this user has access to (via user_profiles)

---

## Business Rules

1. **Email uniqueness:** Global across entire platform
2. **Password requirements:** ✅ Min 8 chars, any mix of character types (uppercase, lowercase, numbers, special chars) - Balance of security and UX
3. **2FA enrollment:** Optional for users, required by entity policy
4. **OAuth providers:** ✅ Google and GitHub only - No additional providers at launch
5. **Account suspension:** Suspends all profiles across all entities
6. **Account deletion:** ✅ Soft delete (status: deleted, data retained for 90 days for GDPR compliance)
7. **Email confirmation:** Required before first login
8. **Password reset:** Global (changes password for all contexts)

---

## Security Considerations

- Passwords hashed with bcrypt (cost factor: 12)
- ✅ Password validation: Minimum 8 characters, must include mix of character types
- TOTP secrets encrypted at rest using Cloak (HashiCorp Vault)
- Backup codes encrypted and hashed
- OAuth tokens encrypted at rest
- Rate limiting on login attempts (5 per 15 minutes)
- Failed login tracking (lock after 5 failures)
- ✅ GDPR Compliance: Deleted user data retained for 90 days, then permanently purged

---

## Migrations Required

1. Create `platform` schema
2. Enable `citext` extension
3. Create `users` table
4. Create indexes
5. Set up row-level security (RLS) policies
6. Add background job for purging deleted users after 90 days (Oban)
