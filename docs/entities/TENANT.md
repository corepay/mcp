# Tenant Entity

> **Last Updated**: 2026-01-10 | **Code Verified**: Yes

## Overview

A **Tenant** represents an organization that uses the MCP platform - typically an ISO (Independent Sales Organization), a reseller network, or a large enterprise. Each tenant operates as a fully isolated environment with their own merchants, data, and branding.

### Business Context

Tenants are your **direct customers** - the organizations that pay to use the platform. They may:
- Operate a white-labeled merchant services platform
- Manage a portfolio of merchants
- Offer payment processing to their downstream customers
- Run an ISO or Payment Facilitator operation

### Key Characteristics

| Aspect | Implementation |
|--------|----------------|
| Data Isolation | Dedicated PostgreSQL schema (`acq_{uuid}`) |
| Branding | Full white-label (colors, logo, fonts) |
| Domain | Custom domain or subdomain |
| Pricing | Per-plan feature access |

---

## Current State

### Data Model

**Resource**: `Mcp.Platform.Tenant`
**Table**: `platform.tenants`
**Multitenancy**: Global (not tenant-scoped)

#### Core Attributes

| Attribute | Type | Status | Description |
|-----------|------|--------|-------------|
| `id` | UUID | ✅ | Primary key |
| `name` | String | ✅ | Display name |
| `slug` | String | ✅ | URL-safe identifier (lowercase, alphanumeric, hyphens) |
| `company_schema` | String | ✅ | PostgreSQL schema name (`acq_*`) |
| `subdomain` | String | ✅ | Tenant subdomain |
| `custom_domain` | String | ✅ | Optional custom domain |
| `plan` | Atom | ✅ | `starter`, `professional`, `enterprise` |
| `status` | Atom | ✅ | `active`, `trial`, `suspended`, `canceled` |
| `features` | Map | ✅ | Feature flags (JSON) |
| `settings` | Map | ✅ | General settings (JSON) |
| `inserted_at` | DateTime | ✅ | Created timestamp |
| `updated_at` | DateTime | ✅ | Modified timestamp |

#### Relationships

| Relationship | Type | Target | Status |
|--------------|------|--------|--------|
| `account` | has_one | `Finance.Account` | ✅ |
| `branding` | has_one | `TenantBranding` | ✅ |
| `settings` | - | `TenantSettings` | ⚠️ Commented out |

#### Available Actions

| Action | Status | Description |
|--------|--------|-------------|
| `create` | ✅ | Creates tenant + provisions schema |
| `read` | ✅ | List/query tenants |
| `update` | ✅ | Modify tenant attributes |
| `destroy` | ✅ | Delete tenant |
| `suspend` | ✅ | Set status to suspended |
| `activate` | ✅ | Set status to active |
| `cancel` | ✅ | Set status to canceled |
| `update_plan` | ✅ | Change pricing plan |
| `complete_onboarding` | ⚠️ | Stub - no logic |
| `by_subdomain` | ✅ | Lookup by subdomain |
| `by_custom_domain` | ✅ | Lookup by custom domain |
| `by_slug` | ✅ | Lookup by slug |
| `by_status` | ✅ | Filter by status |
| `by_plan` | ✅ | Filter by plan |
| `get_by_schema` | ✅ | Lookup by schema name |

### Supporting Resources

#### TenantSettings

**Resource**: `Mcp.Platform.TenantSettings`
**Status**: ✅ Complete

Flexible key-value settings storage with categories.

| Category | Examples |
|----------|----------|
| `general` | Timezone, language |
| `billing` | Payment terms, currency |
| `business_info` | Legal name, tax ID |
| `security` | Password policies |
| `notifications` | Email preferences |
| `integrations` | Third-party configs |
| `feature` | Feature toggles |

Features:
- Type-safe values (string, integer, float, boolean, map, array, json)
- Optional encryption for sensitive values
- Validation rules support
- Upsert capability

#### TenantBranding

**Resource**: `Mcp.Platform.TenantBranding`
**Status**: ✅ Complete

White-label theming configuration.

| Attribute | Type | Description |
|-----------|------|-------------|
| `name` | String | Branding profile name |
| `primary_color` | String | Primary brand color |
| `secondary_color` | String | Secondary color |
| `accent_color` | String | Accent color |
| `background_color` | String | Background color |
| `text_color` | String | Text color |
| `theme` | Atom | `light`, `dark`, `system` |
| `font_family` | String | Primary font |
| `logo_url` | String | Logo asset URL |
| `is_active` | Boolean | Currently active branding |

Features:
- Multiple branding profiles per tenant
- Only one active at a time
- Auto-activates first branding
- CSS variable generation

### Portal / UI

**Route Prefix**: `/tenant`
**Layout**: `tenant_portal_layout`

| Route | LiveView | Status | Description |
|-------|----------|--------|-------------|
| `/tenant/sign-in` | `AuthLive.Login` | ✅ | Authentication |
| `/tenant/dashboard` | `Tenant.DashboardLive` | ✅ | Main dashboard |
| `/tenant/applications` | `Tenant.ApplicationsLive` | ✅ | Application list |
| `/tenant/applications/:id` | `Tenant.ApplicationDetailLive` | ✅ | Application detail |
| `/tenant/settings` | `TenantSettingsLive` | ✅ | Settings management |
| `/tenant/merchants` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |
| `/tenant/gdpr` | `GdprLive` | ✅ | GDPR management |
| `/tenant/underwriting` | `Tenant.UnderwritingLive` | ✅ | UW queue |
| `/tenant/underwriting/board` | `Tenant.Underwriting.KanbanLive` | ✅ | Kanban board |
| `/tenant/underwriting/settings` | `Tenant.Underwriting.SettingsLive` | ✅ | UW config |
| `/tenant/underwriting/:id` | `Tenant.ReviewLive` | ✅ | Application review |
| `/tenant/settings/api-keys` | `Settings.ApiKeysLive` | ✅ | API key management |
| `/tenant/settings/custom-domains` | `Settings.CustomDomainsLive` | ✅ | Domain settings |
| `/tenant/settings/webhooks` | `Settings.WebhooksLive` | ✅ | Webhook config |

### API

| Endpoint | Method | Status | Description |
|----------|--------|--------|-------------|
| JSON:API `/tenant` | GET | ✅ | List tenants |
| JSON:API `/tenant/:id` | GET | ✅ | Get tenant |
| JSON:API `/tenant` | POST | ✅ | Create tenant |
| JSON:API `/tenant/:id` | PATCH | ✅ | Update tenant |
| JSON:API `/tenant/:id` | DELETE | ✅ | Delete tenant |

### Tests

| Test File | Coverage |
|-----------|----------|
| `test/mcp/platform/tenant_test.exs` | Core CRUD |
| `test/mcp/platform/tenant_settings_test.exs` | Settings |
| `test/mcp/platform/schema_provisioner_test.exs` | Schema creation |
| `test/mcp/platform/tenant_migration_manager_test.exs` | Migrations |

---

## Gaps

### Critical Gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| ⚠️ **Merchant Management UI** | Route exists but uses MockDashboardLive | High |
| ⚠️ **Onboarding Workflow** | `complete_onboarding` action is a stub | Medium |
| ⚠️ **TenantSettings relationship** | Commented out in Tenant resource | Low |

### Missing Features

| Feature | Description | Priority |
|---------|-------------|----------|
| Tenant Analytics Dashboard | Usage metrics, merchant counts, volume | High |
| Billing Integration | Subscription management, invoicing | High |
| Reseller Management UI | View/manage assigned resellers | Medium |
| Developer Management UI | View/manage API developers | Medium |
| Audit Log Viewer | Activity history for tenant | Medium |
| Feature Flag UI | Toggle features from portal | Low |
| Tenant Provisioning Wizard | Guided setup flow | Low |

---

## Recommendations

### Short-Term (0-30 days)

1. **Implement Merchant Management LiveView**
   - Replace `MockDashboardLive` on `/tenant/merchants`
   - List merchants with search/filter
   - CRUD operations for merchants
   - Link to underwriting applications

2. **Complete TenantSettings Integration**
   - Uncomment relationship in Tenant resource
   - Add settings preloading where needed

3. **Implement Onboarding Flow**
   - Add logic to `complete_onboarding` action
   - Track onboarding completion steps
   - Surface incomplete setup in dashboard

### Medium-Term (30-90 days)

1. **Add Tenant Analytics**
   - Merchant count metrics
   - Transaction volume summaries
   - Application pipeline stats
   - Time-series charts

2. **Billing Module Integration**
   - Connect to `Mcp.Billing` domain
   - Display subscription status
   - Usage-based billing metrics

3. **Reseller/Developer Management**
   - Views to see assigned partners
   - Invitation workflows
   - Commission configuration for resellers

### Long-Term (90+ days)

1. **Self-Service Provisioning**
   - Public tenant signup flow
   - Trial period management
   - Automated schema provisioning

2. **Multi-Branding Campaigns**
   - Seasonal branding profiles
   - A/B testing for themes
   - Scheduled branding switches

---

## Opportunities

### Revenue Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Tiered Feature Gating** | Enforce plan-based feature access | Medium |
| **Usage-Based Billing** | Charge by merchant count, volume | High |
| **White-Label Markup** | Tenants set their own pricing | Medium |
| **Add-On Services** | Premium support, custom domains | Low |

### Product Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Tenant Marketplace** | Shared app/integration catalog | High |
| **Cross-Tenant Analytics** | Benchmarking against peers | Medium |
| **AI-Powered Insights** | Churn prediction, growth recommendations | High |
| **Tenant API Console** | Interactive API testing | Medium |

### Technical Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Schema Cloning** | Duplicate tenant for demos | Medium |
| **Tenant Export/Import** | Full data portability | High |
| **Read Replicas** | Per-tenant read scaling | High |
| **Tenant Hibernation** | Reduce costs for inactive | Medium |

---

## Related Entities

- **Reseller** - Sales partners that bring merchants
- **Developer** - API integration partners
- **Merchant** - Businesses managed by tenant
- **Team** - User groups with permissions

---

*Source: `lib/mcp/platform/tenant.ex`, `lib/mcp/platform/tenant_settings.ex`, `lib/mcp/platform/tenant_branding.ex`, `lib/mcp_web/router.ex`*
