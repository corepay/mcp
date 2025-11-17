# Architecture Document: AI-Powered MSP Platform

**Version:** 1.0
**Date:** 2025-11-17
**Status:** Complete - Ready for Implementation
**Project:** Base MCP with Integrated AI Underwriting (OLA)

---

## Executive Summary

This architecture defines a **10-portal multi-tenant payment processing and merchant underwriting platform** built on Phoenix/Elixir with the Ash Framework. The platform integrates payment processing (Base MCP - 8 portals) with AI-powered merchant underwriting (OLA - 2 portals) as a unified system with clear phase boundaries.

**Phase 1 Focus:** Payment processing platform (8 portals, ~40 database tables)
**Phase 2+ Integration:** AI underwriting system (2 additional portals, ~12 additional tables) - Stubbed with clear boundaries

**Key Architectural Decisions:**
- Schema-based multi-tenancy (acq_{tenant})
- Entity-scoped user profiles (separate identity per entity)
- Path-based portal routing (no unnecessary subdomains)
- Reseller custom domains for white-label OLA experience
- Flexible pricing/billing architecture (deferred business logic)
- World-class OTP supervision with stateful/stateless separation
- Stripe-style API versioning (header-based, not path-based)
- Lookup tables replacing ALL PostgreSQL ENUMs

---

## Table of Contents

1. [Portal Architecture](#portal-architecture)
2. [Technology Stack](#technology-stack)
3. [OTP Supervision Strategy](#otp-supervision-strategy)
4. [Database Architecture](#database-architecture)
5. [Authentication & Authorization](#authentication--authorization)
6. [Domain Structure](#domain-structure)
7. [Multi-Tenancy Architecture](#multi-tenancy-architecture)
8. [Routing & Custom Domains](#routing--custom-domains)
9. [AI Integration Strategy](#ai-integration-strategy)
10. [OLA/Underwriting Integration Boundaries](#ola-underwriting-integration-boundaries)
11. [API Architecture](#api-architecture)
12. [Pricing & Billing Architecture](#pricing--billing-architecture)
13. [Security Architecture](#security-architecture)
14. [Performance & Scalability](#performance--scalability)
15. [Deployment Architecture](#deployment-architecture)
16. [Development Workflow](#development-workflow)
17. [Architecture Decision Records](#architecture-decision-records)

---

## Portal Architecture

### 10-Portal System Overview

**Phase 1: Payment Processing (8 Portals)**

1. **Platform Admin Portal** - `admin.base.do`
   - Platform operator management
   - Cross-tenant analytics
   - System configuration
   - Billing operations management

2. **Tenant Admin Portal** - `{tenant-slug}.base.do`
   - Payment processor operations
   - Merchant/reseller/developer management
   - Integrated underwriting queue (`/underwriting/`)
   - Business analytics and reporting
   - Settings and branding configuration

3. **Developer Portal** - `{tenant-slug}.base.do/developers/`
   - Unified developer access (context-aware)
   - API documentation and testing
   - API key management (admin/team-controlled)
   - Usage analytics

4. **Reseller Portal** - `{reseller-slug}.{tenant-slug}.base.do`
   - Partner merchant portfolio management
   - Commission tracking and reporting
   - Reseller-branded application links
   - Limited merchant data visibility

5. **Merchant Portal** - `{merchant-slug}.{tenant-slug}.base.do`
   - Business payment processing dashboard
   - MID and gateway management
   - Transaction history and analytics
   - Multi-store management

6. **Store Portal** - `{merchant-slug}.{tenant-slug}.base.do/stores/{store-slug}/`
   - Multi-store management interface
   - Store-specific analytics
   - Store user management
   - Store settings and branding

7. **Customer Portal** - `{merchant-slug}.{tenant-slug}.base.do/account/`
   - Customer account management
   - Order history
   - Payment methods
   - Subscription management

8. **Vendor Portal** - `{merchant-slug}.{tenant-slug}.base.do/vendors/`
   - Vendor relationship management
   - Product catalog
   - Inventory tracking

**Phase 2+: AI Underwriting (2 Additional Portals - Stubbed)**

9. **Merchant Application Portal** - Multiple routing options:
   - Direct tenant: `{tenant-slug}.base.do/applications/`
   - Reseller subdomain: `{reseller-slug}.{tenant-slug}.base.do/apply/`
   - Reseller custom domain: `apply.{reseller-brand}.com/`

   Features:
   - Public-facing AI-assisted application
   - Merchant prospect self-service
   - Conversational AI + traditional forms
   - Document upload and real-time tracking
   - Application status tracking

10. **Underwriting Review Portal** - `{tenant-slug}.base.do/underwriting/`
    - Tenant underwriter dashboard
    - AI risk analysis review interface
    - HITL rules configuration
    - Case management and analytics
    - Document review interface
    - Applicant communication tools

### Portal Routing Strategy

**Path-based routing for tight integration:**
```
{tenant-slug}.base.do/
├── dashboard/              # Tenant admin
├── merchants/              # Merchant management
├── resellers/              # Reseller management
├── developers/             # Developer portal
├── analytics/              # Business analytics
├── settings/               # Configuration
├── underwriting/           # ← Underwriter portal (Phase 2)
└── applications/           # ← Direct applications (Phase 2)

{reseller-slug}.{tenant-slug}.base.do/
├── dashboard/              # Reseller dashboard
├── merchants/              # Portfolio management
└── apply/                  # ← Reseller-branded OLA (Phase 2)

{merchant-slug}.{tenant-slug}.base.do/
├── dashboard/              # Merchant dashboard
├── mids/                   # Payment gateway management
├── transactions/           # Transaction history
├── stores/                 # Multi-store management
├── account/                # Customer portal
└── vendors/                # Vendor portal
```

---

## Technology Stack

### Backend Framework
- **Phoenix 1.8.1** - Web framework
- **Elixir 1.17+** - Runtime language
- **Ash Framework 3.0** - Resource-based architecture
  - `ash_authentication` - Auth system
  - `ash_postgres` - Database integration
  - `ash_policies` - Authorization
  - `ash_reactor` - Saga orchestration
  - `ash_paper_trail` - Audit logging
  - `ash_archival` - Soft deletes

### Frontend
- **Phoenix LiveView** - Real-time UI
- **DaisyUI** - Component library
- **Tailwind CSS v4** - Styling (new import syntax)
- **Alpine.js** - Client-side interactivity
- **esbuild** - JavaScript bundling (ES2022)

### Database & Data
- **PostgreSQL 17+** - Primary database
  - **TimescaleDB** - Time-series data (transactions)
  - **PostGIS** - Geospatial data (addresses)
  - **pgvector** - Vector search (AI embeddings)
  - **Apache AGE** - Graph database (relationships)
- **Redis** - Caching and sessions
- **Meilisearch** - Full-text search

### Infrastructure
- **Docker/Kubernetes** - Container orchestration
- **MinIO** - S3-compatible object storage
- **HashiCorp Vault** - Secrets management
- **CloudFlare** - SSL/DNS for custom domains
- **Grafana + Prometheus + Loki** - Monitoring stack

### AI/ML (Phase 2+)
- **OpenRouter API** - Conversational AI (GPT-4, Claude, Gemini)
- **Ollama + Llama** - Local ML models (risk scoring)
- **Elixir NX + Axon** - ML framework
- **Qdrant** - Vector database (self-hosted)

### Background Jobs
- **Oban** - Reliable job processing

### External Integrations (Phase 2+)
- **Mock-first adapter pattern** for all external services
- KYC/KYB: Jumio, Onfido, Veriff
- Credit Bureaus: Experian, Equifax, TransUnion
- Business Verification: LexisNexis, Dun & Bradstreet
- Bank Verification: Plaid, Yodlee, Finicity
- AML/Sanctions: Refinitiv, Comply Advantage
- Fraud Detection: Sift, Riskified, Signifyd

---

## OTP Supervision Strategy

### Main Supervision Tree

```
Mcp.Application (:one_for_one)
│
├── Mcp.Infrastructure.Supervisor (:rest_for_one)
│   ├── Mcp.Core.Repo (Ecto connection pool)
│   ├── Mcp.Infrastructure.Cache.Supervisor
│   │   ├── Redix (connection pool, permanent)
│   │   ├── Mcp.Cache.Manager (GenServer)
│   │   └── Mcp.Cache.SessionStore (GenServer)
│   ├── Mcp.Infrastructure.Secrets.Supervisor
│   │   ├── Mcp.Secrets.VaultClient (GenServer with pool)
│   │   ├── Mcp.Secrets.CredentialManager (GenServer)
│   │   └── Mcp.Secrets.EncryptionService (stateless)
│   ├── Mcp.Infrastructure.Storage.Supervisor
│   │   ├── Mcp.Storage.S3Client (GenServer with pool)
│   │   └── Mcp.Storage.FileManager (GenServer)
│   └── Mcp.Infrastructure.Search.Supervisor
│       └── Mcp.Search.MeilisearchClient (GenServer)
│
├── Mcp.Domains.Supervisor (:one_for_one)
│   ├── Mcp.Auth (Ash Domain - stateless)
│   ├── Mcp.Tenants (Ash Domain - stateless)
│   ├── Mcp.Merchants (Ash Domain - stateless)
│   ├── Mcp.Payments (Ash Domain - stateless)
│   ├── Mcp.Underwriting (Ash Domain - stateless) [Phase 2]
│   └── Mcp.Analytics (Ash Domain - stateless)
│
├── Mcp.Services.Supervisor (:one_for_one)
│   ├── Mcp.Services.MultiTenant.SchemaManager (GenServer)
│   ├── Mcp.Services.AI.ConversationManager (DynamicSupervisor) [Phase 2]
│   ├── Mcp.Services.AI.ModelRouter (GenServer) [Phase 2]
│   ├── Mcp.Services.Document.ProcessorPool (NimblePool) [Phase 2]
│   ├── Mcp.Services.Risk.AssessmentEngine (GenServer) [Phase 2]
│   ├── Mcp.Services.Notifications.Dispatcher (GenServer)
│   └── Mcp.Services.Billing.UsageTracker (GenServer + ETS)
│
├── Mcp.Jobs.Supervisor (:one_for_one)
│   └── {Oban, name: Mcp.Oban, repo: Mcp.Core.Repo}
│
├── Mcp.Platform.Supervisor (:one_for_one)
│   ├── {Phoenix.PubSub, name: Mcp.PubSub}
│   ├── {Finch, name: Mcp.Finch}
│   └── {PartitionSupervisor, child_spec: Registry, name: Mcp.Registry}
│
└── Mcp.Web.Supervisor (:one_for_one)
    ├── McpWeb.Telemetry
    ├── McpWeb.Presence
    └── McpWeb.Endpoint
```

### Supervision Strategies

**:rest_for_one (Infrastructure)**
- If Vault dies → restart CredentialManager (depends on Vault)
- Cache/Storage continue independently
- Ensures dependent services restart in order

**:one_for_one (Domains, Services, Platform, Web)**
- Each process independent
- Isolated failures
- AI conversation crash doesn't affect billing

### Process Responsibilities

| Process | Type | Restart | Shared | Purpose |
|---------|------|---------|--------|---------|
| Repo | GenServer | permanent | ✅ | Database pool |
| Redix | GenServer | permanent | ✅ | Redis pool |
| VaultClient | GenServer | permanent | ✅ | Secrets API |
| S3Client | GenServer | permanent | ✅ | Storage API |
| MeilisearchClient | GenServer | permanent | ✅ | Search API |
| SchemaManager | GenServer | permanent | ✅ | Tenant schemas |
| ConversationSession | GenServer | temporary | ❌ | AI chat state |
| ProcessorWorker | Worker | temporary | ❌ | OCR/document |
| AssessmentEngine | GenServer | permanent | ✅ | ML inference |
| UsageTracker | GenServer | permanent | ✅ | Usage events |

### Shared Resource Patterns

**Connection Pooling:**
```elixir
# Redis
{Redix, name: :redix_cache, host: "localhost", port: 6379}

# HTTP (Finch)
{Finch, name: Mcp.Finch, pools: %{
  :default => [size: 10],
  "https://openrouter.ai" => [size: 32, count: 8]
}}

# OCR Worker Pool (NimblePool)
{NimblePool, worker: {ProcessorWorker, []}, pool_size: 10}
```

**ETS for High-Performance State:**
```elixir
# Usage events (avoid GenServer bottleneck)
:ets.new(:usage_events, [
  :named_table, :public, :set,
  {:write_concurrency, true},
  {:read_concurrency, true}
])
```

**Process Registry:**
```elixir
# Lookup AI conversation sessions
Registry.lookup(Mcp.Registry, {:conversation, application_id})
```

---

## Database Architecture

### PostgreSQL Schema Strategy

**Multi-Tenant Schema Isolation:**
```sql
-- Platform-wide schemas
platform         -- Global auth, tenants, lookup tables
shared           -- Polymorphic shared entities (addresses, notes, etc.)

-- Per-tenant schemas (created during onboarding)
acq_acme        -- Tenant "acme" data
acq_globex      -- Tenant "globex" data
```

**Search Path:**
```sql
SET search_path TO acq_acme, platform, shared, public;
```

### Schema File Organization

All schema definitions in `/docs/schemas/`:

1. **00-lookup-tables-schema.md** - ALL lookup tables (replaces ENUMs)
2. **01-platform-users-schema.md** - Global authentication
3. **02-user-profiles-schema.md** - Entity-scoped identities
4. **03-tenants-schema.md** - Top-level entities
5. **04-merchants-schema.md** - Merchant accounts
6. **05-mids-stores-customers-schema.md** - Payment processing entities
7. **06-polymorphic-shared-entities-schema.md** - Shared entities with RLS

### Phase 1 Tables (~40 tables)

**Platform Schema:**
- platform.users
- platform.user_profiles
- platform.tenants
- platform.entity_types (lookup)
- platform.status_types (lookup)
- platform.plan_types (lookup)
- platform.address_types (lookup)
- platform.email_types (lookup)
- platform.phone_types (lookup)
- platform.payment_gateways
- platform.addresses (polymorphic)
- platform.emails (polymorphic)
- platform.phones (polymorphic)
- platform.images (polymorphic)
- platform.documents (polymorphic)
- platform.notes (polymorphic)
- platform.todos (polymorphic)
- platform.teams
- platform.team_members
- platform.api_keys

**Tenant Schemas (acq_{tenant}):**
- developers
- resellers
- merchants
- mids
- stores
- customers
- vendors
- products
- transactions (TimescaleDB hypertable)
- orders
- subscriptions

### Phase 2+ Tables (~12 additional tables)

**Tenant Schemas (acq_{tenant}):**
- application_users (merchant prospects)
- merchant_applications
- application_sessions (AI conversations)
- application_documents
- application_messages
- hitl_rules
- underwriting_reviews
- risk_assessments
- application_events
- application_analytics
- external_api_calls

**Platform Schema:**
- payfac_configurations

### Key Architectural Decisions

**✅ NO PostgreSQL ENUMs**
- All type fields use FK to lookup tables
- Runtime changes via INSERT/UPDATE (no migrations)
- Extensible without schema changes

**✅ Polymorphic Associations**
- owner_type + owner_id pattern
- FK to platform.entity_types(value)
- 30+ entity types supported

**✅ Row-Level Security (RLS)**
- Database-enforced access control
- Policies based on user context
- Shared entities with tenant isolation

**✅ JSONB for Extensibility**
- Settings, branding, metadata
- Pricing configuration
- Commission rules
- Preferences

---

## Authentication & Authorization

### Authentication Architecture

**Three Authentication Realms:**

1. **Platform Users** (`platform.users`)
   - Global authentication (email + password + 2FA)
   - OAuth: Google and GitHub only
   - Password requirements: Min 8 chars, mixed types
   - Soft delete (status: deleted, 90-day GDPR retention)

2. **Entity Users** (`platform.user_profiles`)
   - Entity-scoped identities (separate profile per entity)
   - Same user can be "Alice Developer" (Tenant A) and "Alice Admin" (Merchant B)
   - Separate: name, nickname, avatar, bio, title, contact info, preferences
   - Role flags: is_admin, is_developer

3. **Application Users** (`acq_{tenant}.application_users`) [Phase 2]
   - Merchant prospects applying via OLA
   - Separate auth from platform users
   - Create account via "Apply Now" links
   - Tenant-scoped uniqueness

### Authorization Model

**Teams & Permissions:**
- GitHub-style team invitations
- Feature-based permissions: read, write, archive, create_users, create_teams, manage_members
- Teams assigned to entity scopes
- Hierarchical permission inheritance

**API Key Management:**
- Three-tier access model (Developer, Merchant, Reseller)
- Admin-only creation rights (separation from developer portal access)
- Team-based API key permissions
- 90-day expiry with rotation

**Ash Policies:**
```elixir
policy action_type(:read) do
  authorize_if tenant_user?()
  authorize_if expr(reseller_id == ^actor(:profile).entity_id)
end

policy action_type(:create) do
  authorize_if tenant_admin?()
  authorize_if reseller_user?()
end
```

---

## Domain Structure

### Ash Domain Organization

```
lib/mcp/domains/
├── auth/                    # Mcp.Auth
│   ├── domain.ex
│   ├── user.ex
│   ├── user_profile.ex
│   ├── token.ex
│   └── policies.ex
├── tenants/                 # Mcp.Tenants
│   ├── domain.ex
│   ├── tenant.ex
│   ├── onboarding_reactor.ex
│   └── policies.ex
├── merchants/               # Mcp.Merchants
│   ├── domain.ex
│   ├── merchant.ex
│   ├── mid.ex
│   ├── store.ex
│   └── policies.ex
├── payments/                # Mcp.Payments
│   ├── domain.ex
│   ├── transaction.ex
│   ├── payment_gateway.ex
│   └── policies.ex
├── underwriting/            # Mcp.Underwriting [Phase 2]
│   ├── domain.ex
│   ├── application.ex
│   ├── risk_assessment.ex
│   ├── underwriting_review.ex
│   └── policies.ex
└── analytics/               # Mcp.Analytics
    ├── domain.ex
    └── metrics.ex
```

### Domain Boundaries

**Mcp.Auth** - Authentication & user management
- Resources: User, UserProfile, Token
- Responsibilities: Login, registration, 2FA, profiles
- Shared: All domains use for actor resolution

**Mcp.Tenants** - Tenant lifecycle
- Resources: Tenant
- Responsibilities: Onboarding, schema creation, DNS provisioning
- Reactor Saga: OnboardingReactor

**Mcp.Merchants** - Merchant management
- Resources: Merchant, MID, Store
- Responsibilities: Merchant accounts, payment gateway routing
- Integration: Underwriting domain (approved applications → create merchant)

**Mcp.Payments** - Payment processing
- Resources: Transaction, PaymentGateway
- Responsibilities: Transaction processing, routing
- TimescaleDB: transactions table (time-series)

**Mcp.Underwriting** [Phase 2] - AI-powered underwriting
- Resources: Application, RiskAssessment, UnderwritingReview
- Responsibilities: Application processing, risk scoring, HITL workflows
- Integration: Merchants domain (approval creates merchant)

**Mcp.Analytics** - Business intelligence
- Resources: Metrics
- Responsibilities: Dashboards, reporting, KPIs

---

## Multi-Tenancy Architecture

### Schema-Based Isolation

**Tenant Schema Pattern:**
```elixir
defmodule Mcp.MultiTenant do
  def with_tenant_context(tenant_slug, fun) do
    schema_name = "acq_#{tenant_slug}"

    Repo.query("SET search_path TO #{schema_name}, platform, shared")

    try do
      fun.()
    after
      Repo.query("SET search_path TO platform, public")
    end
  end
end
```

**Schema Creation (Reactor Saga):**
```elixir
defmodule Mcp.Tenants.OnboardingReactor do
  step :create_schema do
    run fn %{tenant: tenant}, _ ->
      Mcp.MultiTenant.create_tenant_schema(tenant.slug)
    end
  end

  step :run_migrations do
    wait_for [:create_schema]
    run fn %{tenant: tenant}, _ ->
      Mcp.MultiTenant.run_tenant_migrations(tenant.slug)
    end
  end

  step :provision_subdomain, async?: true do
    run fn %{tenant: tenant}, _ ->
      Mcp.DNS.create_subdomain("#{tenant.slug}.base.do")
    end
  end
end
```

### Data Isolation Rules

**Tenant Data:**
- Developers, Resellers, Merchants, MIDs, Stores, Customers
- Isolated in `acq_{tenant}` schema
- No cross-tenant queries

**Platform Data:**
- Users, UserProfiles, Tenants, Lookup Tables
- Shared across all tenants
- Global uniqueness (emails, subdomains)

**Shared Polymorphic Data:**
- Addresses, Emails, Phones, Documents, Notes
- Row-Level Security (RLS) enforces access
- Accessible via user context

### Cross-Tenant Visibility

**Reseller Visibility:**
- ✅ Can see: Merchant payment data (MIDs, gateways, volume)
- ❌ Cannot see: Merchant business data (customers, products, PII)

**Developer Visibility:**
- Scoped to tenant-defined permissions
- API key boundaries

---

## Routing & Custom Domains

### Domain Routing Strategy

**Base Domains:**
- `base.do` - Platform domain
- `{tenant}.base.do` - Tenant portal
- `{reseller}.{tenant}.base.do` - Reseller portal
- `{merchant}.{tenant}.base.do` - Merchant portal

**Custom Domain Support:**

| Entity | Example | Pricing | SSL |
|--------|---------|---------|-----|
| Tenant | `portal.tenantbrand.com` | Free (Pro), $10/mo (Starter) | CloudFlare |
| Reseller | `apply.resellerbrand.com` | Free (Pro), $10/mo (Starter) | CloudFlare |
| Merchant | `store.merchantbrand.com` | Free (Pro), $10/mo (Starter) | CloudFlare |

**Reseller-Branded Application Routing:**
```
Reseller share links:
1. Subdomain: reseller-slug.tenant.base.do/apply
2. Custom domain: apply.resellerbrand.com

Application created with:
- reseller_id (automatic attribution)
- tenant_id (from reseller relationship)
- source: 'reseller'

Branding inheritance:
- Custom domain → Reseller branding
- Subdomain → Reseller branding + tenant fallback
- Direct tenant → Tenant branding only
```

### DNS Configuration

**CloudFlare DNS:**
- Unlimited SSL certificates (no Let's Encrypt rate limits)
- Instant provisioning
- Automatic renewal
- CNAME verification for custom domains

**Verification Flow:**
1. User requests custom domain
2. System generates verification token
3. User adds CNAME record: `_verify.{domain}` → `verify-{token}.base.do`
4. System polls DNS for verification
5. On success: Provision SSL via CloudFlare API
6. Activate custom domain routing

---

## AI Integration Strategy

### Hybrid AI Approach (Phase 2+)

**OpenRouter API (Conversational AI):**
- Use case: Customer-facing conversational interfaces
- Models: GPT-4, Claude, Gemini, Llama (via API)
- Benefits: Latest models, no infrastructure
- Cost management: Per-token tracking, tenant billing

**Local Ollama + Llama (Core ML):**
- Use case: Risk scoring, decision engines
- Models: Llama 3/4, custom fine-tuned
- Benefits: No per-token costs, complete data control
- Infrastructure: Self-hosted with GPU

**AI Cost Management:**
```elixir
# Track AI usage per conversation
CREATE TABLE application_sessions (
  model_used TEXT,
  tokens_used INTEGER,
  cost_usd NUMERIC(10,4),
  application_id UUID
);

# Tenant AI cost configuration
attribute :ai_pricing, :map, default: %{
  "model_selection": "auto",  # or "gpt-4", "claude"
  "usage_quota": 10000,       # tokens per month
  "markup_percentage": 20,    # upcharge on API costs
  "fallback_model": "llama"   # if quota exceeded
}
```

---

## OLA/Underwriting Integration Boundaries

### Phase Separation

**Phase 1: Payment Processing Platform**
- Focus: 8 portals, payment processing, multi-tenancy
- Tables: ~40 tables for core platform
- NO underwriting implementation
- Stub: Schema definitions, integration points documented

**Phase 2+: AI Underwriting Integration**
- Focus: 2 additional portals, AI-powered underwriting
- Tables: +12 tables for underwriting
- Full implementation: Conversational AI, risk assessment, HITL
- Integration: Approved applications → create merchants

### Integration Points

**Merchant Creation from Application:**
```elixir
# When application approved
defmodule Mcp.Underwriting.ApplicationApproval do
  def approve_and_create_merchant(application_id) do
    Reactor.run(MerchantCreationReactor, %{
      application: application,
      reseller_id: application.reseller_id
    })
  end
end

# Creates merchant with attribution
# merchants.reseller_id = application.reseller_id
```

**Reseller Attribution:**
- OLA links tagged with reseller_id
- Application carries reseller attribution
- Commission tracking enabled
- Reseller dashboard shows applications

**Shared Services:**
- Storage: Documents stored in shared MinIO
- Secrets: Vault for encryption
- Cache: Redis for sessions
- Billing: Unified usage tracking

### Deferred Business Logic

**DEFERRED:** Commission calculation strategy
**DEFERRED:** Custom domain billing responsibility
**DEFERRED:** AI cost pass-through vs markup model
**DEFERRED:** Reseller payout mechanisms
**DEFERRED:** Application processing pricing tiers

**Flexibility Ensured:**
- JSONB pricing configuration (no schema changes)
- Event-driven usage tracking
- Pluggable commission calculators
- Generic ledger system
- Flexible billing relationships

---

## API Architecture

### Stripe-Style API Versioning

**Header-Based Versioning:**
```
API-Version: 2025-11-17
```

**NO path-based versioning** (`/v1/`, `/v2/` NOT used)

**Version Strategy:**
- Account default version (configurable per tenant)
- Request-level version override via header
- Version-aware serialization
- Backward compatibility maintenance

### API Endpoints

**Payment Processing:**
```
POST   /api/merchants
GET    /api/merchants/:id
POST   /api/transactions
GET    /api/transactions/:id
```

**Underwriting API (Phase 2+):**
```
POST   /api/underwriting/applications
GET    /api/underwriting/applications/:id
POST   /api/underwriting/applications/:id/documents
GET    /api/underwriting/risk-assessment/:id
POST   /api/underwriting/decisions/:id
```

**API Authentication:**
- Three-tier access model
- Admin-only API key creation
- Team-based permissions
- Scoped to tenant boundaries

### API-Only Customers

**Scenario:** External payment processors consume underwriting API
**Pricing:** OLA PRD pricing ($299-$2,999) based on volume
**Access:** Underwriting endpoints only (not payment processing)
**Tenant Type:** `api_only` vs `integrated`

```elixir
attribute :tenant_type, :atom do
  constraints one_of: [:integrated, :api_only, :white_label]
end

attribute :api_features, :map do
  default %{
    "conversational_ai" => true,
    "document_processing" => true,
    "risk_assessment" => true
  }
end
```

---

## Pricing & Billing Architecture

### Pricing Dimensions

**Base Platform Subscriptions:**
- Starter: $0/month
- Professional: $49/month or $490/year
- Enterprise: $149/month or $1,490/year

**Add-On Pricing:**
- Custom domains: Free (Pro), $10/month (Starter)
- Store custom subdomains: Free (Pro), $10/month per subdomain (Starter)
- Path-based stores: Unlimited FREE on all plans

**Usage-Based (Phase 2+):**
- OLA application processing fees
- AI token consumption (OpenRouter API)
- External API calls (KYC, credit bureaus)
- Document processing (OCR, fraud detection)

### Flexible Pricing Engine

**JSONB Configuration:**
```elixir
attribute :pricing_model, :map, default: %{
  "subscription" => %{
    "plan_tier" => "professional",
    "base_price_monthly" => 49
  },
  "usage_based" => %{
    "applications_processed" => %{
      "price_per_unit" => 5.00,
      "included_units" => 100
    }
  },
  "addons" => %{
    "custom_domain" => %{"price" => 10}
  },
  "reseller_commissions" => %{
    "enabled" => true,
    "model" => "to_be_determined"
  }
}
```

### Usage Tracking

**Event-Driven Architecture:**
```elixir
# Every billable event
defstruct [
  :event_type,  # "application_processed", "ai_tokens_used"
  :tenant_id,
  :reseller_id,  # Attribution
  :cost_usd,
  :billable,
  :metadata,
  :occurred_at
]

# Usage tracking table
CREATE TABLE usage_events (
  event_type TEXT NOT NULL,
  tenant_id UUID NOT NULL,
  reseller_id UUID,
  cost_usd NUMERIC(10,4),
  commission_calculated BOOLEAN DEFAULT false,
  billable BOOLEAN DEFAULT true
);
```

### Commission Architecture

**Pluggable Commission Calculators:**
```elixir
@callback calculate_commission(event, config) :: {:ok, Decimal.t()}

# Implementations:
Mcp.Billing.Commissions.FlatFee
Mcp.Billing.Commissions.PercentageRevShare
Mcp.Billing.Commissions.Tiered
Mcp.Billing.Commissions.Custom
```

### Generic Ledger System

```sql
CREATE TABLE ledger_entries (
  entity_type TEXT NOT NULL,  -- 'tenant', 'reseller', 'platform'
  entity_id UUID NOT NULL,
  entry_type TEXT NOT NULL,   -- 'charge', 'payment', 'commission'
  amount NUMERIC(12,4),
  source_type TEXT,           -- 'subscription', 'usage', 'commission'
  source_id UUID,
  status TEXT DEFAULT 'pending'
);
```

---

## Security Architecture

### Authentication Security

**Password Policy:**
- ✅ Min 8 characters
- ✅ Mixed character types (uppercase, lowercase, numbers, special)
- ✅ Bcrypt hashing (cost factor: 12)
- ✅ Rate limiting: 5 attempts per 15 minutes
- ✅ Account lockout after 5 failures

**2FA Support:**
- TOTP via authenticator apps
- Backup codes (encrypted)
- Optional per user, enforceable per entity

**OAuth:**
- Google and GitHub only
- Token encryption at rest (Vault)

### Data Protection

**Encryption:**
- TLS 1.2+ in transit
- AES-256 at rest (Vault)
- Document encryption: HashiCorp Vault
- PII encryption: Cloak/Vault

**GDPR Compliance:**
- Soft delete (status: deleted)
- 90-day retention for deleted users
- 7-year retention for financial documents
- Background job for permanent purging (Oban)

### Access Control

**Row-Level Security (RLS):**
```sql
CREATE POLICY addresses_select ON platform.addresses
  FOR SELECT
  USING (
    owner_type = 'user' AND owner_id = current_user_id()
    OR EXISTS (
      SELECT 1 FROM platform.user_profiles
      WHERE user_id = current_user_id()
        AND entity_type = addresses.owner_type
        AND entity_id = addresses.owner_id
    )
  );
```

**Ash Policies:**
- Declarative authorization
- Resource-level policies
- Action-specific rules
- Actor-based context

### Audit Trail

**AshPaperTrail:**
- Complete change history
- Actor attribution
- Timestamp tracking
- Immutable audit log

---

## Performance & Scalability

### Database Optimization

**Connection Pooling:**
- Ecto pool size: 10 per node
- Read replicas for analytics
- Connection timeout: 5s

**Indexes:**
- All FK columns indexed
- Composite indexes for common queries
- GIN indexes for JSONB
- Full-text search indexes (GiST)

**TimescaleDB:**
- transactions table as hypertable
- Automatic partitioning by time
- Compressed historical data
- Retention policies

**Query Optimization:**
- N+1 prevention via Ash preloads
- Dataloader for batch loading
- Pagination on all list endpoints
- Aggregate queries pushed to database

### Caching Strategy

**Redis Layers:**
- Session store
- API response cache
- Query result cache
- Rate limiting counters

**ETS Tables:**
- Usage event buffer (high write volume)
- Hot lookup tables (entity_types, status_types)
- Process registry

### Horizontal Scaling

**Stateless Web Nodes:**
- Phoenix cluster with Horde
- Shared PubSub (Redis adapter)
- Session affinity not required

**Background Job Distribution:**
- Oban queue distribution
- Per-tenant job isolation
- Priority-based scheduling

**Database Scaling:**
- Read replicas
- Connection pooling via PgBouncer
- Tenant schema sharding (future)

---

## Deployment Architecture

### Infrastructure Components

**Container Orchestration:**
- Docker Swarm or Kubernetes
- Multi-node cluster
- Auto-scaling based on load

**Services:**
- PostgreSQL 17+ with replication
- Redis cluster (3 nodes minimum)
- MinIO cluster (distributed mode)
- HashiCorp Vault (HA mode)
- Meilisearch cluster

**Load Balancing:**
- Traefik or HAProxy
- SSL termination
- Health checks
- WebSocket support

**Monitoring:**
- Grafana dashboards
- Prometheus metrics
- Loki log aggregation
- Application telemetry

### Deployment Strategy

**Zero-Downtime Deployments:**
- Rolling updates
- Health check validation
- Automatic rollback on failure

**Database Migrations:**
- Ecto migrations
- Tenant schema migrations via Reactor
- Backward-compatible changes only

**Environment Configuration:**
- Environment variables
- Vault for secrets
- Runtime configuration via Mcp.Core.Repo.init/2

---

## Development Workflow

### Project Initialization

**Setup Commands:**
```bash
mix setup                    # Dependencies + database + assets
mix ecto.setup              # Create + migrate + seed
mix phx.server              # Start dev server
iex -S mix phx.server       # With IEx console
```

**Infrastructure:**
```bash
docker-compose up -d        # Start PostgreSQL, Redis, MinIO, Vault
docker-compose down         # Stop all services
```

### Code Quality

**Pre-Commit Checks:**
```bash
mix precommit               # Compile + credo + format check + test
mix quality                 # Compile + credo + dialyzer
mix check                   # Full suite
```

**Testing:**
```bash
mix test                    # All tests
mix test --failed           # Failed tests only
mix test --cover            # With coverage
```

**Formatting:**
```bash
mix format                  # Format code
mix format --check-formatted  # Check only
```

---

## Architecture Decision Records

### ADR-001: Schema-Based Multi-Tenancy

**Decision:** Use PostgreSQL schemas (acq_{tenant}) instead of shared tables with tenant_id
**Rationale:** Complete data isolation, simpler queries, better performance
**Trade-offs:** More complex migrations, schema proliferation
**Status:** Accepted

### ADR-002: NO PostgreSQL ENUMs

**Decision:** Replace ALL ENUMs with lookup tables
**Rationale:** ENUMs require migrations to change, cause table locks
**Benefits:** Runtime extensibility, no deployment for type changes
**Status:** Accepted

### ADR-003: Entity-Scoped User Profiles

**Decision:** Separate user profiles per entity (not global profile)
**Rationale:** Users need different professional identities per context
**Example:** Same user is "Alice Developer" (Tenant A), "Alice Admin" (Merchant B)
**Status:** Accepted

### ADR-004: Path-Based Portal Routing

**Decision:** Use paths (tenant.base.do/underwriting/) not subdomains (underwriting.tenant.base.do)
**Rationale:** Simpler SSL, shared session, tighter integration
**Benefits:** Single domain certificate, consistent UX
**Status:** Accepted

### ADR-005: Reseller Custom Domains

**Decision:** Support custom domains for resellers (apply.resellerbrand.com)
**Rationale:** Full white-label experience for reseller-branded applications
**Pricing:** Same as tenant/merchant ($10/month on Starter, free on Pro)
**Status:** Accepted

### ADR-006: Stripe-Style API Versioning

**Decision:** Header-based versioning (API-Version: 2025-11-17), NOT path-based (/v1/)
**Rationale:** Cleaner URLs, flexible version management, account defaults
**Status:** Accepted

### ADR-007: Admin-Only API Key Creation

**Decision:** Separate developer portal access from API key creation rights
**Rationale:** Security - prevent privilege escalation
**Implementation:** is_developer flag (portal access), API key creation requires admin or team permission
**Status:** Accepted

### ADR-008: Hybrid AI Strategy (Phase 2+)

**Decision:** OpenRouter for conversational AI, Local Ollama for core ML
**Rationale:** Latest models for UX, cost control for high-volume inference
**Cost Management:** Per-token tracking, tenant upcharging, usage quotas
**Status:** Accepted

### ADR-009: Mock-First Plugin Architecture (Phase 2+)

**Decision:** All external integrations start as mocks, adapter pattern for seamless switching
**Rationale:** Accelerate development, eliminate external dependencies initially
**Migration:** Tenant-controlled activation of live services
**Status:** Accepted

### ADR-010: Flexible Billing via JSONB

**Decision:** Store pricing config in JSONB (not hardcoded schema)
**Rationale:** Business model will evolve, avoid schema migrations
**Deferred:** Commission models, cost allocation, payout mechanisms
**Status:** Accepted

### ADR-011: OTP Supervision: Stateful vs Stateless Separation

**Decision:** Ash Domains stateless (just modules), Infrastructure/Services stateful (GenServers)
**Rationale:** Clear separation, fault isolation, Elixir best practices
**Pattern:** Infrastructure (:rest_for_one), Services (:one_for_one)
**Status:** Accepted

---

## Appendix: File Locations

**Schema Definitions:**
- `/docs/schemas/00-lookup-tables-schema.md`
- `/docs/schemas/01-platform-users-schema.md`
- `/docs/schemas/02-user-profiles-schema.md`
- `/docs/schemas/03-tenants-schema.md`
- `/docs/schemas/04-merchants-schema.md`
- `/docs/schemas/05-mids-stores-customers-schema.md`
- `/docs/schemas/06-polymorphic-shared-entities-schema.md`

**Decisions:**
- `/docs/my-schema-decisions.md` - All 24 finalized schema decisions
- `/docs/architecture-refinement-decisions-2025-11-17.md` - 11 architectural refinements

**Features:**
- `/docs/features/ai-merchant-underwriting.md` - Complete OLA/PAYFAC specification

**Context:**
- `/docs/domain-brief.md` - Functional requirements
- `/docs/architecture-session-context.md` - Complete architecture discussions

**External:**
- `/Users/rp/Developer/Base/OLA/docs/prd.md` - AI Underwriting PRD

---

**Document Version:** 1.0
**Last Updated:** 2025-11-17
**Ready for Implementation:** ✅
**Next Step:** Create epics and stories via `/bmad:bmm:workflows:create-epics-and-stories`
