# Merchant Entity

> **Last Updated**: 2026-01-10 | **Code Verified**: Yes

## Overview

A **Merchant** is a business entity that processes payments through the platform. Merchants are the core revenue-generating entities - they have customers, process transactions, and pay fees for the service.

### Business Context

Merchants are the **end customers** of the payment processing service. They may be:
- Retail businesses (brick-and-mortar, e-commerce)
- Service providers (SaaS, professional services)
- Marketplaces (multi-vendor platforms)
- Subscription businesses

### Key Characteristics

| Aspect | Implementation |
|--------|----------------|
| Scope | Tenant-scoped (isolated data) |
| Verification | KYC/KYB required for processing |
| Processing | Via MIDs (payment gateway accounts) |
| Structure | Can have multiple stores, customers, vendors |

---

## Current State

### Data Model

**Resource**: `Mcp.Platform.Merchant`
**Table**: `merchants` (tenant schema)
**Multitenancy**: ✅ Context strategy (tenant-scoped)
**Archival**: ✅ Soft-delete enabled

#### Core Attributes

| Attribute | Type | Status | Description |
|-----------|------|--------|-------------|
| `id` | UUID | ✅ | Primary key |
| `slug` | String | ✅ | URL-safe identifier |
| `business_name` | String | ✅ | Legal business name |
| `dba_name` | String | ✅ | "Doing Business As" name |
| `subdomain` | String | ✅ | Merchant portal subdomain |
| `custom_domain` | String | ✅ | Optional custom domain |
| `business_type` | Atom | ✅ | `sole_proprietor`, `llc`, `corporation`, `partnership`, `nonprofit` |
| `ein` | String | ✅ | Employer Identification Number |
| `website_url` | String | ✅ | Business website |
| `description` | String | ✅ | Business description |
| `address_line1` | String | ✅ | Street address |
| `address_line2` | String | ✅ | Suite/unit |
| `city` | String | ✅ | City |
| `state` | String | ✅ | State/province |
| `postal_code` | String | ✅ | ZIP/postal code |
| `country` | String | ✅ | Country (default: "US") |
| `phone` | String | ✅ | Business phone |
| `support_email` | String | ✅ | Support email |
| `plan` | Atom | ✅ | `starter`, `professional`, `enterprise` |
| `status` | Atom | ✅ | `active`, `suspended`, `pending_verification`, `closed` |
| `settings` | Map | ✅ | General settings |
| `branding` | Map | ✅ | White-label config |
| `max_stores` | Integer | ✅ | Store limit |
| `max_products` | Integer | ✅ | Product limit |
| `max_monthly_volume` | Decimal | ✅ | Processing cap |
| `risk_level` | Atom | ✅ | `low`, `medium`, `high` |
| `risk_score` | Integer | ✅ | Calculated risk score |
| `risk_profile` | Atom | ✅ | `low`, `medium`, `high` |
| `kyc_verified_at` | DateTime | ✅ | Verification timestamp |
| `kyc_status` | Atom | ✅ | `pending`, `verified`, `rejected`, `manual_review` |
| `kyc_documents` | Map | ✅ | Document references (sensitive) |
| `verification_status` | Atom | ✅ | `pending`, `verified`, `rejected` |
| `mcc` | String | ✅ | Merchant Category Code |
| `tax_id_type` | Atom | ✅ | `ein`, `ssn` |
| `timezone` | String | ✅ | Default: "UTC" |
| `default_currency` | String | ✅ | Default: "USD" |
| `operating_hours` | Map | ✅ | Business hours |
| `processing_limits` | Map | ✅ | Transaction limits |

#### Relationships

| Relationship | Type | Target | Status |
|--------------|------|--------|--------|
| `reseller` | belongs_to | `Platform.Reseller` | ✅ |
| `stores` | has_many | `Platform.Store` | ✅ |
| `mids` | has_many | `Platform.MID` | ✅ |
| `account` | has_one | `Finance.Account` | ✅ |
| `underwriting_applications` | has_many | `Underwriting.Application` | ✅ |
| `risk_assessments` | has_many | `Underwriting.RiskAssessment` | ✅ |

#### Available Actions

| Action | Status | Description |
|--------|--------|-------------|
| `create` | ✅ | Create merchant |
| `read` | ✅ | List/query merchants |
| `update` | ✅ | Modify merchant |
| `destroy` | ✅ | Soft-delete merchant |
| `by_slug` | ✅ | Lookup by slug |

### Portal / UI

**Route Prefix**: `/app`
**Layout**: `merchant_portal_layout`

| Route | LiveView | Status | Description |
|-------|----------|--------|-------------|
| `/app/sign-in` | `AuthLive.Login` | ✅ | Authentication |
| `/app/` | `LandingLive` | ✅ | Landing page |
| `/app/dashboard` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |
| `/app/orders` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |
| `/app/products` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |
| `/app/customers` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |

### API

| Endpoint | Method | Status | Description |
|----------|--------|--------|-------------|
| JSON:API `/merchant` | GET | ✅ | List merchants |
| JSON:API `/merchant/:id` | GET | ✅ | Get merchant |
| JSON:API `/merchant` | POST | ✅ | Create merchant |
| JSON:API `/merchant/:id` | PATCH | ✅ | Update merchant |
| JSON:API `/merchant/:id` | DELETE | ✅ | Archive merchant |

### Tests

| Test File | Coverage |
|-----------|----------|
| `test/mcp/platform/shared_entities_test.exs` | Partial |

---

## Gaps

### Critical Gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| ⚠️ **Dashboard** | No functional merchant dashboard | Critical |
| ⚠️ **Orders View** | Cannot view transactions | Critical |
| ⚠️ **Products Management** | No product catalog | High |
| ⚠️ **Customer Management** | No CRM functionality | High |
| ⚠️ **Reporting** | No analytics/reports | High |

### Missing Features

| Feature | Description | Priority |
|---------|-------------|----------|
| Transaction Dashboard | Real-time transaction view | Critical |
| Settlement Reports | Daily/weekly settlements | Critical |
| Chargeback Management | Dispute handling | Critical |
| Product Catalog | SKU management | High |
| Customer CRM | Customer profiles, history | High |
| Invoice Generation | Create/send invoices | High |
| Subscription Management | Recurring billing | High |
| Staff Management | User roles for merchant | Medium |
| Reporting/Analytics | Sales, trends, forecasts | Medium |
| API Access | Merchant-level API keys | Medium |
| PCI Compliance Tools | Compliance dashboard | Medium |
| Tax Configuration | Tax rates, nexus | Low |

---

## Recommendations

### Short-Term (0-30 days)

1. **Implement Merchant Dashboard**
   - Today's transactions summary
   - Settlement status
   - Key metrics (volume, avg ticket)
   - Quick actions

2. **Transaction View**
   - List all transactions
   - Search/filter by date, amount, status
   - Transaction details
   - Refund capability

3. **Basic Reporting**
   - Daily summary report
   - Settlement report
   - Export to CSV

### Medium-Term (30-90 days)

1. **Product Catalog**
   - SKU management
   - Pricing tiers
   - Inventory tracking (optional)
   - Product images

2. **Customer Management**
   - Customer profiles
   - Purchase history
   - Saved payment methods
   - Communication history

3. **Invoice/Billing**
   - Create invoices
   - Send via email
   - Online payment links
   - Recurring invoices

### Long-Term (90+ days)

1. **Advanced Analytics**
   - Sales trends
   - Customer lifetime value
   - Churn analysis
   - Forecasting

2. **Subscription Engine**
   - Plan creation
   - Trial management
   - Proration handling
   - Dunning management

3. **Multi-Location Support**
   - Store comparison
   - Consolidated reporting
   - Staff scheduling

---

## Opportunities

### Revenue Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Premium Features** | Advanced reporting, API access | Medium |
| **Transaction Fees** | Per-transaction processing | Built-in |
| **PCI Compliance Add-on** | Compliance toolkit subscription | Medium |
| **Marketing Tools** | Email/SMS marketing integration | High |

### Product Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Mobile POS App** | iOS/Android card reader app | High |
| **E-commerce Plugin** | Shopify, WooCommerce integration | Medium |
| **Loyalty Program** | Points/rewards system | Medium |
| **Gift Cards** | Gift card issuance/redemption | Medium |

### Technical Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Merchant API** | Self-service integration | Medium |
| **Webhooks** | Event notifications | Low |
| **Batch Processing** | Bulk transaction upload | Medium |
| **White-Label Mobile** | Branded merchant app | High |

---

## Related Entities

- **Tenant** - Parent organization
- **Reseller** - Sales partner (if applicable)
- **Store** - Operating locations
- **MID** - Payment gateway accounts
- **Customer** - End consumers
- **Vendor** - Suppliers

---

*Source: `lib/mcp/platform/merchant.ex`, `lib/mcp_web/router.ex`*
