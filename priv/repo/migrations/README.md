# Database Migrations

This directory contains Ecto migrations for the Base MCP platform. These migrations implement the complete schema architecture including multi-tenancy, polymorphic shared entities, and lookup table patterns.

## Migration Files

### 00001 - Platform Schema and Extensions
**File:** `20250117000001_create_platform_schema_and_extensions.exs`

Creates the foundational `platform` schema and enables required PostgreSQL extensions:
- **citext**: Case-insensitive text for emails
- **postgis**: Geospatial queries for addresses
- **pgcrypto**: Cryptographic functions
- **uuid-ossp**: UUID generation

### 00002 - Lookup Tables
**File:** `20250117000002_create_lookup_tables.exs`

Creates all lookup tables that replace PostgreSQL ENUMs for flexibility:
- `entity_types` - All polymorphic entity types (30+ types)
- `address_types` - Address classifications
- `email_types` - Email classifications
- `phone_types` - Phone classifications with SMS support flags
- `social_platforms` - Social media platforms with URL patterns
- `image_types` - Image classifications with file size limits
- `document_types` - Document classifications with retention policies
- `status_types` - Universal status values with colors
- `plan_types` - Subscription plan configurations

**Seeded Data:**
- 30+ entity types across 6 categories (core, commerce, payments, shipping, content, marketing, support)
- 3 plan types (Starter $0, Professional $49, Enterprise $149)
- Status types with UI colors for all major workflows

### 00003 - Users
**File:** `20250117000003_create_users.exs`

Creates `platform.users` table for global authentication:
- Email/password authentication (ash_authentication)
- 2FA support (TOTP, backup codes)
- OAuth tokens (Google, GitHub)
- Session tracking
- Account status management

### 00004 - User Profiles
**File:** `20250117000004_create_user_profiles.exs`

Creates `platform.user_profiles` table for entity-scoped identities:
- One profile per user per entity (tenant, merchant, reseller, etc.)
- Entity-specific name, avatar, bio, contact info
- Role flags (admin, developer)
- Invitation workflow support
- Preferences (UI, notifications, accessibility)

**Key Constraint:** `UNIQUE(user_id, entity_type, entity_id)`

### 00005 - Tenants
**File:** `20250117000005_create_tenants.exs`

Creates `platform.tenants` table for top-level entities:
- Slug-based identification
- Subdomain routing (`{slug}.base.do`)
- Custom domain support
- Plan and subscription management
- Trial period tracking (14 days)
- Onboarding workflow state
- Configuration (settings, branding)

**Triggers Reactor Saga:** Tenant onboarding creates schema, provisions DNS, sets up admin profile

### 00006 - Polymorphic Shared Entities
**File:** `20250117000006_create_polymorphic_shared_entities.exs`

Creates 8 polymorphic tables that can belong to any entity:

1. **Addresses** - Physical addresses with PostGIS geocoding
2. **Emails** - Email addresses with verification
3. **Phones** - Phone numbers with SMS capability flags
4. **Socials** - Social media profiles
5. **Images** - S3/MinIO stored images with thumbnails
6. **Documents** - Encrypted documents with retention policies
7. **Todos** - Task management with checklists
8. **Notes** - Note-taking with full-text search

**Row-Level Security:** All tables have RLS policies for access control

### 00007 - Tenant Schema Functions
**File:** `20250117000007_create_tenant_schema_functions.exs`

Creates PostgreSQL functions for tenant schema management:
- `create_tenant_schema(tenant_slug)` - Creates `acq_{slug}` schema
- `drop_tenant_schema(tenant_slug)` - Drops tenant schema

### 00008 - Tenant-Scoped Tables
**File:** `20250117000008_create_tenant_scoped_tables.exs`

Creates table templates for tenant-specific schemas:
- `merchants` - Merchant accounts
- `mids` - Payment gateway accounts (Merchant IDs)
- `stores` - Sub-brands within merchants
- `customers` - End customers with authentication
- `developers` - API partners
- `resellers` - White-label partners

**Templates stored in:** `platform.tenant_table_templates`

### 00009 - API Keys and Teams
**File:** `20250117000009_create_api_keys_and_teams.exs`

Creates authentication and collaboration tables:
- `api_keys` - Developer API keys with scopes and rate limits
- `teams` - Entity-scoped team structures
- `team_members` - Team membership with roles

### 00010 - Payment Gateways and Audit Logs
**File:** `20250117000010_create_payment_gateways_and_audit_logs.exs`

Creates platform-level infrastructure:
- `payment_gateways` - Gateway configurations (Stripe, Authorize.Net, PayPal)
- `audit_logs` - Compliance and security audit trail

**Seeded Gateways:**
- Stripe (default)
- Authorize.Net
- PayPal

## Running Migrations

```bash
# Run all pending migrations
mix ecto.migrate

# Rollback last migration
mix ecto.rollback

# Rollback N migrations
mix ecto.rollback --step N

# Reset database (drop, create, migrate, seed)
mix ecto.reset
```

## Multi-Tenancy Pattern

The platform uses **schema-based multi-tenancy**:

1. **Platform Schema** (`platform`): Global tables (users, tenants, lookup tables, shared entities)
2. **Tenant Schemas** (`acq_{slug}`): Tenant-specific tables (merchants, customers, transactions)

**Search Path:** `acq_{tenant} → platform → public`

### Creating a New Tenant

When a tenant is onboarded:

1. Tenant record created in `platform.tenants`
2. `create_tenant_schema('tenant_slug')` function called
3. Tenant tables created from templates in `platform.tenant_table_templates`
4. DNS provisioned via CloudFlare
5. Admin user profile created
6. Welcome email sent

**Reactor Saga:** `Mcp.Tenants.OnboardingReactor`

## Lookup Tables Pattern

All ENUMs replaced with FK to lookup tables for flexibility:

### Benefits
- ✅ No schema migrations to add/remove values
- ✅ No table locks
- ✅ Metadata storage (icons, colors, descriptions)
- ✅ Soft delete capability
- ✅ Runtime configuration
- ✅ Queryable for UI dropdowns

### Example Usage

```elixir
# Add new entity type without migration
Mcp.Shared.EntityType.add_type(%{
  value: "subscription",
  label: "Subscription",
  category: "commerce",
  sort_order: 18
})

# Reference in polymorphic tables
CREATE TABLE addresses (
  owner_type TEXT NOT NULL REFERENCES platform.entity_types(value),
  owner_id UUID NOT NULL,
  ...
)
```

## Row-Level Security (RLS)

All polymorphic shared entities use PostgreSQL RLS for access control:

### Access Rules
1. Users can see their own data
2. Users can see data for entities they belong to (via `user_profiles`)
3. Admins have elevated access within their entity
4. Public data visible to all

### Session Variables
- `app.current_user_id` - Current user UUID
- `app.current_tenant_id` - Current tenant UUID

### Example Policy

```sql
CREATE POLICY addresses_select ON platform.addresses
  FOR SELECT
  USING (
    (owner_type = 'user' AND owner_id = current_setting('app.current_user_id', true)::uuid)
    OR
    EXISTS (
      SELECT 1 FROM platform.user_profiles up
      WHERE up.user_id = current_setting('app.current_user_id', true)::uuid
        AND up.entity_type = addresses.owner_type
        AND up.entity_id = addresses.owner_id
        AND up.status = 'active'
    )
  );
```

## Database Extensions

### PostGIS (Addresses)
```sql
-- Store geocoded location
location GEOGRAPHY(POINT, 4326)

-- Spatial index
CREATE INDEX idx_addresses_location ON platform.addresses USING GIST(location);

-- Query within radius
SELECT * FROM platform.addresses
WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326), 5000);
```

### Full-Text Search (Notes)
```sql
-- Full-text search index
CREATE INDEX idx_notes_content_search ON platform.notes
USING GIN(to_tsvector('english', content));

-- Search query
SELECT * FROM platform.notes
WHERE to_tsvector('english', content) @@ plainto_tsquery('english', 'payment processing');
```

### TimescaleDB (Ready for Phase 2)
```sql
-- Convert audit_logs to hypertable for time-series optimization
SELECT create_hypertable('platform.audit_logs', 'created_at');
```

## Data Retention Policies

### Documents
- **KYC Documents:** 7 years
- **Contracts:** 7 years
- **Financial Records:** 7 years
- **Audit Logs:** 1 year (configurable per tenant)
- **Deleted Users:** 90 days (GDPR compliance)

### Implementation
- Oban background jobs for scheduled purges
- `expires_at` timestamp on document records
- Soft delete on users (status: 'deleted')

## Security Considerations

### Encryption
- **Passwords:** bcrypt (cost factor: 12)
- **TOTP Secrets:** Encrypted via Cloak (HashiCorp Vault)
- **Documents:** Server-side encryption via Vault
- **API Keys:** Hashed with prefix for identification

### Sensitive Data
- `hashed_password` (users)
- `totp_secret` (users)
- `backup_codes` (users)
- `gateway_credentials` (mids)
- `encryption_key_id` (documents)

### Rate Limiting
- Login attempts: 5 per 15 minutes
- API calls: Configurable per API key
- Account lockout: After 5 failed logins

## Next Steps

1. ✅ Run migrations: `mix ecto.migrate`
2. ✅ Verify schema: `psql mcp_dev -c "\dt platform.*"`
3. Create seed data: `priv/repo/seeds.exs`
4. Implement Ash Resources for each table
5. Create Reactor sagas for workflows (tenant onboarding, merchant KYC)
6. Set up TimescaleDB hypertables for transactions
7. Configure RLS policies with session variables
8. Implement Oban jobs for retention policies

## Architecture Document

For complete architectural context and OTP supervision strategy, see:
- `/Users/rp/Developer/Base/mcp/docs/architecture.md`
- `/Users/rp/Developer/Base/mcp/docs/schemas/` (schema specifications)
