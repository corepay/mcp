# Store Entity

> **Last Updated**: 2026-01-10 | **Code Verified**: Yes

## Overview

A **Store** represents an operating unit within a merchant - a physical location, online storefront, pop-up, or other distinct point-of-sale. Stores are where actual transactions occur.

### Business Context

Stores enable **multi-location and multi-channel** operations. They may be:
- Physical retail locations
- E-commerce storefronts
- Food trucks or pop-up shops
- B2B sales channels
- Franchise locations

### Key Characteristics

| Aspect | Implementation |
|--------|----------------|
| Scope | Tenant-scoped (via merchant) |
| Purpose | Operational unit for transactions |
| Routing | Path-based or subdomain routing |
| Processing | Assigned MID for payments |

---

## Current State

### Data Model

**Resource**: `Mcp.Platform.Store`
**Table**: `stores` (tenant schema)
**Multitenancy**: ✅ Context strategy
**Archival**: ✅ Soft-delete enabled

#### Core Attributes

| Attribute | Type | Status | Description |
|-----------|------|--------|-------------|
| `id` | UUID | ✅ | Primary key |
| `slug` | String | ✅ | URL-safe identifier |
| `name` | String | ✅ | Display name |
| `routing_type` | Atom | ✅ | `path` or `subdomain` |
| `subdomain` | String | ✅ | Store subdomain (optional) |
| `custom_domain` | String | ✅ | Custom domain (optional) |
| `geo_location` | Map | ✅ | Lat/lng coordinates |
| `tax_nexus` | Array[String] | ✅ | Tax jurisdictions |
| `store_type` | Atom | ✅ | `physical`, `online`, `hybrid`, `popup` |
| `store_manager_name` | String | ✅ | Manager contact |
| `store_phone` | String | ✅ | Store phone |
| `store_email` | String | ✅ | Store email |
| `settings` | Map | ✅ | Store-specific settings |
| `branding` | Map | ✅ | Store-level branding |
| `fallback_mid_ids` | Array[UUID] | ✅ | Backup MIDs |
| `status` | Atom | ✅ | `active`, `suspended`, `draft` |
| `inserted_at` | DateTime | ✅ | Created timestamp |
| `updated_at` | DateTime | ✅ | Modified timestamp |

#### Relationships

| Relationship | Type | Target | Status |
|--------------|------|--------|--------|
| `merchant` | belongs_to | `Platform.Merchant` | ✅ |
| `primary_mid` | belongs_to | `Platform.MID` | ✅ |

#### Available Actions

| Action | Status | Description |
|--------|--------|-------------|
| `create` | ✅ | Create store |
| `read` | ✅ | List/query stores |
| `update` | ✅ | Modify store |
| `destroy` | ✅ | Soft-delete store |

### Portal / UI

**Route Prefix**: `/app/stores/:store_slug`
**Layout**: `store_portal_layout`

| Route | LiveView | Status | Description |
|-------|----------|--------|-------------|
| `/app/stores/:slug/sign-in` | `AuthLive.Login` | ✅ | Authentication |
| `/app/stores/:slug/` | `LandingLive` | ✅ | Landing page |
| `/app/stores/:slug/dashboard` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |
| `/app/stores/:slug/terminal` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |
| `/app/stores/:slug/invoices` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |
| `/app/stores/:slug/subscriptions` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |

### API

| Endpoint | Method | Status | Description |
|----------|--------|--------|-------------|
| JSON:API `/store` | GET | ✅ | List stores |
| JSON:API `/store/:id` | GET | ✅ | Get store |
| JSON:API `/store` | POST | ✅ | Create store |
| JSON:API `/store/:id` | PATCH | ✅ | Update store |
| JSON:API `/store/:id` | DELETE | ✅ | Archive store |

### Tests

| Test File | Coverage |
|-----------|----------|
| `test/mcp/platform/shared_entities_test.exs` | Partial |

---

## Gaps

### Critical Gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| ⚠️ **Dashboard** | No functional store dashboard | Critical |
| ⚠️ **Virtual Terminal** | Cannot process card-present transactions | Critical |
| ⚠️ **Invoicing** | Cannot create/send invoices | Critical |
| ⚠️ **Subscriptions** | Cannot manage recurring billing | High |

### Missing Features

| Feature | Description | Priority |
|---------|-------------|----------|
| Virtual Terminal | Manual card entry for staff | Critical |
| Invoice Management | Create, send, track invoices | Critical |
| Cash Register | POS-style interface | High |
| Receipt Printing | Generate/print receipts | High |
| Shift Management | Open/close register | High |
| Subscription Management | Recurring billing UI | High |
| Customer Lookup | Quick customer search | Medium |
| Product Quick-Add | Rapid checkout | Medium |
| Daily Closeout | End-of-day reconciliation | Medium |
| Staff Permissions | Store-level user roles | Medium |
| Inventory Tracking | Stock levels per store | Low |
| Appointment Booking | Service scheduling | Low |

---

## Recommendations

### Short-Term (0-30 days)

1. **Implement Store Dashboard**
   - Today's sales summary
   - Recent transactions
   - Staff on duty (future)
   - Quick actions

2. **Virtual Terminal (Basic)**
   - Manual card entry form
   - Amount input
   - Process authorization
   - Print/email receipt

3. **Basic Invoicing**
   - Create invoice
   - Add line items
   - Send via email
   - Mark as paid

### Medium-Term (30-90 days)

1. **Enhanced Virtual Terminal**
   - Customer lookup
   - Product catalog integration
   - Tax calculation
   - Tip adjustment
   - Split payments

2. **Subscription Management**
   - Create subscription
   - View active subscriptions
   - Cancel/pause
   - Payment retry

3. **Shift Management**
   - Open register
   - Track cash drawer
   - Close register
   - Daily report

### Long-Term (90+ days)

1. **Full POS System**
   - Barcode scanning
   - Hardware integration (card readers)
   - Offline mode
   - Mobile POS app

2. **Multi-Store Operations**
   - Cross-store inventory
   - Consolidated reporting
   - Transfer between stores

3. **Customer Experience**
   - Customer-facing display
   - Digital receipts
   - Loyalty integration

---

## Opportunities

### Revenue Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Per-Store Pricing** | Charge per active store | Low |
| **Terminal Hardware** | Sell/lease card readers | Medium |
| **Premium POS Features** | Advanced POS add-on | Medium |
| **Store Analytics** | Per-store reporting premium | Low |

### Product Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Mobile Store App** | Staff app for floor sales | High |
| **Self-Checkout Kiosk** | Customer self-service | High |
| **Curbside Pickup** | BOPIS integration | Medium |
| **Table Management** | Restaurant seating | Medium |

### Technical Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Offline Sync** | Work without internet | High |
| **Hardware SDK** | Terminal integrations | High |
| **Real-Time Inventory** | Live stock levels | Medium |
| **Store Analytics** | Location performance | Medium |

---

## Store Types

| Type | Use Case | Features Needed |
|------|----------|-----------------|
| `physical` | Brick-and-mortar retail | Virtual terminal, cash drawer, receipts |
| `online` | E-commerce | Checkout widget, subscriptions |
| `hybrid` | Omnichannel | Both physical + online features |
| `popup` | Temporary locations | Mobile POS, quick setup |

---

## Related Entities

- **Merchant** - Parent business
- **MID** - Primary payment gateway account
- **Customer** - Via CustomerStore join
- **Vendor** - Via VendorStore join

---

*Source: `lib/mcp/platform/store.ex`, `lib/mcp_web/router.ex`*
