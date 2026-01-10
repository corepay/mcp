# Developer Entity

> **Last Updated**: 2026-01-10 | **Code Verified**: Yes

## Overview

A **Developer** (also called an API Partner) is an organization that integrates with the MCP platform via APIs. Developers build applications, plugins, or services that extend the platform's functionality.

### Business Context

Developers are **technical partners** that create value through integration. They may be:
- ISV (Independent Software Vendors) building payment integrations
- SaaS platforms adding merchant services
- Fintech companies using APIs for their products
- System integrators building custom solutions

### Key Characteristics

| Aspect | Implementation |
|--------|----------------|
| Authentication | API keys per tenant |
| Rate Limits | Daily and monthly quotas |
| Revenue | Optional revenue share on usage |
| Notifications | Webhook-based event delivery |

---

## Current State

### Data Model

**Resource**: `Mcp.Platform.Developer`
**Table**: `developers` (global schema)
**Multitenancy**: Global (not tenant-scoped)
**Archival**: ✅ Soft-delete enabled (AshArchival)

#### Core Attributes

| Attribute | Type | Status | Description |
|-----------|------|--------|-------------|
| `id` | UUID | ✅ | Primary key |
| `company_name` | String | ✅ | Business name |
| `contact_name` | String | ✅ | Primary contact |
| `contact_email` | String | ✅ | Primary email |
| `contact_phone` | String | ✅ | Primary phone |
| `technical_contact_email` | String | ✅ | Technical support email |
| `admin_contact_email` | String | ✅ | Admin contact email |
| `support_phone` | String | ✅ | Support phone |
| `webhook_url` | String | ✅ | Webhook delivery URL |
| `webhook_secret` | String | ✅ | Webhook auth secret |
| `webhook_events` | Array[String] | ✅ | Subscribed event types |
| `webhook_signing_secret` | String | ✅ | Signing key (sensitive) |
| `app_type` | String | ✅ | `public` (default) |
| `revenue_share_percentage` | Decimal | ✅ | Revenue share % |
| `payout_settings` | Map | ✅ | Payout config (sensitive) |
| `api_quota_daily` | Integer | ✅ | Daily API limit (default: 1000) |
| `api_quota_monthly` | Integer | ✅ | Monthly API limit (default: 10000) |
| `status` | Atom | ✅ | `active`, `suspended`, `pending` |
| `inserted_at` | DateTime | ✅ | Created timestamp |
| `updated_at` | DateTime | ✅ | Modified timestamp |

#### Relationships

| Relationship | Type | Target | Status |
|--------------|------|--------|--------|
| `user` | belongs_to | `Accounts.User` | ✅ |
| `resellers` | has_many | `Platform.Reseller` | ✅ |

#### Available Actions

| Action | Status | Description |
|--------|--------|-------------|
| `create` | ✅ | Create developer |
| `read` | ✅ | List/query developers |
| `update` | ✅ | Modify developer |
| `destroy` | ✅ | Soft-delete developer |

### Tenant-Developer Bridge

**Resource**: `Mcp.Platform.DeveloperTenant`
**Purpose**: Links developers to tenants with specific permissions

This join resource enables:
- One developer to work with multiple tenants
- Per-tenant permission configuration
- API key scoping

### Portal / UI

**Route Prefix**: `/developers`
**Layout**: `developer_portal_layout`

| Route | LiveView | Status | Description |
|-------|----------|--------|-------------|
| `/developers/sign-in` | `AuthLive.Login` | ✅ | Authentication |
| `/developers/` | `LandingLive` | ✅ | Landing page |
| `/developers/dashboard` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |
| `/developers/apps` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |
| `/developers/docs` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |

### API

| Endpoint | Method | Status | Description |
|----------|--------|--------|-------------|
| JSON:API `/developer` | GET | ✅ | List developers |
| JSON:API `/developer/:id` | GET | ✅ | Get developer |
| JSON:API `/developer` | POST | ✅ | Create developer |
| JSON:API `/developer/:id` | PATCH | ✅ | Update developer |
| JSON:API `/developer/:id` | DELETE | ✅ | Archive developer |

### Tests

| Test File | Coverage |
|-----------|----------|
| No dedicated test file | ⚠️ Missing |

---

## Gaps

### Critical Gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| ⚠️ **Dashboard** | No functional dashboard | High |
| ⚠️ **App Management** | Cannot create/manage apps | High |
| ⚠️ **Documentation Portal** | No API docs access | High |
| ⚠️ **API Key Management** | UI missing for key generation | High |
| ⚠️ **No Tests** | Zero test coverage | High |

### Missing Features

| Feature | Description | Priority |
|---------|-------------|----------|
| API Key Generation | Self-service key creation | High |
| Webhook Testing | Test webhook delivery | High |
| API Usage Dashboard | Request counts, errors, latency | High |
| Documentation Browser | Interactive API docs | High |
| Sandbox Environment | Test mode with mock data | High |
| App Registration | Register OAuth apps | Medium |
| SDK Downloads | Client library downloads | Medium |
| Changelog | API version history | Medium |
| Rate Limit Dashboard | View quota usage | Medium |
| Support Ticketing | Developer support requests | Low |

---

## Recommendations

### Short-Term (0-30 days)

1. **Implement Developer Dashboard**
   - API usage summary
   - Recent webhook deliveries
   - Quick links to docs/keys

2. **API Key Management UI**
   - List existing keys
   - Generate new keys
   - Revoke keys
   - Key permissions/scopes

3. **Webhook Configuration**
   - Set webhook URL
   - Select event subscriptions
   - Test webhook delivery
   - View delivery history

4. **Add Test Coverage**
   - CRUD operations
   - DeveloperTenant linking
   - Quota enforcement

### Medium-Term (30-90 days)

1. **API Documentation Portal**
   - OpenAPI/Swagger integration
   - Interactive "try it" console
   - Code examples in multiple languages
   - Authentication guide

2. **Sandbox Environment**
   - Test API keys (no real transactions)
   - Mock webhook events
   - Sample data generation

3. **Usage Analytics**
   - Request volume charts
   - Error rate tracking
   - Endpoint popularity
   - Response time metrics

### Long-Term (90+ days)

1. **App Marketplace**
   - Public app directory
   - App review/approval workflow
   - User ratings/reviews
   - Installation tracking

2. **OAuth 2.0 Support**
   - Full OAuth flow for user authorization
   - Refresh token management
   - Scope-based permissions

3. **Developer Tiers**
   - Free/Pro/Enterprise tiers
   - Tier-based rate limits
   - Premium support options

---

## Opportunities

### Revenue Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **API Usage Fees** | Charge per request above quota | Medium |
| **Premium API Access** | Higher rate limits for fee | Low |
| **Marketplace Commission** | % of paid app revenue | High |
| **Priority Support** | Paid developer support | Low |

### Product Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **API Playground** | Browser-based API testing | Medium |
| **SDK Generation** | Auto-generate client SDKs | Medium |
| **Code Snippets** | Copy-paste integration code | Low |
| **Developer Blog** | Technical content, tutorials | Low |

### Technical Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **GraphQL API** | Alternative to REST | High |
| **Async API (Webhooks v2)** | Better webhook reliability | Medium |
| **API Versioning** | Header-based version control | Low |
| **Request Logging** | Debug log access | Medium |

---

## Invitation Model

Per the domain brief, developer onboarding uses email-based invitations:

| Step | Description |
|------|-------------|
| 1 | Tenant admin invites developer via email |
| 2 | Invitation includes permission scope |
| 3 | 24-hour expiration |
| 4 | Developer accepts, gains access |
| 5 | Tenant can revoke/refresh invitations |

---

## Related Entities

- **Tenant** - Organization that invites developer
- **Reseller** - Sales partners under developer
- **DeveloperTenant** - Permission bridge
- **ApiKey** - Authentication credentials
- **User** - Developer's login account

---

*Source: `lib/mcp/platform/developer.ex`, `lib/mcp/platform/developer_tenant.ex`, `lib/mcp_web/router.ex`*
