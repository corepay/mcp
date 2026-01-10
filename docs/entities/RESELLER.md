# Reseller Entity

> **Last Updated**: 2026-01-10 | **Code Verified**: Yes

## Overview

A **Reseller** (also called a Partner) is a sales channel that acquires merchants on behalf of a tenant. Resellers earn commissions on the merchants they bring to the platform and manage their merchant portfolio.

### Business Context

Resellers are the **sales arm** of your tenant customers. They may be:
- Independent Sales Agents (ISAs)
- Referral Partners
- White-Label Resellers
- Value-Added Resellers (VARs)

### Key Characteristics

| Aspect | Implementation |
|--------|----------------|
| Relationship | Belongs to a Developer (parent) |
| Compensation | Commission rate on merchant volume |
| Branding | Own white-label configuration |
| Access | Limited to payment processing data (no customer PII) |

---

## Current State

### Data Model

**Resource**: `Mcp.Platform.Reseller`
**Table**: `resellers` (global schema)
**Multitenancy**: Global (not tenant-scoped)
**Archival**: ✅ Soft-delete enabled (AshArchival)

#### Core Attributes

| Attribute | Type | Status | Description |
|-----------|------|--------|-------------|
| `id` | UUID | ✅ | Primary key |
| `slug` | String | ✅ | URL-safe identifier |
| `company_name` | String | ✅ | Business name |
| `subdomain` | String | ✅ | Reseller portal subdomain |
| `custom_domain` | String | ✅ | Optional custom domain |
| `contact_name` | String | ✅ | Primary contact |
| `contact_email` | String | ✅ | Primary email |
| `contact_phone` | String | ✅ | Primary phone |
| `commission_rate` | Decimal | ✅ | Default commission % |
| `revenue_share_model` | Map | ✅ | Complex revenue share rules |
| `banking_info` | Map | ✅ | Payout details (sensitive) |
| `tax_id` | String | ✅ | Tax identification |
| `contract_start_date` | Date | ✅ | Agreement start |
| `contract_end_date` | Date | ✅ | Agreement end |
| `support_tier` | Atom | ✅ | `standard`, `priority` |
| `branding` | Map | ✅ | White-label config |
| `settings` | Map | ✅ | General settings |
| `max_merchants` | Integer | ✅ | Merchant cap (default: 50) |
| `status` | Atom | ✅ | `active`, `suspended`, `pending` |
| `inserted_at` | DateTime | ✅ | Created timestamp |
| `updated_at` | DateTime | ✅ | Modified timestamp |

#### Relationships

| Relationship | Type | Target | Status |
|--------------|------|--------|--------|
| `user` | belongs_to | `Accounts.User` | ✅ |
| `developer` | belongs_to | `Platform.Developer` | ✅ |
| `merchants` | has_many | `Platform.Merchant` | ✅ |

#### Available Actions

| Action | Status | Description |
|--------|--------|-------------|
| `create` | ✅ | Create reseller |
| `read` | ✅ | List/query resellers |
| `update` | ✅ | Modify reseller |
| `destroy` | ✅ | Soft-delete reseller |

### Portal / UI

**Route Prefix**: `/partners`
**Layout**: `reseller_portal_layout`

| Route | LiveView | Status | Description |
|-------|----------|--------|-------------|
| `/partners/sign-in` | `AuthLive.Login` | ✅ | Authentication |
| `/partners/` | `LandingLive` | ✅ | Landing page |
| `/partners/dashboard` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |
| `/partners/applications` | `Reseller.ApplicationsLive` | ✅ | Application list |
| `/partners/applications/:id` | `Reseller.UnderwritingApplicationLive` | ✅ | Application detail |
| `/partners/merchants` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |
| `/partners/commissions` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |

### API

| Endpoint | Method | Status | Description |
|----------|--------|--------|-------------|
| JSON:API `/reseller` | GET | ✅ | List resellers |
| JSON:API `/reseller/:id` | GET | ✅ | Get reseller |
| JSON:API `/reseller` | POST | ✅ | Create reseller |
| JSON:API `/reseller/:id` | PATCH | ✅ | Update reseller |
| JSON:API `/reseller/:id` | DELETE | ✅ | Archive reseller |

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
| ⚠️ **Merchant List** | Cannot view merchant portfolio | High |
| ⚠️ **Commission Tracking** | No commission calculation/display | High |
| ⚠️ **No Tests** | Zero test coverage | High |

### Missing Features

| Feature | Description | Priority |
|---------|-------------|----------|
| Commission Calculator | Calculate earnings from merchant volume | High |
| Payout Management | Request/view payout history | High |
| Merchant Portfolio View | Full merchant list with stats | High |
| Application Submission | Submit new merchant applications | High |
| Performance Metrics | Sales metrics, conversion rates | Medium |
| Lead Management | Track merchant prospects | Medium |
| Contract Management | View/accept agreements | Medium |
| Referral Links | Trackable signup links | Low |
| Marketing Materials | Downloadable assets | Low |

---

## Recommendations

### Short-Term (0-30 days)

1. **Implement Reseller Dashboard**
   - Portfolio summary (merchant count, total volume)
   - Recent applications status
   - Commission summary (MTD, YTD)
   - Quick actions

2. **Add Merchant Portfolio View**
   - List merchants with status, volume, commission
   - Search and filter
   - Link to application details

3. **Basic Commission Tracking**
   - Display commission rate
   - Calculate estimated earnings
   - Show pending vs paid

4. **Add Test Coverage**
   - CRUD operations
   - Relationship tests
   - Commission calculations

### Medium-Term (30-90 days)

1. **Commission Engine**
   - Support complex revenue share models
   - Tiered commission structures
   - Override rates per merchant

2. **Payout System**
   - Integration with Finance domain
   - Payout request workflow
   - ACH/wire transfer support
   - 1099 generation

3. **Application Submission Flow**
   - Pre-fill merchant applications
   - Track referred applications
   - Notification on status changes

### Long-Term (90+ days)

1. **Partner Portal Enhancements**
   - White-label the reseller portal itself
   - Custom reporting
   - API access for integrations

2. **Advanced Analytics**
   - Funnel analysis (leads → merchants)
   - Merchant lifetime value
   - Churn prediction

3. **Tiered Partner Program**
   - Bronze/Silver/Gold levels
   - Automatic tier advancement
   - Tier-based commission rates

---

## Opportunities

### Revenue Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Partner Program Fees** | Annual partner certification fee | Low |
| **Premium Support Tier** | Charge for priority support | Low |
| **Marketing Co-op** | Shared marketing fund | Medium |
| **Lead Gen Services** | Sell qualified leads to partners | High |

### Product Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Reseller Mobile App** | On-the-go portfolio management | High |
| **CRM Integration** | Sync with Salesforce, HubSpot | Medium |
| **E-Signature Integration** | DocuSign for merchant apps | Medium |
| **Commission Advances** | Early payout option | Medium |

### Technical Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Commission Audit Trail** | Full history of rate changes | Low |
| **Automated Tier Management** | Rules-based tier advancement | Medium |
| **Multi-Currency Commissions** | Support international resellers | Medium |

---

## Data Visibility Rules

Resellers have restricted data access per the domain brief:

| Data Type | Can See? | Notes |
|-----------|----------|-------|
| Merchant payment data | ✅ Yes | MIDs, gateways, volume |
| Merchant business data | ❌ No | Customers, products, pricing |
| Merchant PII | ❌ No | SSN, bank accounts |
| Application status | ✅ Yes | Submitted applications |
| Commission data | ✅ Yes | Own earnings only |

---

## Related Entities

- **Tenant** - Parent organization
- **Developer** - API partner (can have resellers)
- **Merchant** - Businesses brought by reseller
- **User** - Reseller's login account

---

*Source: `lib/mcp/platform/reseller.ex`, `lib/mcp_web/router.ex`, `lib/mcp_web/live/reseller/`*
