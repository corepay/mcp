# Architecture Refinement Decisions - Session 2025-11-17

**Session Date:** 2025-11-17
**Status:** All decisions finalized and approved
**Next Step:** Run `/bmad:bmm:workflows:architecture` to generate final architecture document

---

## CRITICAL ARCHITECTURAL REFINEMENTS

### 1. Multi-Entity User Profiles ✅

**Problem:** Original design used global user profiles (one name/avatar for all entities)

**Solution:** Entity-scoped user profiles

**Decision:**
- `platform.users` = Authentication ONLY (email, password, 2FA)
- `platform.user_profiles` = Entity-specific identity (separate name, avatar, contact per entity)
- User can have MULTIPLE profiles (one per tenant, merchant, reseller, etc.)
- Each profile has independent: first_name, last_name, nickname, avatar_url, bio, title, contact_email, phone
- `is_admin` flag per profile (admin in Tenant A ≠ admin in Merchant B)
- `is_developer` flag per profile (developer portal access per entity)

**Example:**
```
User: alice@example.com
├─ Profile in Tenant A: "Alice Smith, CTO" (professional)
├─ Profile in Merchant B: "Chef Alice" (brand persona)
└─ Profile in Reseller C: "A. Smith Consulting" (business identity)
```

**JWT Session Structure:**
```json
{
  "user_id": "user_123",
  "email": "alice@example.com",
  "current_profile_id": "profile_456",
  "current_context": {
    "type": "tenant",
    "id": "tenant_a",
    "profile": {
      "first_name": "Alice",
      "last_name": "Smith",
      "is_admin": true,
      "is_developer": true,
      "teams": ["team_dev", "team_admin"]
    }
  },
  "authorized_contexts": [
    {"type": "tenant", "id": "tenant_a", "profile_id": "profile_456", "name": "Alice Smith"},
    {"type": "merchant", "id": "merchant_b", "profile_id": "profile_789", "name": "Chef Alice"}
  ]
}
```

**Context Switching:**
- When user switches from Tenant A → Merchant B:
  - Session ID rotated (security)
  - Current profile changes (profile_456 → profile_789)
  - UI shows new name/avatar ("Chef Alice")
  - Permissions reload for new context

**Database Schema:**
```sql
CREATE TABLE platform.user_profiles (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES platform.users(id),
  entity_type TEXT NOT NULL,  -- 'tenant', 'merchant', 'reseller', etc.
  entity_id UUID NOT NULL,

  -- Entity-specific identity
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  nickname TEXT,
  avatar_url TEXT,
  bio TEXT,
  title TEXT,

  -- Contact (entity-specific)
  phone TEXT,
  contact_email TEXT,
  timezone TEXT DEFAULT 'UTC',

  -- Preferences (entity-specific)
  preferences JSONB DEFAULT '{}',

  -- Role flags
  is_admin BOOLEAN DEFAULT false,
  is_developer BOOLEAN DEFAULT false,

  -- Status
  status TEXT DEFAULT 'active',  -- 'active', 'suspended', 'invited', 'pending'

  UNIQUE(user_id, entity_type, entity_id)
);
```

---

### 2. Store Routing & Custom Domain Pricing ✅

**Decision:** Path-based stores by default, custom subdomains as premium feature

**Default Routing (FREE):**
```
merchant.base.do/store/store-a
merchant.base.do/store/store-b
merchant.base.do/store/store-c
```

**Custom Merchant Domain ($5/month):**
```
portal.bobs-burgers.com                    # Merchant portal
portal.bobs-burgers.com/store/store-a      # Store inherits path
portal.bobs-burgers.com/store/store-b
merchant.base.do/*                         # Original routes still work
```

**Custom Store Subdomain ($5/month per store):**
```
store-a.bobs-burgers.com                   # Dedicated store subdomain
portal.bobs-burgers.com/store/store-a      # Path route STILL works (dual routing)
```

**Pricing Model:**
- **Free:** Unlimited path-based stores
- **$5/month:** Custom merchant domain (includes all path-based stores)
- **$5/month per store:** Custom store subdomain (optional, dual routing preserved)

**Database Schema:**
```sql
CREATE TABLE stores (
  id UUID PRIMARY KEY,
  merchant_id UUID REFERENCES merchants(id),
  slug TEXT NOT NULL,
  name TEXT NOT NULL,

  routing_type TEXT DEFAULT 'path',  -- 'path' or 'subdomain'
  subdomain TEXT,                    -- Only if routing_type = 'subdomain'
  custom_domain TEXT,                -- Optional custom domain

  UNIQUE(merchant_id, slug)
);
```

---

### 3. API Key Creation Requires Admin ✅

**Problem:** Original proposal allowed any developer to create API keys (privilege escalation risk)

**Solution:** Separate developer portal access from API key creation rights

**Permission Model:**

| Action | is_developer | is_admin | Teams Permission |
|--------|--------------|----------|------------------|
| View API docs | ✅ | ✅ | - |
| Use API Playground | ✅ | ✅ | - |
| View masked API keys | ✅ | ✅ | - |
| **Create API keys** | ❌ | **✅** | OR `create_api_keys` |
| **Rotate own assigned keys** | ✅ | ✅ | - |
| **Rotate any key** | ❌ | **✅** | OR `manage_api_keys` |
| **Revoke API keys** | ❌ | **✅** | OR `manage_api_keys` |
| Manage webhooks | ❌ | **✅** | OR `manage_webhooks` |

**Key Points:**
- `is_developer` flag = Developer Portal access ONLY (view docs, playground, assigned keys)
- API key creation requires `is_admin = true` OR `create_api_keys` team permission
- Non-admin developers can REQUEST keys from admin
- Non-admin developers can ROTATE their assigned keys (admin notified)
- Admin can assign keys to team members

**Workflow:**
1. Admin creates API key with scoped permissions
2. Admin optionally assigns key to team member (junior developer)
3. Assigned user receives notification with key (one-time view)
4. Assigned user can rotate key (admin notified)
5. Only admin can revoke or reassign key

**Database Schema:**
```sql
CREATE TABLE api_keys (
  id UUID PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  key_type TEXT NOT NULL,  -- 'developer', 'merchant', 'reseller'
  entity_id UUID NOT NULL,

  created_by UUID REFERENCES platform.user_profiles(id),
  assigned_to UUID REFERENCES platform.user_profiles(id),  -- Optional assignment

  scope JSONB NOT NULL,
  permissions TEXT[] NOT NULL,

  expires_at TIMESTAMP,
  status TEXT DEFAULT 'active'
);
```

---

### 4. Three-Tier API Access Model ✅

**Decision:** Separate API authentication for Developers, Merchants, and Resellers

**1. Developer API Keys (External Integration)**
- **Created by:** Tenant admin (during developer invitation)
- **Scope:** Tenant-defined (can access multiple merchants if permissions allow)
- **Permissions:** Tenant-defined (granular control)
- **Auth Header:** `Bearer dev_ak_...`
- **Base URL:** `https://api.base.do/v1/tenants/{tenant_id}/...`
- **Use Case:** Third-party integrations, custom applications

**2. Merchant API Keys (Self-Service)**
- **Created by:** Merchant admin (self-service, no approval needed)
- **Scope:** Auto-scoped to own merchant entity only
- **Permissions:** Full access to own merchant data OR custom scoped permissions
- **Auth Header:** `Bearer merch_ak_...`
- **Base URL:** `https://api.base.do/v1/merchants/{merchant_id}/...`
- **Use Case:** POS integration, custom dashboards, CRM sync
- **Plan Limits:** 2 keys (Professional), 10 keys (Enterprise)

**3. Reseller API Keys (Self-Service, Limited Scope)**
- **Created by:** Reseller admin (self-service)
- **Scope:** Auto-scoped to own reseller entity + assigned merchants
- **Permissions:** Full reseller data + payment data only for assigned merchants
- **Auth Header:** `Bearer res_ak_...`
- **Base URL:** `https://api.base.do/v1/resellers/{reseller_id}/...`
- **Use Case:** Backoffice integration, merchant portfolio analytics

**Key Architectural Decision:**
- Each API key type has different scope enforcement
- URL structure enforces scoping (merchant_id in URL must match key)
- Middleware validates scope at every request
- RLS policies enforce data access boundaries

---

### 5. Unified Developer Portal ✅

**Decision:** One portal (`developers.base.do`), context-aware for all three user types

**Portal Architecture:**
```
developers.base.do
├─ Context detection plug (detects: developer, merchant, reseller)
├─ Context-aware dashboard
├─ Context-aware API documentation
├─ Shared features:
│   ├─ API Keys (create/view/rotate based on permissions)
│   ├─ API Playground (temporary tokens)
│   ├─ Request Logs (scoped to user's keys)
│   ├─ Webhooks (scoped to entity)
│   ├─ Usage Analytics
│   └─ SDK/Code Snippets
```

**Features:**

| Feature | External Developer | Merchant User | Reseller User |
|---------|-------------------|---------------|---------------|
| API Keys | Tenant-controlled | Self-service scoped | Self-service scoped |
| API Docs | Tenant API | Merchant API | Reseller API |
| Playground | ✅ | ✅ | ✅ |
| Request Logs | ✅ | ✅ | ✅ |
| Webhooks | ✅ Tenant-scoped | ✅ Merchant-scoped | ✅ Reseller-scoped |
| Sandbox | ✅ | ✅ Pro+ | ✅ Pro+ |

**Security:**
- API Playground uses temporary tokens (1 hour expiry)
- Real API keys never exposed in browser
- CORS restricted to Developer Portal domain
- Separate audit trail for playground vs production

---

### 6. Stripe-Based API Versioning ✅

**Decision:** Header-based versioning (NO path-based `/v1/`, `/v2/`)

**Implementation:**
```bash
# Client sends version header
curl https://api.base.do/merchants \
  -H "Authorization: Bearer merch_ak_..." \
  -H "API-Version: 2025-11-17"

# No version header = use account default or latest
curl https://api.base.do/merchants \
  -H "Authorization: Bearer merch_ak_..."
```

**Versioning Strategy:**
1. Client sends `API-Version: YYYY-MM-DD` header
2. If no header: Use account's default version (stored in user_profile.preferences)
3. If no account default: Use latest stable version
4. Server responds with `API-Version: YYYY-MM-DD` header (confirmation)
5. Version-aware serialization in controllers

**Benefits:**
- Clean URLs (no `/v1/`, `/v2/` clutter)
- Pin to stable version (2024-06-01) while testing new version (2025-11-17)
- Account-level default version
- Gradual migration path

**Supported Versions:**
```
2024-01-15 - Initial API release
2024-06-01 - Added multi-MID support
2025-11-17 - Added branding/settings objects (latest)
```

---

### 7. Lookup Tables Architecture (NO ENUMs) ✅

**Problem:** PostgreSQL ENUMs require schema migrations and table locks to modify

**Solution:** Replace ALL ENUMs with lookup tables

**Example:**
```sql
-- BAD (ENUM or CHECK constraint)
owner_type TEXT CHECK (owner_type IN ('user', 'merchant', 'customer'))

-- GOOD (FK to lookup table)
owner_type TEXT REFERENCES platform.entity_types(value)
```

**Lookup Tables Created:**
- `platform.entity_types` - All entity types (30+ types: user, merchant, product, order, etc.)
- `platform.address_types` - Address types (home, business, shipping, billing, etc.)
- `platform.email_types` - Email types (personal, work, support, billing, etc.)
- `platform.phone_types` - Phone types (mobile, home, work, SMS-capable, etc.)
- `platform.social_platforms` - Social platforms (twitter, facebook, instagram, etc.)
- `platform.image_types` - Image types (avatar, logo, product, banner, etc.)
- `platform.document_types` - Document types (kyc_id, contract, invoice, etc.)
- `platform.status_types` - Universal statuses (active, suspended, pending, etc.)
- `platform.plan_types` - Subscription plans (starter, professional, enterprise)

**Benefits:**
- ✅ Add new types: `INSERT INTO entity_types VALUES ('product', ...)`
- ✅ No schema migrations
- ✅ No table locks
- ✅ Soft delete: `UPDATE entity_types SET is_active = false`
- ✅ Metadata storage (icons, colors, descriptions, validation rules)
- ✅ Queryable (list all available types dynamically)
- ✅ i18n ready

**Complete Entity Type Coverage:**

| Category | Entity Types |
|----------|-------------|
| **Core** | user, user_profile, tenant, developer, reseller, merchant, store, customer, vendor |
| **Commerce** | product, product_variant, category, collection, order, order_item, cart, cart_item |
| **Payments** | transaction, payment_method, refund, chargeback, payout, mid |
| **Shipping** | shipment, shipment_item, tracking_event |
| **Content** | page, blog_post, media |
| **Marketing** | campaign, discount, coupon, loyalty_program |
| **Support** | ticket, message, kb_article |

---

### 8. Polymorphic Shared Entities ✅

**Decision:** Store common entities in `platform` schema with polymorphic associations

**Shared Entities:**
- **Addresses** - Home, business, shipping, billing, warehouse
- **Emails** - Personal, work, support, billing
- **Phones** - Mobile, home, work, SMS-capable
- **Socials** - Twitter, Facebook, Instagram, LinkedIn, GitHub
- **Images** - Avatars, logos, product images (S3 metadata)
- **Documents** - KYC docs, contracts, invoices (encrypted S3)
- **Todos** - User tasks, entity-related todos
- **Notes** - Private/shared notes with full-text search

**Schema Pattern:**
```sql
CREATE TABLE platform.addresses (
  id UUID PRIMARY KEY,

  -- Polymorphic association (FK to entity_types, NOT CHECK constraint!)
  owner_type TEXT NOT NULL REFERENCES platform.entity_types(value),
  owner_id UUID NOT NULL,

  -- Type (FK to lookup table)
  address_type TEXT REFERENCES platform.address_types(value),

  -- Address data
  line1 TEXT NOT NULL,
  city TEXT NOT NULL,
  state TEXT,
  postal_code TEXT NOT NULL,
  country TEXT DEFAULT 'US',

  -- PostGIS for geocoding
  location GEOGRAPHY(POINT, 4326),

  is_verified BOOLEAN DEFAULT false,
  is_primary BOOLEAN DEFAULT false
);
```

**Row-Level Security (RLS):**
```sql
CREATE POLICY addresses_select ON platform.addresses
  FOR SELECT
  USING (
    -- User can see own addresses
    (owner_type = 'user' AND owner_id = current_user_id())
    OR
    -- User can see addresses of entities they belong to
    EXISTS (
      SELECT 1 FROM platform.user_profiles up
      WHERE up.user_id = current_user_id()
        AND up.entity_type = addresses.owner_type
        AND up.entity_id = addresses.owner_id
    )
    OR
    -- Merchants can see customer addresses (for shipping)
    (owner_type = 'customer' AND can_access_customer(owner_id))
  );
```

**Benefits:**
- No data duplication (user enters address once, reused across entities)
- Privacy by design (RLS enforces access control)
- GDPR compliance (centralized data for deletion requests)
- Consistent API (same patterns for all shared entities)
- Performance (indexed properly, no cross-schema joins)

---

### 9. Seed Data with Platform Admin ✅

**Decision:** Comprehensive seed data with forced password change for platform admin

**Seed Structure:**
```elixir
# Platform Admin (MUST change password on first login)
User.register!(
  email: "admin@platform.local",
  password: "TempPassword123!",
  password_change_required: true  # NEW FLAG
)

# Sample Tenant: "Acme Payment Solutions"
# Sample Merchant: "Bob's Burgers"
# Sample MID, Store, Customer, Products
```

**Forced Password Change Flow:**
```elixir
def create(conn, %{"email" => email, "password" => password}) do
  case User.sign_in(email, password) do
    {:ok, user} ->
      if user.password_change_required do
        conn
        |> put_session(:user_id, user.id)
        |> put_session(:password_change_required, true)
        |> redirect(to: ~p"/change-password")
      else
        complete_sign_in(conn, user)
      end
  end
end
```

**Enforcement Plug:**
```elixir
# Only allow access to password change page until completed
defmodule McpWeb.Plugs.RequirePasswordChange do
  def call(conn, _opts) do
    if get_session(conn, :password_change_required) do
      unless conn.request_path == "/change-password" do
        conn
        |> redirect(to: ~p"/change-password")
        |> halt()
      end
    end
    conn
  end
end
```

---

### 10. Portal Landing Pages & Architecture ✅

**Landing Pages:**
```
1. Platform Portal (platform.base.do/)
   └─> /dashboard → Platform admin overview (tenants, system health)

2. Discovery Portal (app.base.do/)
   └─> / → Context switcher (list all user's entities)

3. Tenant Portal ({tenant}.base.do/)
   └─> /dashboard → Tenant overview (merchants, resellers, developers)

4. Merchant Portal ({merchant}.base.do/)
   └─> /dashboard → Merchant overview (sales, transactions, products)

5. Customer Portal (customer.{merchant}.base.do/)
   └─> / → Shop/storefront (NOT /dashboard - it's a store!)

6. Developer Portal (developers.base.do/)
   └─> /dashboard → API keys, docs, usage stats

7. Store Portal ({store}.{merchant}.base.do/)
   └─> / → Store-specific shop

8. Vendor Portal (vendor.{merchant}.base.do/)
   └─> /dashboard → Vendor inventory, orders
```

**Shared Component Architecture:**
```
lib/mcp_web/
├── components/
│   ├── core/               # Shared across ALL portals
│   │   ├── layouts/        # root, app, public
│   │   ├── ui/             # DaisyUI components
│   │   └── nav/            # topbar, sidebar, context_switcher
│   ├── portals/            # Portal-specific components
│   │   ├── platform/
│   │   ├── tenant/
│   │   ├── merchant/
│   │   └── customer/
│   └── shared/             # Shared business logic
│       ├── auth/
│       ├── profile/
│       └── payments/
```

---

### 11. Login Redirect Behavior ✅

**Decision:** Protected page > context > primary profile

**Logic:**
```elixir
defp determine_redirect_path(conn, user, params) do
  cond do
    # 1. Protected page in query param (highest priority)
    redirect_url = params["redirect_to"] ->
      validate_and_return_redirect(redirect_url)

    # 2. Current host context (second priority)
    current_context = detect_portal_context(conn) ->
      default_dashboard_for_context(current_context)

    # 3. User's primary context (fallback)
    true ->
      primary_profile = UserProfile.get_primary_for_user(user)
      default_dashboard_for_profile(primary_profile)
  end
end
```

**Examples:**
```
# User clicks "Login" from merchant.base.do/products
→ redirect_to=/products
→ After login: merchant.base.do/products ✅

# User visits customer.bobs-burgers.base.do
→ No redirect_to
→ After login: customer.bobs-burgers.base.do/ (shop) ✅

# User visits app.base.do
→ No redirect_to
→ After login: app.base.do/ (context switcher) ✅
```

---

## IMPLEMENTATION READY

All architectural decisions are finalized and approved. Ready to proceed with:

1. **Run `/bmad:bmm:workflows:architecture`** - Generate final architecture document
2. **Run `/bmad:bmm:workflows:create-epics-and-stories`** - Break down into implementable epics
3. **Begin implementation** - Start building with Ash + DaisyUI + BMAD integration

---

**Schema Documentation Location:** `/Users/rp/Developer/Base/mcp/docs/schemas/`

**All decisions documented:** 2025-11-17
