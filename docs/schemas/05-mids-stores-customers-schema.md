# MIDs, Stores, Customers Schemas (Quick Reference)

## MIDs (Merchant IDs) Schema

**Entity:** `acq_{tenant}.mids`
**Ash Resource:** `Mcp.MIDs.MID`

```sql
CREATE TABLE mids (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  
  -- MID Identity
  mid_number TEXT NOT NULL,  -- Payment gateway assigned MID
  gateway_id UUID NOT NULL,  -- References platform.payment_gateways(id)
  
  -- Configuration
  gateway_credentials JSONB NOT NULL,  -- Encrypted: {api_key, secret, merchant_account_id}
  routing_rules JSONB DEFAULT '{}',  -- AI-assisted routing configuration
  
  -- Status
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'testing')),
  is_primary BOOLEAN DEFAULT false,
  
  -- Limits
  daily_limit NUMERIC,
  monthly_limit NUMERIC,
  
  -- Analytics
  total_volume NUMERIC DEFAULT 0,
  total_transactions INTEGER DEFAULT 0,
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  UNIQUE(merchant_id, gateway_id, mid_number)
);
```

**Key Business Rules:**
- One merchant can have multiple MIDs
- One MID per gateway per merchant
- Primary MID used for default routing
- Credentials encrypted using Cloak/Vault

---

## Stores Schema

**Entity:** `acq_{tenant}.stores`
**Ash Resource:** `Mcp.Stores.Store`

```sql
CREATE TABLE stores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  
  -- Identity
  slug TEXT NOT NULL,  -- URL-safe: "store-a"
  name TEXT NOT NULL,
  
  -- Routing
  routing_type TEXT DEFAULT 'path' CHECK (routing_type IN ('path', 'subdomain')),
  subdomain TEXT,  -- Only if routing_type = 'subdomain'
  custom_domain TEXT,  -- Optional: store-a.bobs-burgers.com
  
  -- Configuration
  settings JSONB DEFAULT '{}',
  branding JSONB DEFAULT '{}',
  
  -- Payment
  primary_mid_id UUID REFERENCES mids(id),
  fallback_mid_ids UUID[],  -- Array of MID IDs for routing
  
  -- Status
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'draft')),
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  UNIQUE(merchant_id, slug)
);
```

**Key Business Rules:**
- Default routing: `merchant.base.do/store/store-a` (FREE)
- Custom subdomain: `store-a.merchant.base.do` ($5/month)
- Each store assigned to one or more MIDs
- Stores can have separate branding from merchant

---

## Customers Schema

**Entity:** `acq_{tenant}.customers`
**Ash Resource:** `Mcp.Customers.Customer`

```sql
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  
  -- Identity
  email CITEXT NOT NULL,  -- Scoped to merchant (alice@example.com can be customer of multiple merchants)
  first_name TEXT,
  last_name TEXT,
  
  -- Authentication (ash_authentication)
  hashed_password TEXT,
  
  -- Contact
  phone TEXT,
  
  -- Address (optional)
  shipping_address JSONB,
  billing_address JSONB,
  
  -- Store associations (many-to-many via customers_stores junction)
  -- Customer can belong to multiple stores
  
  -- Payment methods
  saved_payment_methods JSONB DEFAULT '[]',  -- Array of tokenized payment methods
  
  -- Lifetime value
  total_orders INTEGER DEFAULT 0,
  total_spent NUMERIC DEFAULT 0,
  
  -- Status
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')),
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  UNIQUE(merchant_id, email)  -- Email unique per merchant
);

-- Customer-Store junction table
CREATE TABLE customers_stores (
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  joined_at TIMESTAMP NOT NULL DEFAULT NOW(),
  PRIMARY KEY (customer_id, store_id)
);
```

**Key Business Rules:**
- Email scoped to merchant (alice@example.com in Merchant A ≠ alice@example.com in Merchant B)
- Customers can self-register (ONLY entity with self-registration)
- Login at `customer.{merchant}.base.do/signin`
- URL determines merchant context (no selection needed)
- Customer can belong to multiple stores within same merchant

---

## ✅ Finalized Decisions

### AI-Based MID Routing
**Decision:** ✅ Placeholder only (defer to post-MVP)
**Rationale:** Build database schema to support AI routing (routing_rules JSONB column), but no ML implementation yet. Focus on core features first. AI routing can be added in Phase 2 without schema changes.

**Implementation:**
- `routing_rules` JSONB field allows future AI configuration
- MVP uses simple primary/fallback MID routing
- Phase 2 can add ML-based intelligent routing without breaking changes

### Store Custom Subdomain Pricing
**Decision:** ✅ Free with Professional plan, $10/month on Starter (per subdomain)
**Rationale:** Aligns with tenant-level custom domain pricing. Covers infrastructure costs for DNS, SSL, and routing. Incentivizes plan upgrades.

**Pricing Breakdown:**
- **Path-based stores:** FREE on all plans (unlimited: `merchant.base.do/store1`, `merchant.base.do/store2`)
- **Custom subdomains (Starter plan):** $10/month per subdomain (`store1.merchant.base.do`)
- **Custom subdomains (Professional plan):** Included (5 subdomains free with plan)
- **Custom subdomains (Enterprise plan):** Unlimited (included with plan)

### Customer Email Uniqueness Scope
**Decision:** ✅ Merchant-scoped (alice@example.com can be a customer of multiple merchants)
**Rationale:** Same person can shop at multiple stores without account conflicts. Customer records are isolated per merchant within a tenant. Email is unique within `(merchant_id, email)` constraint, NOT globally.

**Implementation:**
```sql
UNIQUE(merchant_id, email)  -- alice@example.com in Merchant A ≠ alice@example.com in Merchant B
```

**Use Case:** Alice shops at both Bob's Burgers and Tina's Tacos (both merchants in same tenant). She uses alice@example.com at both stores. Two separate customer records are created, each with their own order history and preferences.
