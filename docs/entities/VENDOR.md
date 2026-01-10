# Vendor Entity

> **Last Updated**: 2026-01-10 | **Code Verified**: Yes

## Overview

A **Vendor** represents a supplier or service provider that a merchant works with. Vendors supply products, inventory, or services to merchants and may have their own portal access.

### Business Context

Vendors are the **supply side** of merchant operations. They may be:
- Product wholesalers/distributors
- Dropship suppliers
- Service contractors (maintenance, cleaning)
- Raw material suppliers
- Professional service providers

### Key Characteristics

| Aspect | Implementation |
|--------|----------------|
| Scope | Merchant-scoped (composite key) |
| Purpose | Supply chain management |
| Access | Self-service vendor portal |
| Relationship | Can serve multiple stores |

---

## Current State

### Data Model

**Resource**: `Mcp.Platform.Vendor`
**Table**: `vendors` (tenant schema)
**Multitenancy**: ✅ Context strategy
**Primary Key**: Composite (`merchant_id` + `id`)
**Archival**: ✅ Soft-delete enabled

#### Core Attributes

| Attribute | Type | Status | Description |
|-----------|------|--------|-------------|
| `id` | UUID | ✅ | Vendor ID |
| `merchant_id` | UUID | ✅ | Owning merchant (PK) |
| `name` | String | ✅ | Vendor/company name |
| `service_type` | String | ✅ | Type of goods/services |
| `contact_name` | String | ✅ | Primary contact |
| `contact_email` | String | ✅ | Contact email |
| `contact_phone` | String | ✅ | Contact phone |
| `address` | Map | ✅ | Business address |
| `status` | Atom | ✅ | `active`, `inactive` |
| `tax_form_status` | Atom | ✅ | `w9_received`, `w9_pending`, `not_required` |
| `payment_terms` | Atom | ✅ | `net15`, `net30`, `net60`, `due_on_receipt` |
| `service_category` | String | ✅ | Category classification |
| `performance_rating` | Integer | ✅ | 1-5 rating |
| `active_contracts` | Map | ✅ | Current agreements |
| `inserted_at` | DateTime | ✅ | Created timestamp |
| `updated_at` | DateTime | ✅ | Modified timestamp |

#### Relationships

| Relationship | Type | Target | Status |
|--------------|------|--------|--------|
| `merchant` | belongs_to | `Platform.Merchant` | ✅ |
| `user` | belongs_to | `Accounts.User` | ✅ |
| `stores` | many_to_many | `Platform.Store` | ✅ (via VendorStore) |

#### Available Actions

| Action | Status | Description |
|--------|--------|-------------|
| `create` | ✅ | Create vendor |
| `read` | ✅ | List/query vendors |
| `update` | ✅ | Modify vendor |
| `destroy` | ✅ | Soft-delete vendor |

### Portal / UI

**Route Prefix**: `/vendors`
**Layout**: `vendor_portal_layout`

| Route | LiveView | Status | Description |
|-------|----------|--------|-------------|
| `/vendors/sign-in` | `AuthLive.Login` | ✅ | Authentication |
| `/vendors/` | `LandingLive` | ✅ | Landing page |
| `/vendors/dashboard` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |
| `/vendors/products` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |
| `/vendors/orders` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |

### API

| Endpoint | Method | Status | Description |
|----------|--------|--------|-------------|
| JSON:API `/vendor` | GET | ✅ | List vendors |
| JSON:API `/vendor/:id` | GET | ✅ | Get vendor |
| JSON:API `/vendor` | POST | ✅ | Create vendor |
| JSON:API `/vendor/:id` | PATCH | ✅ | Update vendor |
| JSON:API `/vendor/:id` | DELETE | ✅ | Archive vendor |

### Tests

| Test File | Coverage |
|-----------|----------|
| `test/mcp/platform/shared_entities_test.exs` | Partial |

---

## Gaps

### Critical Gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| ⚠️ **Dashboard** | Vendors cannot access portal | Medium |
| ⚠️ **Product Catalog** | Cannot list products | Medium |
| ⚠️ **Order Visibility** | Cannot see purchase orders | Medium |
| ⚠️ **Invoice Submission** | Cannot submit invoices | Medium |

### Missing Features

| Feature | Description | Priority |
|---------|-------------|----------|
| Vendor Dashboard | Overview of relationship status | Medium |
| Product Catalog Upload | Submit product listings | Medium |
| Purchase Order View | See orders from merchant | Medium |
| Invoice Submission | Submit invoices for payment | Medium |
| Contract Management | View/sign agreements | Medium |
| Performance Metrics | See own ratings/feedback | Low |
| Inventory Updates | Report stock levels | Low |
| Shipping Integration | Provide tracking info | Low |
| W-9 Upload | Tax form submission | Low |
| Payment History | View past payments | Low |

---

## Recommendations

### Short-Term (0-30 days)

1. **Basic Vendor Dashboard**
   - Relationship status
   - Recent orders summary
   - Pending actions
   - Contact info

2. **Purchase Order View**
   - List orders from merchant
   - Order details
   - Mark as fulfilled
   - Add tracking

3. **Basic Invoicing**
   - Submit invoice
   - Track invoice status
   - View payment history

### Medium-Term (30-90 days)

1. **Product Catalog Management**
   - Upload product list (CSV/API)
   - Pricing updates
   - Inventory levels
   - Product images

2. **Contract/Agreement Portal**
   - View contracts
   - Electronic signature
   - Terms acceptance
   - Renewal tracking

3. **Communication Center**
   - Messages from merchant
   - Order inquiries
   - Issue reporting

### Long-Term (90+ days)

1. **Advanced Catalog Integration**
   - Real-time inventory sync
   - Automated reordering
   - EDI integration
   - Dropship automation

2. **Performance Dashboard**
   - Fulfillment metrics
   - Quality ratings
   - Comparison to benchmarks
   - Improvement recommendations

3. **B2B Marketplace**
   - Public product listings
   - Multi-merchant sales
   - Bulk pricing

---

## Opportunities

### Revenue Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Vendor Portal Fee** | Monthly portal access fee | Low |
| **Catalog Listing Fee** | Per-product listing fee | Low |
| **Transaction Fees** | % of purchase order value | Medium |
| **Featured Placement** | Premium catalog positioning | Low |

### Product Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Vendor Marketplace** | B2B supplier marketplace | High |
| **Dropship Integration** | Automated fulfillment | High |
| **Quality Scoring** | Automated vendor ratings | Medium |
| **Procurement Automation** | AI-based reordering | High |

### Technical Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **EDI Integration** | Standard B2B messaging | High |
| **API Catalog Sync** | Real-time inventory API | Medium |
| **Barcode/SKU Mapping** | Cross-reference products | Medium |
| **Shipment Tracking** | Carrier API integration | Medium |

---

## Use Cases by Service Category

| Category | Typical Features Needed |
|----------|------------------------|
| **Product Suppliers** | Catalog, inventory, dropship |
| **Service Contractors** | Scheduling, work orders, invoicing |
| **Raw Materials** | Bulk ordering, quality certs |
| **Professional Services** | Time tracking, project management |
| **Maintenance/Repair** | Work orders, scheduling, parts |

---

## Related Entities

- **Merchant** - Parent business
- **User** - Optional linked login account
- **Store** - Via VendorStore join (multi-store service)

---

*Source: `lib/mcp/platform/vendor.ex`, `lib/mcp_web/router.ex`*
