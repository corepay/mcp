# Customer Entity

> **Last Updated**: 2026-01-10 | **Code Verified**: Yes

## Overview

A **Customer** represents an end consumer who purchases from a merchant. Customers are the ultimate buyers in the payment chain - they have accounts, saved payment methods, and purchase history.

### Business Context

Customers are the **end users** that merchants serve. They may be:
- Individual consumers (B2C)
- Business accounts (B2B)
- Subscription members
- Marketplace buyers

### Key Characteristics

| Aspect | Implementation |
|--------|----------------|
| Scope | Merchant-scoped (composite key) |
| Identity | Email-based identification |
| Access | Self-service portal |
| Data | Owns profile, payment methods, orders |

---

## Current State

### Data Model

**Resource**: `Mcp.Platform.Customer`
**Table**: `customers` (tenant schema)
**Multitenancy**: ✅ Context strategy
**Primary Key**: Composite (`merchant_id` + `id`)
**Archival**: ✅ Soft-delete enabled

#### Core Attributes

| Attribute | Type | Status | Description |
|-----------|------|--------|-------------|
| `id` | UUID | ✅ | Customer ID |
| `merchant_id` | UUID | ✅ | Owning merchant (PK) |
| `email` | CI_String | ✅ | Customer email (case-insensitive) |
| `first_name` | String | ✅ | First name |
| `last_name` | String | ✅ | Last name |
| `phone` | String | ✅ | Phone number |
| `shipping_address` | Map | ✅ | Default shipping address |
| `billing_address` | Map | ✅ | Default billing address |
| `saved_payment_methods` | Array[Map] | ✅ | Tokenized payment methods |
| `total_orders` | Integer | ✅ | Lifetime order count |
| `total_spent` | Decimal | ✅ | Lifetime spend |
| `status` | Atom | ✅ | `active`, `suspended` |
| `marketing_preferences` | Map | ✅ | Email/SMS opt-ins |
| `loyalty_tier` | String | ✅ | Loyalty program tier |
| `loyalty_points` | Integer | ✅ | Current point balance |
| `tags` | Array[String] | ✅ | Custom tags |
| `last_active_at` | DateTime | ✅ | Last activity timestamp |
| `source` | String | ✅ | Acquisition source |
| `gdpr_consent` | Boolean | ✅ | Marketing consent |
| `gdpr_consent_at` | DateTime | ✅ | Consent timestamp |
| `inserted_at` | DateTime | ✅ | Created timestamp |
| `updated_at` | DateTime | ✅ | Modified timestamp |

#### Relationships

| Relationship | Type | Target | Status |
|--------------|------|--------|--------|
| `merchant` | belongs_to | `Platform.Merchant` | ✅ |
| `user` | belongs_to | `Accounts.User` | ✅ |
| `stores` | many_to_many | `Platform.Store` | ✅ (via CustomerStore) |

#### Available Actions

| Action | Status | Description |
|--------|--------|-------------|
| `create` | ✅ | Create customer |
| `read` | ✅ | List/query customers |
| `update` | ✅ | Modify customer |
| `destroy` | ✅ | Soft-delete customer |

### Portal / UI

**Route Prefix**: `/store/account`
**Layout**: `customer_portal_layout`

| Route | LiveView | Status | Description |
|-------|----------|--------|-------------|
| `/store/account/sign-in` | `AuthLive.Login` | ✅ | Authentication |
| `/store/account/` | `LandingLive` | ✅ | Landing page |
| `/store/account/dashboard` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |
| `/store/account/orders` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |
| `/store/account/profile` | `MockDashboardLive` | 🚫 | **PLACEHOLDER** |

### API

| Endpoint | Method | Status | Description |
|----------|--------|--------|-------------|
| JSON:API `/customer` | GET | ✅ | List customers |
| JSON:API `/customer/:id` | GET | ✅ | Get customer |
| JSON:API `/customer` | POST | ✅ | Create customer |
| JSON:API `/customer/:id` | PATCH | ✅ | Update customer |
| JSON:API `/customer/:id` | DELETE | ✅ | Archive customer |

### Tests

| Test File | Coverage |
|-----------|----------|
| `test/mcp/platform/shared_entities_test.exs` | Partial |

---

## Gaps

### Critical Gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| ⚠️ **Account Dashboard** | Customers cannot view their account | High |
| ⚠️ **Order History** | Cannot view past purchases | High |
| ⚠️ **Profile Management** | Cannot update their info | High |
| ⚠️ **Payment Method Management** | Cannot add/remove cards | High |

### Missing Features

| Feature | Description | Priority |
|---------|-------------|----------|
| Account Dashboard | Overview of account status | High |
| Order History | List past orders with details | High |
| Profile Editor | Update name, address, phone | High |
| Payment Methods | Add/remove saved cards | High |
| Subscription Management | View/cancel subscriptions | High |
| Invoice Access | Download invoices/receipts | Medium |
| Communication Preferences | Email/SMS opt-in/out | Medium |
| Address Book | Multiple saved addresses | Medium |
| Wishlist | Save items for later | Low |
| Order Tracking | Real-time delivery status | Low |
| Returns/Refunds | Self-service returns | Low |

---

## Recommendations

### Short-Term (0-30 days)

1. **Implement Account Dashboard**
   - Account summary
   - Recent orders preview
   - Quick links
   - Support contact

2. **Order History View**
   - List all orders
   - Order details
   - Download receipts
   - Status display

3. **Basic Profile Management**
   - Edit name, email, phone
   - Update password
   - Manage addresses

### Medium-Term (30-90 days)

1. **Payment Method Management**
   - List saved cards
   - Add new card
   - Remove card
   - Set default

2. **Subscription Self-Service**
   - View active subscriptions
   - Update payment method
   - Cancel/pause subscription
   - Change plan

3. **Communication Preferences**
   - Email opt-in/out
   - SMS opt-in/out
   - Notification settings
   - GDPR consent management

### Long-Term (90+ days)

1. **Enhanced Experience**
   - Order tracking
   - Wishlist
   - Product reviews
   - Loyalty dashboard

2. **Self-Service Support**
   - Initiate returns
   - Request refunds
   - Chat support
   - FAQ/help center

3. **Mobile App**
   - Native account app
   - Push notifications
   - Mobile wallet

---

## Opportunities

### Revenue Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Loyalty Program** | Points/rewards system | Medium |
| **Premium Membership** | Paid membership tiers | Medium |
| **Gift Cards** | Customer gift card balance | Medium |
| **Referral Program** | Customer-to-customer referrals | Low |

### Product Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Mobile Account App** | iOS/Android customer app | High |
| **One-Click Checkout** | Saved payment express checkout | Medium |
| **Subscription Box** | Curated recurring products | Medium |
| **Customer Reviews** | Product rating/review system | Low |

### Technical Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **SSO Integration** | Social login options | Medium |
| **Biometric Auth** | Face/fingerprint login | Medium |
| **Cross-Merchant Identity** | Unified customer identity | High |
| **Customer Data Platform** | Unified profile across channels | High |

---

## Authentication Model

Per the domain brief:
- Authentication: Email + `merchant_id`
- This allows customers to be customers of multiple merchants
- No cross-merchant visibility (data isolation)

```
Customer (merchant_a) ≠ Customer (merchant_b)
Even if same email address
```

---

## Related Entities

- **Merchant** - Parent business
- **User** - Optional linked login account
- **Store** - Via CustomerStore join (multi-store membership)
- **Payments.Customer** - Payment profile (separate resource)

---

*Source: `lib/mcp/platform/customer.ex`, `lib/mcp_web/router.ex`*
