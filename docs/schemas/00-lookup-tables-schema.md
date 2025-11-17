# Lookup Tables Schema (Enum Replacement)

**Purpose:** Replace PostgreSQL ENUMs with flexible lookup tables
**Why:** Adding/removing enum values requires schema migrations and table locks. Lookup tables allow runtime changes.

---

## Core Lookup Tables

### Entity Types

```sql
CREATE TABLE platform.entity_types (
  value TEXT PRIMARY KEY,  -- 'user', 'merchant', 'product', etc.
  label TEXT NOT NULL,     -- 'User', 'Merchant', 'Product'
  description TEXT,
  category TEXT,           -- 'core', 'commerce', 'payments', 'shipping'
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  metadata JSONB DEFAULT '{}',  -- {icon: 'user-icon', color: '#3b82f6'}
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Seed data
INSERT INTO platform.entity_types (value, label, description, category, sort_order) VALUES
  -- Core entities
  ('user', 'User', 'Global platform user', 'core', 1),
  ('user_profile', 'User Profile', 'Entity-scoped user profile', 'core', 2),
  ('tenant', 'Tenant', 'Top-level tenant entity', 'core', 3),
  ('developer', 'Developer', 'External API developer', 'core', 4),
  ('reseller', 'Reseller', 'Partner reseller', 'core', 5),
  ('merchant', 'Merchant', 'Merchant account', 'core', 6),
  ('store', 'Store', 'Store entity', 'core', 7),
  ('customer', 'Customer', 'End customer', 'core', 8),
  ('vendor', 'Vendor', 'Vendor/supplier', 'core', 9),

  -- Commerce entities
  ('product', 'Product', 'Product entity', 'commerce', 10),
  ('product_variant', 'Product Variant', 'Product SKU variant', 'commerce', 11),
  ('category', 'Category', 'Product category', 'commerce', 12),
  ('collection', 'Collection', 'Product collection', 'commerce', 13),
  ('order', 'Order', 'Customer order', 'commerce', 14),
  ('order_item', 'Order Item', 'Line item in order', 'commerce', 15),
  ('cart', 'Shopping Cart', 'Customer cart', 'commerce', 16),
  ('cart_item', 'Cart Item', 'Item in cart', 'commerce', 17),

  -- Payment entities
  ('transaction', 'Transaction', 'Payment transaction', 'payments', 20),
  ('payment_method', 'Payment Method', 'Saved payment method', 'payments', 21),
  ('refund', 'Refund', 'Payment refund', 'payments', 22),
  ('chargeback', 'Chargeback', 'Payment chargeback', 'payments', 23),
  ('payout', 'Payout', 'Merchant payout', 'payments', 24),
  ('mid', 'MID', 'Merchant ID account', 'payments', 25),

  -- Shipping entities
  ('shipment', 'Shipment', 'Order shipment', 'shipping', 30),
  ('shipment_item', 'Shipment Item', 'Item in shipment', 'shipping', 31),
  ('tracking_event', 'Tracking Event', 'Shipment tracking update', 'shipping', 32),

  -- Content entities
  ('page', 'Page', 'CMS page', 'content', 40),
  ('blog_post', 'Blog Post', 'Blog article', 'content', 41),
  ('media', 'Media', 'Media asset', 'content', 42),

  -- Marketing entities
  ('campaign', 'Campaign', 'Marketing campaign', 'marketing', 50),
  ('discount', 'Discount', 'Discount rule', 'marketing', 51),
  ('coupon', 'Coupon', 'Coupon code', 'marketing', 52),
  ('loyalty_program', 'Loyalty Program', 'Customer loyalty program', 'marketing', 53),

  -- Support entities
  ('ticket', 'Support Ticket', 'Customer support ticket', 'support', 60),
  ('message', 'Message', 'Support message', 'support', 61),
  ('kb_article', 'Knowledge Base Article', 'Help article', 'support', 62);

CREATE INDEX idx_entity_types_category ON platform.entity_types(category);
CREATE INDEX idx_entity_types_is_active ON platform.entity_types(is_active) WHERE is_active = true;
```

---

### Address Types

```sql
CREATE TABLE platform.address_types (
  value TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO platform.address_types (value, label, description, sort_order) VALUES
  ('home', 'Home Address', 'Personal home address', 1),
  ('business', 'Business Address', 'Business/office address', 2),
  ('shipping', 'Shipping Address', 'Shipping/delivery address', 3),
  ('billing', 'Billing Address', 'Billing address for invoices', 4),
  ('legal', 'Legal Address', 'Legal/registered address', 5),
  ('warehouse', 'Warehouse', 'Warehouse/fulfillment center', 6),
  ('pickup', 'Pickup Location', 'Customer pickup location', 7);
```

---

### Email Types

```sql
CREATE TABLE platform.email_types (
  value TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO platform.email_types (value, label, sort_order) VALUES
  ('personal', 'Personal', 1),
  ('work', 'Work', 2),
  ('support', 'Support', 3),
  ('billing', 'Billing', 4),
  ('noreply', 'No Reply', 5),
  ('sales', 'Sales', 6),
  ('marketing', 'Marketing', 7);
```

---

### Phone Types

```sql
CREATE TABLE platform.phone_types (
  value TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  supports_sms BOOLEAN DEFAULT false,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO platform.phone_types (value, label, supports_sms, sort_order) VALUES
  ('mobile', 'Mobile', true, 1),
  ('home', 'Home', false, 2),
  ('work', 'Work', false, 3),
  ('fax', 'Fax', false, 4),
  ('support', 'Support', true, 5),
  ('toll_free', 'Toll Free', false, 6);
```

---

### Social Platforms

```sql
CREATE TABLE platform.social_platforms (
  value TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  icon TEXT,  -- Icon name or URL
  url_pattern TEXT,  -- 'https://twitter.com/{username}'
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO platform.social_platforms (value, label, icon, url_pattern, sort_order) VALUES
  ('twitter', 'Twitter/X', 'twitter', 'https://twitter.com/{username}', 1),
  ('facebook', 'Facebook', 'facebook', 'https://facebook.com/{username}', 2),
  ('instagram', 'Instagram', 'instagram', 'https://instagram.com/{username}', 3),
  ('linkedin', 'LinkedIn', 'linkedin', 'https://linkedin.com/in/{username}', 4),
  ('tiktok', 'TikTok', 'tiktok', 'https://tiktok.com/@{username}', 5),
  ('youtube', 'YouTube', 'youtube', 'https://youtube.com/@{username}', 6),
  ('github', 'GitHub', 'github', 'https://github.com/{username}', 7),
  ('pinterest', 'Pinterest', 'pinterest', 'https://pinterest.com/{username}', 8),
  ('snapchat', 'Snapchat', 'snapchat', 'https://snapchat.com/add/{username}', 9);
```

---

### Image Types

```sql
CREATE TABLE platform.image_types (
  value TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  max_file_size INTEGER,  -- Bytes
  allowed_mime_types TEXT[],
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO platform.image_types (value, label, max_file_size, allowed_mime_types, sort_order) VALUES
  ('avatar', 'Avatar', 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'], 1),  -- 5MB
  ('logo', 'Logo', 2097152, ARRAY['image/png', 'image/svg+xml'], 2),  -- 2MB
  ('banner', 'Banner', 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp'], 3),  -- 10MB
  ('product', 'Product Image', 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'], 4),
  ('gallery', 'Gallery Image', 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp'], 5),
  ('document_scan', 'Document Scan', 20971520, ARRAY['image/jpeg', 'image/png', 'application/pdf'], 6),  -- 20MB
  ('thumbnail', 'Thumbnail', 1048576, ARRAY['image/jpeg', 'image/png', 'image/webp'], 7);  -- 1MB
```

---

### Document Types

```sql
CREATE TABLE platform.document_types (
  value TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT,
  is_sensitive BOOLEAN DEFAULT true,
  requires_encryption BOOLEAN DEFAULT true,
  retention_years INTEGER,  -- NULL = indefinite
  allowed_mime_types TEXT[],
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO platform.document_types (value, label, description, is_sensitive, requires_encryption, retention_years, allowed_mime_types, sort_order) VALUES
  ('kyc_id', 'KYC ID Document', 'Government-issued ID', true, true, 7, ARRAY['image/jpeg', 'image/png', 'application/pdf'], 1),
  ('kyc_address_proof', 'KYC Address Proof', 'Proof of address', true, true, 7, ARRAY['image/jpeg', 'image/png', 'application/pdf'], 2),
  ('contract', 'Contract', 'Legal contract', true, true, 10, ARRAY['application/pdf'], 3),
  ('invoice', 'Invoice', 'Invoice document', false, false, 7, ARRAY['application/pdf'], 4),
  ('receipt', 'Receipt', 'Payment receipt', false, false, 7, ARRAY['application/pdf'], 5),
  ('tax_form', 'Tax Form', 'Tax document', true, true, 7, ARRAY['application/pdf'], 6),
  ('legal', 'Legal Document', 'Legal filing', true, true, NULL, ARRAY['application/pdf'], 7),
  ('bank_statement', 'Bank Statement', 'Bank account statement', true, true, 7, ARRAY['application/pdf'], 8),
  ('business_license', 'Business License', 'Business registration', true, true, 10, ARRAY['image/jpeg', 'image/png', 'application/pdf'], 9);
```

---

### Status Types (Universal)

```sql
CREATE TABLE platform.status_types (
  value TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  category TEXT,  -- 'entity', 'transaction', 'order', etc.
  color TEXT,  -- Hex color for UI: '#22c55e'
  is_final BOOLEAN DEFAULT false,  -- Terminal state (can't transition out)
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO platform.status_types (value, label, category, color, is_final, sort_order) VALUES
  -- Entity statuses
  ('active', 'Active', 'entity', '#22c55e', false, 1),
  ('suspended', 'Suspended', 'entity', '#f59e0b', false, 2),
  ('pending', 'Pending', 'entity', '#3b82f6', false, 3),
  ('trial', 'Trial', 'entity', '#8b5cf6', false, 4),
  ('canceled', 'Canceled', 'entity', '#ef4444', true, 5),
  ('closed', 'Closed', 'entity', '#6b7280', true, 6),

  -- Transaction statuses
  ('pending_payment', 'Pending Payment', 'transaction', '#f59e0b', false, 10),
  ('processing', 'Processing', 'transaction', '#3b82f6', false, 11),
  ('succeeded', 'Succeeded', 'transaction', '#22c55e', true, 12),
  ('failed', 'Failed', 'transaction', '#ef4444', true, 13),
  ('refunded', 'Refunded', 'transaction', '#6b7280', true, 14),
  ('partially_refunded', 'Partially Refunded', 'transaction', '#f59e0b', false, 15),

  -- Order statuses
  ('draft', 'Draft', 'order', '#6b7280', false, 20),
  ('pending_fulfillment', 'Pending Fulfillment', 'order', '#f59e0b', false, 21),
  ('fulfilled', 'Fulfilled', 'order', '#22c55e', false, 22),
  ('shipped', 'Shipped', 'order', '#3b82f6', false, 23),
  ('delivered', 'Delivered', 'order', '#22c55e', true, 24),
  ('returned', 'Returned', 'order', '#ef4444', true, 25);
```

---

### Plan Types

```sql
CREATE TABLE platform.plan_types (
  value TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT,
  features JSONB DEFAULT '{}',
  pricing JSONB DEFAULT '{}',  -- {monthly: 29, annual: 290}
  limits JSONB DEFAULT '{}',   -- {max_users: 5, max_api_calls: 10000}
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO platform.plan_types (value, label, description, pricing, limits, sort_order) VALUES
  ('starter', 'Starter', 'For small businesses getting started', '{"monthly": 0}'::jsonb, '{"max_users": 2, "max_api_calls": 1000}'::jsonb, 1),
  ('professional', 'Professional', 'For growing businesses', '{"monthly": 49, "annual": 490}'::jsonb, '{"max_users": 10, "max_api_calls": 10000}'::jsonb, 2),
  ('enterprise', 'Enterprise', 'For large organizations', '{"monthly": 149, "annual": 1490}'::jsonb, '{"max_users": -1, "max_api_calls": -1}'::jsonb, 3);
```

---

## Updated Polymorphic Tables (Using Lookups)

```sql
-- Addresses with FK to entity_types
CREATE TABLE platform.addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Polymorphic association (NO CHECK constraint!)
  owner_type TEXT NOT NULL REFERENCES platform.entity_types(value),
  owner_id UUID NOT NULL,

  -- Address type (FK to lookup table)
  address_type TEXT REFERENCES platform.address_types(value),

  -- ... rest of fields
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Same pattern for all polymorphic tables
CREATE TABLE platform.emails (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_type TEXT NOT NULL REFERENCES platform.entity_types(value),
  owner_id UUID NOT NULL,
  email_type TEXT REFERENCES platform.email_types(value),
  -- ...
);

CREATE TABLE platform.phones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_type TEXT NOT NULL REFERENCES platform.entity_types(value),
  owner_id UUID NOT NULL,
  phone_type TEXT REFERENCES platform.phone_types(value),
  -- ...
);
```

---

## Benefits

1. ✅ **No schema migrations** - Add new types with INSERT
2. ✅ **No table locks** - Runtime changes
3. ✅ **Metadata storage** - Icons, colors, descriptions
4. ✅ **Soft delete** - Set is_active = false
5. ✅ **Ordering** - sort_order for UI display
6. ✅ **i18n ready** - Can add translations table
7. ✅ **Validation rules** - max_file_size, allowed_mime_types
8. ✅ **Queryable** - Can list all available types dynamically

---

## Ash Resource Pattern

```elixir
defmodule Mcp.Shared.EntityType do
  use Ash.Resource,
    domain: Mcp.Shared,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "entity_types"
    repo Mcp.Repo
    schema "platform"
  end

  attributes do
    attribute :value, :string, primary_key?: true, allow_nil?: false
    attribute :label, :string, allow_nil?: false
    attribute :description, :string
    attribute :category, :string
    attribute :is_active, :boolean, default: true
    attribute :sort_order, :integer, default: 0
    attribute :metadata, :map, default: %{}
    timestamps()
  end

  actions do
    defaults [:read]

    create :add_type do
      accept [:value, :label, :description, :category, :sort_order, :metadata]
    end

    update :deactivate do
      change set_attribute(:is_active, false)
    end
  end

  code_interface do
    define :list_active, action: :read, filter: [is_active: true]
    define :list_by_category, action: :read, args: [:category]
    define :add_type
  end
end
```

---

## Migration Strategy

```elixir
# Migration: Create all lookup tables first
defmodule Mcp.Repo.Migrations.CreateLookupTables do
  use Ecto.Migration

  def up do
    # Create all lookup tables
    execute File.read!("priv/repo/migrations/sql/00_lookup_tables.sql")
  end

  def down do
    execute "DROP TABLE IF EXISTS platform.entity_types CASCADE"
    # ... drop all lookup tables
  end
end
```

---

## ✅ Finalized Decisions

### Entity Types
**Decision:** ✅ Current list sufficient (30+ entity types covering core, commerce, payments, shipping, communication categories)
**Rationale:** Comprehensive coverage of all expected entities. Additional types can be added via INSERT statements without schema migrations.

### Status Colors
**Decision:** ✅ Keep current defaults
**Rationale:** Good defaults based on standard UI conventions (green=success, red=error/failed, orange=warning, blue=info).

### Plan Pricing
**Decision:** ✅ Higher pricing ($0 Starter, $49 Pro/$490 Annual, $149 Enterprise/$1490 Annual)
**Rationale:** Premium positioning reflects the value of payment processing infrastructure and AI features. Competitive with industry standards.

**Pricing Breakdown:**
- **Starter:** $0/month (free tier for small businesses)
- **Professional:** $49/month or $490/year (save ~17%)
- **Enterprise:** $149/month or $1490/year (save ~17%)

**Includes:**
- Starter: 2 users, 1000 API calls, path-based stores only
- Professional: 10 users, 10,000 API calls, 5 custom subdomains, custom domain included
- Enterprise: Unlimited users/API calls/subdomains, white-label, advanced analytics

### Document Retention Policies
**Decision:** ✅ 7 years for financial documents (standard)
**Rationale:** IRS and payment card industry standards require 7-year retention for financial records, contracts, invoices, KYC documents.

**Retention by Document Type:**
- KYC documents: 7 years
- Contracts: 7 years
- Invoices: 7 years
- Receipts: 7 years
- Audit logs: 1 year (configurable per tenant)
- General documents: Per tenant policy (default 7 years)
