# Merchants Schema

**Entity:** `acq_{tenant}.merchants` (tenant-scoped schema)
**Purpose:** Merchant accounts that process payments
**Ash Resource:** `Mcp.Merchants.Merchant`

---

## Database Schema

```sql
-- In tenant schema: acq_acme.merchants
CREATE TABLE merchants (
  -- Primary Key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identity
  slug TEXT NOT NULL,  -- URL-safe identifier (e.g., "bobs-burgers")
  business_name TEXT NOT NULL,
  dba_name TEXT,  -- Doing Business As

  -- Subdomain
  subdomain TEXT NOT NULL,  -- {slug}.base.do
  custom_domain TEXT,  -- Optional: portal.bobs-burgers.com

  -- Business Info
  business_type TEXT CHECK (business_type IN ('sole_proprietor', 'llc', 'corporation', 'partnership', 'nonprofit')),
  ein TEXT,  -- Employer Identification Number
  website_url TEXT,
  description TEXT,

  -- Address
  address_line1 TEXT,
  address_line2 TEXT,
  city TEXT,
  state TEXT,
  postal_code TEXT,
  country TEXT DEFAULT 'US',

  -- Contact
  phone TEXT,
  support_email TEXT,

  -- Ownership (optional: belongs to reseller)
  reseller_id UUID REFERENCES resellers(id) ON DELETE SET NULL,

  -- Subscription & Status
  plan TEXT DEFAULT 'starter' CHECK (plan IN ('starter', 'professional', 'enterprise')),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'pending_verification', 'closed')),

  -- Configuration
  settings JSONB DEFAULT '{}',
  branding JSONB DEFAULT '{}',  -- {logo_url, primary_color, theme}

  -- Limits (plan-based)
  max_stores INTEGER DEFAULT 0,  -- 0 = path-based only, N = N custom store subdomains
  max_products INTEGER,
  max_monthly_volume NUMERIC,  -- Dollar amount

  -- Risk & Compliance
  risk_level TEXT DEFAULT 'low' CHECK (risk_level IN ('low', 'medium', 'high')),
  kyc_verified_at TIMESTAMP,
  verification_status TEXT DEFAULT 'pending' CHECK (verification_status IN ('pending', 'verified', 'rejected')),

  -- Timestamps
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

  -- Tenant-scoped unique constraints
  UNIQUE(slug),  -- Unique within tenant
  UNIQUE(subdomain)  -- Unique within tenant
);

-- Indexes
CREATE INDEX idx_merchants_slug ON merchants(slug);
CREATE INDEX idx_merchants_subdomain ON merchants(subdomain);
CREATE INDEX idx_merchants_status ON merchants(status);
CREATE INDEX idx_merchants_reseller_id ON merchants(reseller_id) WHERE reseller_id IS NOT NULL;
CREATE INDEX idx_merchants_plan ON merchants(plan);
CREATE INDEX idx_merchants_risk_level ON merchants(risk_level);
```

---

## Ash Resource Definition

```elixir
defmodule Mcp.Merchants.Merchant do
  use Ash.Resource,
    domain: Mcp.Merchants,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshArchival, AshPaperTrail]

  postgres do
    table "merchants"
    repo Mcp.Repo
    # Schema determined by current tenant context
    # Uses Mcp.MultiTenant.with_tenant_context/2
  end

  attributes do
    uuid_primary_key :id

    attribute :slug, :string do
      allow_nil? false
      public? true
      constraints [match: ~r/^[a-z0-9-]+$/]
    end

    attribute :business_name, :string, allow_nil?: false, public?: true
    attribute :dba_name, :string, public?: true

    attribute :subdomain, :string, allow_nil?: false
    attribute :custom_domain, :string, public?: true

    attribute :business_type, :atom do
      constraints one_of: [:sole_proprietor, :llc, :corporation, :partnership, :nonprofit]
      public?: true
    end

    attribute :ein, :string, sensitive?: true
    attribute :website_url, :string, public?: true
    attribute :description, :string, public?: true

    # Address
    attribute :address_line1, :string, public?: true
    attribute :address_line2, :string, public?: true
    attribute :city, :string, public?: true
    attribute :state, :string, public?: true
    attribute :postal_code, :string, public?: true
    attribute :country, :string, default: "US", public?: true

    # Contact
    attribute :phone, :string, public?: true
    attribute :support_email, :string, public?: true

    attribute :reseller_id, :uuid

    attribute :plan, :atom do
      constraints one_of: [:starter, :professional, :enterprise]
      default :starter
      public?: true
    end

    attribute :status, :atom do
      constraints one_of: [:active, :suspended, :pending_verification, :closed]
      default :active
    end

    attribute :settings, :map, default: %{}, public?: true
    attribute :branding, :map, default: %{}, public?: true

    attribute :max_stores, :integer, default: 0
    attribute :max_products, :integer
    attribute :max_monthly_volume, :decimal

    attribute :risk_level, :atom do
      constraints one_of: [:low, :medium, :high]
      default :low
    end

    attribute :kyc_verified_at, :utc_datetime_usec
    attribute :verification_status, :atom do
      constraints one_of: [:pending, :verified, :rejected]
      default :pending
    end

    timestamps()
  end

  relationships do
    belongs_to :reseller, Mcp.Resellers.Reseller

    has_many :user_profiles, Mcp.Auth.UserProfile do
      filter expr(entity_type == :merchant and entity_id == ^id)
    end

    has_many :mids, Mcp.MIDs.MID
    has_many :stores, Mcp.Stores.Store
    has_many :products, Mcp.Products.Product
    has_many :customers, Mcp.Customers.Customer
    has_many :vendors, Mcp.Vendors.Vendor
  end

  identities do
    identity :unique_slug, [:slug]
    identity :unique_subdomain, [:subdomain]
  end

  actions do
    defaults [:read, :destroy]

    create :onboard do
      accept [:slug, :business_name, :dba_name, :business_type, :subdomain, :plan, :reseller_id]
      argument :admin_user_id, :uuid, allow_nil?: false

      # Triggers MerchantOnboardingReactor saga
    end

    update :verify_kyc do
      accept []
      change set_attribute(:kyc_verified_at, &DateTime.utc_now/0)
      change set_attribute(:verification_status, :verified)
      change set_attribute(:status, :active)
    end

    update :update_branding do
      accept [:branding]
    end

    update :assign_custom_domain do
      accept [:custom_domain]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if tenant_user?()
      authorize_if expr(reseller_id == ^actor(:profile).entity_id and ^actor(:profile).entity_type == :reseller)
    end

    policy action_type(:create) do
      authorize_if tenant_admin?()
      authorize_if reseller_user?()
    end

    policy action_type(:update) do
      authorize_if merchant_admin?()
      authorize_if tenant_admin?()
    end
  end

  code_interface do
    define :onboard, args: [:slug, :business_name, :subdomain, :plan]
    define :verify_kyc
    define :update_branding, args: [:branding]
  end
end
```

---

## Business Rules

1. **Slug unique within tenant:** "bobs-burgers" can exist in Tenant A and Tenant B
2. **Subdomain:** `{slug}.base.do` (e.g., `bobs-burgers.base.do`)
3. **Reseller ownership:** Optional, if merchant created by reseller
4. **Custom domain pricing:** $5/month for `portal.bobs-burgers.com`
5. **Store limits:** Free plan = 0 custom subdomains (path-based only), Pro = 5, Enterprise = unlimited
6. **KYC verification:** Required before processing payments
7. **Risk assessment:** Auto-calculated based on business type, volume, industry

---

## ✅ Finalized Decisions

### EIN Requirement
**Decision:** ✅ Optional (sole proprietors can use SSN)
**Rationale:** Not all business types have EINs. Sole proprietors in the US typically use SSN for tax purposes.

### Store Limits Per Plan
**Decision:** ✅ Unlimited path-based stores, custom subdomains per plan:
- **Starter:** 0 custom store subdomains (path-based only: `merchant.base.do/store1`, `merchant.base.do/store2`)
- **Professional:** 5 custom store subdomains (`store1.merchant.base.do`)
- **Enterprise:** Unlimited custom store subdomains

**Rationale:** Path-based routing is free and requires no additional infrastructure. Custom subdomains require DNS records and SSL certificates, justifying plan-based limits.

### KYC Verification Process
**Decision:** 🎯 **AI-POWERED MERCHANT UNDERWRITING SYSTEM** (Major Phase 2 Feature)

**Phase 1 (MVP):**
- Third-party KYC service integration (Stripe Identity, Persona, Onfido)
- Simple rules-based risk scoring (5-10 basic factors)
- Manual review queue for flagged applications

**Phase 2 (Strategic Feature):**
- AI-powered merchant online application with dynamic questions
- ML-based automated underwriting decisions
- Intelligent risk assessment using 100+ signals
- PAYFAC services for tenants (sub-merchant onboarding)
- Real-time fraud detection and pattern recognition

**See:** `/Users/rp/Developer/Base/mcp/docs/features/ai-merchant-underwriting.md` for complete feature specification

### Risk Level Calculation Factors
**Decision:** ✅ All factors (integrated into AI underwriting system):
- **Business attributes:** type, age, industry, legal structure
- **Transaction patterns:** volume, ticket size, chargeback rate
- **Verification status:** KYC complete, documents verified, references checked
- **External signals:** credit score, business credit, public records

**Implementation:** Risk calculation will be handled by the AI underwriting system using ML models, not simple rules-based logic. The merchant schema includes stub fields for underwriting integration:
- `underwriting_status` - Application status
- `risk_score` - ML-generated risk score (0-100)
- `verification_documents` - JSONB for KYC document tracking

**Roadmap:**
- **MVP:** Basic KYC with third-party provider
- **Phase 2:** Full AI underwriting with ML models
- **Phase 3:** PAYFAC platform for tenant sub-merchant management
