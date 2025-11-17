# Tenants Schema

**Entity:** `platform.tenants`
**Purpose:** Top-level entity in hierarchy (payment processor/platform customer)
**Ash Resource:** `Mcp.Tenants.Tenant`

---

## Database Schema

```sql
CREATE TABLE platform.tenants (
  -- Primary Key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identity
  slug TEXT NOT NULL UNIQUE,  -- URL-safe identifier (e.g., "acme")
  company_name TEXT NOT NULL,
  company_schema TEXT NOT NULL UNIQUE,  -- Database schema name (e.g., "acq_acme")

  -- Subdomain
  subdomain TEXT NOT NULL UNIQUE,  -- {slug}.base.do
  custom_domain TEXT UNIQUE,  -- Optional: portal.acme.com

  -- Subscription & Billing
  plan TEXT DEFAULT 'starter' CHECK (plan IN ('starter', 'professional', 'enterprise')),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'trial', 'suspended', 'canceled')),
  trial_ends_at TIMESTAMP,
  subscription_id TEXT,  -- External billing system ID

  -- Configuration
  settings JSONB DEFAULT '{}',  -- ✅ Business settings, feature flags, integrations, compliance
  branding JSONB DEFAULT '{}',  -- ✅ Logo, colors (extended palette), typography, custom CSS

  -- Payment Gateways (assigned by platform)
  assigned_gateway_ids UUID[],  -- Array of platform.payment_gateways.id

  -- Limits (plan-based)
  max_developers INTEGER DEFAULT 5,
  max_resellers INTEGER DEFAULT 10,
  max_merchants INTEGER DEFAULT 100,

  -- Onboarding
  onboarding_completed_at TIMESTAMP,
  onboarding_step TEXT,  -- Current step if incomplete

  -- Timestamps
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE UNIQUE INDEX idx_tenants_slug ON platform.tenants(slug);
CREATE UNIQUE INDEX idx_tenants_subdomain ON platform.tenants(subdomain);
CREATE UNIQUE INDEX idx_tenants_custom_domain ON platform.tenants(custom_domain) WHERE custom_domain IS NOT NULL;
CREATE INDEX idx_tenants_status ON platform.tenants(status);
CREATE INDEX idx_tenants_plan ON platform.tenants(plan);
```

---

## Tenant-Specific Schema

Each tenant gets its own PostgreSQL schema: `acq_{slug}`

```sql
-- Created during tenant onboarding via Reactor saga
CREATE SCHEMA acq_acme;

-- Tenant-specific tables (in acq_acme schema):
-- - developers
-- - resellers
-- - merchants
-- - mids
-- - stores
-- - customers
-- - vendors
-- - transactions (TimescaleDB hypertable)
-- - products
-- - etc.
```

---

## Ash Resource Definition

```elixir
defmodule Mcp.Tenants.Tenant do
  use Ash.Resource,
    domain: Mcp.Tenants,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshArchival]

  postgres do
    table "tenants"
    repo Mcp.Repo
    schema "platform"
  end

  attributes do
    uuid_primary_key :id

    attribute :slug, :string do
      allow_nil? false
      public? true
      constraints [match: ~r/^[a-z0-9-]+$/]
    end

    attribute :company_name, :string, allow_nil?: false, public?: true
    attribute :company_schema, :string, allow_nil?: false

    attribute :subdomain, :string do
      allow_nil? false
      constraints [match: ~r/^[a-z0-9-]+$/]
    end

    attribute :custom_domain, :string, public?: true

    attribute :plan, :atom do
      constraints one_of: [:starter, :professional, :enterprise]
      default :starter
      public?: true
    end

    attribute :status, :atom do
      constraints one_of: [:active, :trial, :suspended, :canceled]
      default :active
    end

    attribute :trial_ends_at, :utc_datetime_usec
    attribute :subscription_id, :string

    attribute :settings, :map, default: %{}, public?: true
    attribute :branding, :map, default: %{}, public?: true

    attribute :assigned_gateway_ids, {:array, :uuid}, default: []

    attribute :max_developers, :integer, default: 5
    attribute :max_resellers, :integer, default: 10
    attribute :max_merchants, :integer, default: 100

    attribute :onboarding_completed_at, :utc_datetime_usec
    attribute :onboarding_step, :string

    timestamps()
  end

  relationships do
    has_many :user_profiles, Mcp.Auth.UserProfile do
      filter expr(entity_type == :tenant and entity_id == ^id)
    end

    # Tenant-scoped entities (in tenant schema)
    # Note: These use MultiTenant context switching
    has_many :developers, Mcp.Developers.Developer
    has_many :resellers, Mcp.Resellers.Reseller
    has_many :merchants, Mcp.Merchants.Merchant
  end

  identities do
    identity :unique_slug, [:slug]
    identity :unique_subdomain, [:subdomain]
    identity :unique_company_schema, [:company_schema]
  end

  actions do
    defaults [:read, :destroy]

    create :onboard do
      accept [:slug, :company_name, :subdomain, :plan]
      argument :admin_user_id, :uuid, allow_nil?: false
      argument :gateway_ids, {:array, :uuid}, allow_nil?: false

      # This triggers OnboardingReactor saga
      change fn changeset, context ->
        slug = Ash.Changeset.get_attribute(changeset, :slug)

        changeset
        |> Ash.Changeset.change_attribute(:company_schema, "acq_#{slug}")
        |> Ash.Changeset.change_attribute(:assigned_gateway_ids, context[:gateway_ids])
        |> Ash.Changeset.change_attribute(:status, :trial)
        |> Ash.Changeset.change_attribute(:trial_ends_at, DateTime.add(DateTime.utc_now(), 14 * 86_400, :second))
        |> Ash.Changeset.after_action(fn _changeset, tenant ->
          # Trigger Reactor saga
          Reactor.run(Mcp.Tenants.OnboardingReactor, %{
            tenant: tenant,
            admin_user_id: context[:admin_user_id],
            gateway_ids: context[:gateway_ids]
          })
          {:ok, tenant}
        end)
      end
    end

    update :complete_onboarding do
      accept []
      change set_attribute(:onboarding_completed_at, &DateTime.utc_now/0)
      change set_attribute(:onboarding_step, nil)
    end

    update :update_branding do
      accept [:branding]
    end

    update :update_settings do
      accept [:settings]
    end

    update :assign_custom_domain do
      accept [:custom_domain]
      # This triggers CustomDomainProvisionReactor
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if platform_admin?()
      authorize_if has_profile_in_tenant?()
    end

    policy action(:onboard) do
      authorize_if platform_admin?()
    end

    policy action_type(:update) do
      authorize_if platform_admin?()
      authorize_if tenant_admin?()
    end
  end

  code_interface do
    define :onboard, args: [:slug, :company_name, :subdomain, :plan, :admin_user_id, :gateway_ids]
    define :complete_onboarding
    define :update_branding, args: [:branding]
    define :assign_custom_domain, args: [:custom_domain]
  end
end
```

---

## Relationships

**Has Many:**
- `user_profiles` (entity_type: tenant) → Tenant users
- `developers` → External developers with API access
- `resellers` → Reseller partners
- `merchants` → Merchant accounts

---

## Business Rules

1. **Slug uniqueness:** Globally unique, URL-safe (a-z, 0-9, hyphen)
2. **Subdomain auto-generated:** `{slug}.base.do`
3. **Schema isolation:** Each tenant gets `acq_{slug}` PostgreSQL schema
4. **✅ Trial period:** 14 days from creation (industry standard)
5. **✅ Plan limits:** Keep current defaults (5 developers, 10 resellers, 100 merchants for Starter)
6. **Payment gateways:** Assigned by platform admin during onboarding
7. **✅ Custom domain pricing:** Free with Professional plan, $10/month on Starter plan (covers CloudFlare SSL + DNS costs)
8. **✅ Onboarding steps:** Payment setup → Gateway configuration → Team invitation
9. **Onboarding saga:** Multi-step Reactor (create schema, run migrations, provision DNS, create admin profile, send welcome email)

---

## Onboarding Reactor Saga

```elixir
defmodule Mcp.Tenants.OnboardingReactor do
  use Reactor, extensions: [Ash.Reactor]

  input :tenant
  input :admin_user_id
  input :gateway_ids

  # Step 1: Create tenant schema
  step :create_schema do
    run fn %{tenant: tenant}, _ ->
      Mcp.MultiTenant.create_tenant_schema(tenant.slug)
    end
  end

  # Step 2: Run tenant migrations
  step :run_migrations do
    wait_for [:create_schema]
    run fn %{tenant: tenant}, _ ->
      Mcp.MultiTenant.run_tenant_migrations(tenant.slug)
    end
  end

  # Step 3: Provision subdomain DNS
  step :provision_subdomain, async?: true do
    run fn %{tenant: tenant}, _ ->
      Mcp.DNS.create_subdomain("#{tenant.slug}.base.do")
    end
  end

  # Step 4: Wait for DNS propagation
  step :wait_for_dns_propagation do
    wait_for [:provision_subdomain]
    max_retries 30
    run fn %{tenant: tenant}, _ ->
      # DNS polling logic here
    end
  end

  # Step 5: Create admin user profile
  step :create_admin_profile do
    wait_for [:run_migrations]
    run fn %{tenant: tenant, admin_user_id: admin_user_id}, _ ->
      Mcp.Auth.UserProfile.invite(
        entity_type: :tenant,
        entity_id: tenant.id,
        user_id: admin_user_id,
        is_admin: true,
        is_developer: true
      )
    end
  end

  # Step 6: Send welcome email
  step :send_welcome_email do
    wait_for [:wait_for_dns_propagation, :create_admin_profile]
    run fn %{tenant: tenant}, _ ->
      Mcp.Communication.Email.send_tenant_welcome(tenant)
    end
  end
end
```

---

## ✅ Branding Schema (JSONB)

Comprehensive tenant branding with typography, extended color palette, and custom CSS:

```json
{
  "logo_url": "https://cdn.base.do/tenants/acme/logo.png",
  "colors": {
    "primary": "#3b82f6",      // Primary brand color
    "secondary": "#8b5cf6",    // Secondary brand color
    "accent": "#f59e0b",       // Accent color for CTAs
    "success": "#10b981",      // Success state color
    "warning": "#f59e0b",      // Warning state color
    "error": "#ef4444"         // Error state color
  },
  "typography": {
    "font_family": "Inter, sans-serif",         // Body font
    "heading_font": "Poppins, sans-serif",      // Heading font
    "body_font": "Inter, sans-serif"            // Explicit body font
  },
  "custom_css": "/* Tenant-specific custom styles */\n.btn-primary { border-radius: 8px; }"
}
```

**Implementation Notes:**
- Fonts loaded via CDN (Google Fonts, Adobe Fonts, or self-hosted)
- Custom CSS sanitized to prevent XSS attacks
- Color palette integrated with DaisyUI theme system
- Logo URL stored in S3/MinIO with CDN distribution

---

## ✅ Settings Schema (JSONB)

Tenant-level operational and compliance settings:

### Business Settings
```json
{
  "business": {
    "timezone": "America/New_York",  // IANA timezone for reporting
    "currency": "USD",               // ISO 4217 currency code
    "locale": "en-US",               // ISO 639-1 language + region
    "date_format": "MM/DD/YYYY"      // Date display format
  }
}
```

### Feature Flags
```json
{
  "features": {
    "api_access": true,              // Enable API access for developers
    "custom_domains": true,          // Allow custom domain configuration
    "white_label": false,            // Hide "Powered by Base" branding
    "advanced_analytics": false,     // Enable advanced reporting features
    "ai_underwriting": false         // Enable AI merchant underwriting (Phase 2)
  }
}
```

### Integration Settings
```json
{
  "integrations": {
    "webhook_url": "https://acme.com/webhooks/base",  // Webhook endpoint for events
    "slack_webhook": "https://hooks.slack.com/...",   // Slack notifications
    "stripe_account_id": "acct_...",                  // Stripe Connect account
    "sendgrid_api_key": "SG.encrypted...",           // Email provider API key (encrypted)
    "twilio_account_sid": "AC...",                   // SMS provider credentials (encrypted)
    "custom_integrations": {}                        // Extensible for future integrations
  }
}
```

### Compliance Settings
```json
{
  "compliance": {
    "data_retention_days": 2555,      // 7 years (default financial retention)
    "gdpr_enabled": true,             // GDPR compliance features enabled
    "audit_log_retention_days": 365,  // Audit log retention period
    "require_2fa": false,             // Enforce 2FA for all tenant users
    "ip_allowlist": [],               // IP addresses allowed to access tenant (empty = all)
    "session_timeout_minutes": 60     // Idle session timeout
  }
}
```

### Full Example
```json
{
  "business": {
    "timezone": "America/New_York",
    "currency": "USD",
    "locale": "en-US",
    "date_format": "MM/DD/YYYY"
  },
  "features": {
    "api_access": true,
    "custom_domains": true,
    "white_label": false,
    "advanced_analytics": false,
    "ai_underwriting": false
  },
  "integrations": {
    "webhook_url": "https://acme.com/webhooks/base",
    "slack_webhook": "https://hooks.slack.com/...",
    "stripe_account_id": "acct_..."
  },
  "compliance": {
    "data_retention_days": 2555,
    "gdpr_enabled": true,
    "audit_log_retention_days": 365,
    "require_2fa": false,
    "session_timeout_minutes": 60
  }
}
```

---

## ✅ Onboarding Flow

**Step 1: Payment Setup**
- Add payment method (credit card)
- Select plan (Starter, Professional, Enterprise)
- Enter billing information
- Status: `onboarding_step = 'payment_setup'`

**Step 2: Gateway Configuration**
- Connect payment gateways (Stripe, Authorize.net, etc.)
- Configure MID settings
- Test gateway connections
- Status: `onboarding_step = 'gateway_config'`

**Step 3: Team Invitation**
- Invite admin users
- Assign roles and permissions
- Configure team structure
- Status: `onboarding_step = 'team_invitation'`

**Step 4: Complete**
- Set `onboarding_completed_at` timestamp
- Clear `onboarding_step`
- Activate tenant services
- Send welcome email
