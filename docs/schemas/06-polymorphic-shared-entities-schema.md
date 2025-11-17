# Polymorphic Shared Entities Schema (Updated with Lookup Tables)

**Purpose:** Shared entities that can belong to multiple owner types (users, merchants, products, orders, etc.)
**Storage:** `platform` schema (global, not tenant-scoped)
**Access Control:** Row-Level Security (RLS) policies

---

## Addresses

```sql
CREATE TABLE platform.addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Polymorphic association (FK to lookup table, NO CHECK constraint!)
  owner_type TEXT NOT NULL REFERENCES platform.entity_types(value),
  owner_id UUID NOT NULL,

  -- Address type (FK to lookup table)
  address_type TEXT REFERENCES platform.address_types(value),

  -- Address data
  label TEXT,  -- "Home", "Office", "Warehouse", etc.
  line1 TEXT NOT NULL,
  line2 TEXT,
  city TEXT NOT NULL,
  state TEXT,
  postal_code TEXT NOT NULL,
  country TEXT NOT NULL DEFAULT 'US',

  -- Geocoding (PostGIS)
  location GEOGRAPHY(POINT, 4326),

  -- Validation
  is_verified BOOLEAN DEFAULT false,
  verified_at TIMESTAMP,
  verification_method TEXT,  -- 'manual', 'usps', 'google_maps'

  -- Default flags
  is_primary BOOLEAN DEFAULT false,

  -- Metadata
  notes TEXT,

  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_addresses_owner ON platform.addresses(owner_type, owner_id);
CREATE INDEX idx_addresses_location ON platform.addresses USING GIST(location);
CREATE INDEX idx_addresses_is_primary ON platform.addresses(owner_type, owner_id, is_primary) WHERE is_primary = true;
CREATE INDEX idx_addresses_type ON platform.addresses(address_type);

-- Row-Level Security
ALTER TABLE platform.addresses ENABLE ROW LEVEL SECURITY;

CREATE POLICY addresses_select ON platform.addresses
  FOR SELECT
  USING (
    -- User can see their own addresses
    (owner_type = 'user' AND owner_id = current_setting('app.current_user_id', true)::uuid)
    OR
    -- User can see addresses of entities they belong to via user_profiles
    EXISTS (
      SELECT 1 FROM platform.user_profiles up
      WHERE up.user_id = current_setting('app.current_user_id', true)::uuid
        AND up.entity_type = addresses.owner_type
        AND up.entity_id = addresses.owner_id
        AND up.status = 'active'
    )
    OR
    -- Merchants can see customer addresses (for shipping/billing)
    (owner_type = 'customer' AND EXISTS (
      SELECT 1 FROM platform.user_profiles up
      WHERE up.user_id = current_setting('app.current_user_id', true)::uuid
        AND up.entity_type = 'merchant'
        AND up.status = 'active'
        AND EXISTS (
          SELECT 1 FROM customers c
          WHERE c.id = addresses.owner_id
            AND c.merchant_id = up.entity_id
        )
    ))
    OR
    -- Orders can see associated addresses (customer, shipping, billing)
    (owner_type IN ('customer', 'merchant', 'store') AND EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = current_setting('app.current_order_id', true)::uuid
        AND (
          o.customer_id = addresses.owner_id
          OR o.merchant_id = addresses.owner_id
          OR o.store_id = addresses.owner_id
        )
    ))
  );
```

---

## Emails

```sql
CREATE TABLE platform.emails (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Polymorphic association
  owner_type TEXT NOT NULL REFERENCES platform.entity_types(value),
  owner_id UUID NOT NULL,

  -- Email type
  email_type TEXT REFERENCES platform.email_types(value),

  -- Email data
  label TEXT,
  email CITEXT NOT NULL,

  -- Verification
  is_verified BOOLEAN DEFAULT false,
  verified_at TIMESTAMP,
  verification_token TEXT,
  verification_sent_at TIMESTAMP,

  -- Default flag
  is_primary BOOLEAN DEFAULT false,

  -- Email preferences
  can_receive_marketing BOOLEAN DEFAULT false,
  can_receive_transactional BOOLEAN DEFAULT true,

  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_emails_owner ON platform.emails(owner_type, owner_id);
CREATE INDEX idx_emails_email ON platform.emails(email);
CREATE INDEX idx_emails_type ON platform.emails(email_type);
CREATE INDEX idx_emails_is_primary ON platform.emails(owner_type, owner_id, is_primary) WHERE is_primary = true;

ALTER TABLE platform.emails ENABLE ROW LEVEL SECURITY;

CREATE POLICY emails_owner_access ON platform.emails
  FOR ALL
  USING (
    (owner_type = 'user' AND owner_id = current_setting('app.current_user_id', true)::uuid)
    OR
    EXISTS (
      SELECT 1 FROM platform.user_profiles up
      WHERE up.user_id = current_setting('app.current_user_id', true)::uuid
        AND up.entity_type = emails.owner_type
        AND up.entity_id = emails.owner_id
        AND up.status = 'active'
    )
  );
```

---

## Phones

```sql
CREATE TABLE platform.phones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Polymorphic association
  owner_type TEXT NOT NULL REFERENCES platform.entity_types(value),
  owner_id UUID NOT NULL,

  -- Phone type
  phone_type TEXT REFERENCES platform.phone_types(value),

  -- Phone data
  label TEXT,
  phone TEXT NOT NULL,
  country_code TEXT DEFAULT 'US',
  extension TEXT,

  -- Verification
  is_verified BOOLEAN DEFAULT false,
  verified_at TIMESTAMP,
  verification_code TEXT,
  verification_sent_at TIMESTAMP,

  -- Capabilities
  can_sms BOOLEAN DEFAULT false,
  can_voice BOOLEAN DEFAULT true,

  -- Default flag
  is_primary BOOLEAN DEFAULT false,

  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_phones_owner ON platform.phones(owner_type, owner_id);
CREATE INDEX idx_phones_phone ON platform.phones(phone);
CREATE INDEX idx_phones_type ON platform.phones(phone_type);
CREATE INDEX idx_phones_can_sms ON platform.phones(can_sms) WHERE can_sms = true;

ALTER TABLE platform.phones ENABLE ROW LEVEL SECURITY;

CREATE POLICY phones_owner_access ON platform.phones
  FOR ALL
  USING (
    (owner_type = 'user' AND owner_id = current_setting('app.current_user_id', true)::uuid)
    OR
    EXISTS (
      SELECT 1 FROM platform.user_profiles up
      WHERE up.user_id = current_setting('app.current_user_id', true)::uuid
        AND up.entity_type = phones.owner_type
        AND up.entity_id = phones.owner_id
        AND up.status = 'active'
    )
  );
```

---

## Socials

```sql
CREATE TABLE platform.socials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Polymorphic association
  owner_type TEXT NOT NULL REFERENCES platform.entity_types(value),
  owner_id UUID NOT NULL,

  -- Platform
  platform TEXT NOT NULL REFERENCES platform.social_platforms(value),

  -- Social data
  username TEXT NOT NULL,
  url TEXT NOT NULL,

  -- Verification
  is_verified BOOLEAN DEFAULT false,
  verified_at TIMESTAMP,

  -- Visibility
  is_public BOOLEAN DEFAULT true,  -- Show on public profile

  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

  UNIQUE(owner_type, owner_id, platform)  -- One platform per owner
);

CREATE INDEX idx_socials_owner ON platform.socials(owner_type, owner_id);
CREATE INDEX idx_socials_platform ON platform.socials(platform);
CREATE INDEX idx_socials_is_public ON platform.socials(is_public) WHERE is_public = true;

ALTER TABLE platform.socials ENABLE ROW LEVEL SECURITY;

CREATE POLICY socials_read_public ON platform.socials
  FOR SELECT
  USING (
    is_public = true
    OR
    (owner_type = 'user' AND owner_id = current_setting('app.current_user_id', true)::uuid)
    OR
    EXISTS (
      SELECT 1 FROM platform.user_profiles up
      WHERE up.user_id = current_setting('app.current_user_id', true)::uuid
        AND up.entity_type = socials.owner_type
        AND up.entity_id = socials.owner_id
    )
  );

CREATE POLICY socials_manage_owner ON platform.socials
  FOR ALL
  USING (
    (owner_type = 'user' AND owner_id = current_setting('app.current_user_id', true)::uuid)
    OR
    EXISTS (
      SELECT 1 FROM platform.user_profiles up
      WHERE up.user_id = current_setting('app.current_user_id', true)::uuid
        AND up.entity_type = socials.owner_type
        AND up.entity_id = socials.owner_id
        AND up.is_admin = true
    )
  );
```

---

## Images

```sql
CREATE TABLE platform.images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Polymorphic association (expanded to include ALL entity types)
  owner_type TEXT NOT NULL REFERENCES platform.entity_types(value),
  owner_id UUID NOT NULL,

  -- Image type
  image_type TEXT REFERENCES platform.image_types(value),

  -- Storage (S3/MinIO - metadata only, files stored externally)
  storage_provider TEXT DEFAULT 's3',  -- 's3', 'minio', 'cloudflare_r2'
  storage_bucket TEXT NOT NULL,
  storage_key TEXT NOT NULL,  -- /images/products/prod_123/main.jpg

  -- File metadata
  filename TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  file_size INTEGER NOT NULL,  -- Bytes
  width INTEGER,
  height INTEGER,
  alt_text TEXT,  -- Accessibility

  -- CDN/Access
  public_url TEXT,  -- CDN URL if public
  is_public BOOLEAN DEFAULT false,

  -- Processing
  is_processed BOOLEAN DEFAULT false,
  thumbnails JSONB DEFAULT '{}',  -- {small: 'url', medium: 'url', large: 'url'}

  -- Ordering (for galleries)
  sort_order INTEGER DEFAULT 0,

  -- Metadata
  metadata JSONB DEFAULT '{}',  -- EXIF data, color palette, etc.

  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_images_owner ON platform.images(owner_type, owner_id);
CREATE INDEX idx_images_type ON platform.images(image_type);
CREATE INDEX idx_images_is_public ON platform.images(is_public) WHERE is_public = true;
CREATE INDEX idx_images_storage ON platform.images(storage_provider, storage_bucket, storage_key);

ALTER TABLE platform.images ENABLE ROW LEVEL SECURITY;

CREATE POLICY images_read_public ON platform.images
  FOR SELECT
  USING (
    is_public = true
    OR
    (owner_type = 'user' AND owner_id = current_setting('app.current_user_id', true)::uuid)
    OR
    EXISTS (
      SELECT 1 FROM platform.user_profiles up
      WHERE up.user_id = current_setting('app.current_user_id', true)::uuid
        AND up.entity_type = images.owner_type
        AND up.entity_id = images.owner_id
    )
  );
```

---

## Documents

```sql
CREATE TABLE platform.documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Polymorphic association
  owner_type TEXT NOT NULL REFERENCES platform.entity_types(value),
  owner_id UUID NOT NULL,

  -- Document type
  document_type TEXT REFERENCES platform.document_types(value),

  -- Storage (encrypted at rest)
  storage_provider TEXT DEFAULT 's3',
  storage_bucket TEXT NOT NULL,
  storage_key TEXT NOT NULL,
  encryption_key_id TEXT,  -- Reference to Vault encryption key

  -- File metadata
  filename TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  file_size INTEGER NOT NULL,

  -- Classification
  category TEXT,
  tags TEXT[],

  -- Security
  is_sensitive BOOLEAN DEFAULT true,
  requires_approval BOOLEAN DEFAULT false,
  approved_by UUID REFERENCES platform.users(id),
  approved_at TIMESTAMP,

  -- Retention (GDPR/compliance)
  retention_policy TEXT,  -- References document_types.retention_years
  expires_at TIMESTAMP,

  -- Metadata
  metadata JSONB DEFAULT '{}',  -- OCR text, extracted data, etc.

  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_documents_owner ON platform.documents(owner_type, owner_id);
CREATE INDEX idx_documents_type ON platform.documents(document_type);
CREATE INDEX idx_documents_expires_at ON platform.documents(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX idx_documents_tags ON platform.documents USING GIN(tags);

ALTER TABLE platform.documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY documents_owner_access ON platform.documents
  FOR ALL
  USING (
    (owner_type = 'user' AND owner_id = current_setting('app.current_user_id', true)::uuid)
    OR
    EXISTS (
      SELECT 1 FROM platform.user_profiles up
      WHERE up.user_id = current_setting('app.current_user_id', true)::uuid
        AND up.entity_type = documents.owner_type
        AND up.entity_id = documents.owner_id
        AND (up.is_admin = true OR documents.is_sensitive = false)
    )
  );
```

---

## Todos

```sql
CREATE TABLE platform.todos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Owner (always user or user_profile)
  owner_type TEXT NOT NULL REFERENCES platform.entity_types(value),
  owner_id UUID NOT NULL,

  -- Related entity (optional - what this todo is about)
  related_to_type TEXT REFERENCES platform.entity_types(value),
  related_to_id UUID,

  -- Todo data
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'pending' REFERENCES platform.status_types(value),
  priority TEXT DEFAULT 'medium',  -- 'low', 'medium', 'high', 'urgent'

  -- Dates
  due_at TIMESTAMP,
  completed_at TIMESTAMP,

  -- Assignment
  assigned_to UUID REFERENCES platform.users(id),

  -- Metadata
  tags TEXT[],
  checklist JSONB DEFAULT '[]',  -- [{label: 'Subtask 1', done: false}]

  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_todos_owner ON platform.todos(owner_type, owner_id);
CREATE INDEX idx_todos_related_to ON platform.todos(related_to_type, related_to_id);
CREATE INDEX idx_todos_status ON platform.todos(status);
CREATE INDEX idx_todos_due_at ON platform.todos(due_at) WHERE due_at IS NOT NULL;
CREATE INDEX idx_todos_assigned_to ON platform.todos(assigned_to) WHERE assigned_to IS NOT NULL;

ALTER TABLE platform.todos ENABLE ROW LEVEL SECURITY;

CREATE POLICY todos_owner_access ON platform.todos
  FOR ALL
  USING (
    (owner_type = 'user' AND owner_id = current_setting('app.current_user_id', true)::uuid)
    OR
    assigned_to = current_setting('app.current_user_id', true)::uuid
  );
```

---

## Notes

```sql
CREATE TABLE platform.notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Owner
  owner_type TEXT NOT NULL REFERENCES platform.entity_types(value),
  owner_id UUID NOT NULL,

  -- Related entity (optional)
  related_to_type TEXT REFERENCES platform.entity_types(value),
  related_to_id UUID,

  -- Note data
  title TEXT,
  content TEXT NOT NULL,

  -- Classification
  category TEXT,
  tags TEXT[],

  -- Privacy
  is_private BOOLEAN DEFAULT true,  -- Private to user vs shared with team

  -- Pinning
  is_pinned BOOLEAN DEFAULT false,

  -- Metadata
  metadata JSONB DEFAULT '{}',

  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notes_owner ON platform.notes(owner_type, owner_id);
CREATE INDEX idx_notes_related_to ON platform.notes(related_to_type, related_to_id);
CREATE INDEX idx_notes_tags ON platform.notes USING GIN(tags);
CREATE INDEX idx_notes_is_pinned ON platform.notes(is_pinned) WHERE is_pinned = true;

-- Full-text search
CREATE INDEX idx_notes_content_search ON platform.notes USING GIN(to_tsvector('english', content));

ALTER TABLE platform.notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY notes_read ON platform.notes
  FOR SELECT
  USING (
    (owner_type = 'user' AND owner_id = current_setting('app.current_user_id', true)::uuid)
    OR
    (is_private = false AND EXISTS (
      SELECT 1 FROM platform.user_profiles up
      WHERE up.user_id = current_setting('app.current_user_id', true)::uuid
        AND up.entity_type = notes.owner_type
        AND up.entity_id = notes.owner_id
    ))
  );

CREATE POLICY notes_manage_owner ON platform.notes
  FOR ALL
  USING (
    (owner_type = 'user' AND owner_id = current_setting('app.current_user_id', true)::uuid)
    OR
    EXISTS (
      SELECT 1 FROM platform.user_profiles up
      WHERE up.user_id = current_setting('app.current_user_id', true)::uuid
        AND up.entity_type = notes.owner_type
        AND up.entity_id = notes.owner_id
        AND up.is_admin = true
    )
  );
```

---

## Key Improvements

1. ✅ **No ENUMs** - All type fields use FK to lookup tables
2. ✅ **Complete entity coverage** - All 30+ entity types supported
3. ✅ **Extensible** - Add new entity types with INSERT (no migration)
4. ✅ **RLS policies** - Security enforced at database level
5. ✅ **Flexible associations** - `related_to_type/id` for linking entities
6. ✅ **Metadata-rich** - JSONB for extensibility
7. ✅ **Full-text search** - GIN indexes for notes content
8. ✅ **Ordering** - sort_order for galleries, lists

---

## Usage Examples

```elixir
# Add address to product (for warehouse location)
Mcp.Shared.Address.create_for_owner(%{
  owner_type: "product",
  owner_id: product.id,
  address_type: "warehouse",
  line1: "789 Storage Ln",
  city: "Oakland",
  state: "CA",
  postal_code: "94607"
})

# Add note to customer
Mcp.Shared.Note.create(%{
  owner_type: "merchant",
  owner_id: merchant.id,
  related_to_type: "customer",
  related_to_id: customer.id,
  content: "Customer prefers morning delivery",
  is_private: false,  # Team can see
  tags: ["delivery", "preference"]
})

# Add todo for order fulfillment
Mcp.Shared.Todo.create(%{
  owner_type: "user",
  owner_id: user.id,
  related_to_type: "order",
  related_to_id: order.id,
  title: "Ship order #12345",
  status: "pending",
  priority: "high",
  due_at: DateTime.add(DateTime.utc_now(), 86400, :second)
})
```

---

## ✅ Technical Infrastructure Decisions

### Address Verification Service
**Decision:** ✅ Google Maps Geocoding API
**Rationale:** Global coverage, fast, returns lat/lng for PostGIS storage. $5 per 1000 requests is reasonable. Works worldwide (unlike USPS which is US-only).

**Implementation:**
- Validate addresses on creation/update
- Store geocoded lat/lng in `location` GEOGRAPHY column
- Use for distance-based queries and map display
- Fallback to user-entered address if geocoding fails

**API Integration:**
```elixir
defmodule Mcp.Shared.AddressVerification do
  def verify_address(address_params) do
    # Call Google Maps Geocoding API
    # Store lat/lng in location field
    # Return verified address + geocoded data
  end
end
```

### Image File Size Limits
**Decision:** ✅ Keep current limits
- **Avatar:** 5MB
- **Logo:** 2MB
- **Product Image:** 5MB
- **Banner:** 10MB

**Rationale:** Reasonable limits for modern high-quality images without excessive storage costs. Supports 4K images for banners, HD for products/avatars.

**Implementation:**
- Enforce at upload time (Phoenix controller)
- Validate in Ash Resource change
- Resize/compress images on upload (ImageMagick/Vix)
- Store originals + thumbnails in S3/MinIO

### Document Encryption Provider
**Decision:** ✅ HashiCorp Vault
**Rationale:** Already in the stack, enterprise-grade, centralized encryption with audit logs. Perfect for KYC documents, contracts, invoices.

**Implementation:**
- Store encrypted document URLs in `documents` table
- Use Vault transit secrets engine for document encryption/decryption
- Audit trail for all document access
- Key rotation support

**Vault Integration:**
```elixir
defmodule Mcp.Shared.DocumentEncryption do
  def encrypt_document(file_path) do
    # Upload to S3/MinIO
    # Encrypt S3 URL with Vault
    # Store encrypted URL in database
  end

  def decrypt_document(encrypted_url) do
    # Decrypt URL with Vault
    # Generate presigned S3 URL
    # Return temporary access URL
  end
end
```

### Full-Text Search Engine
**Decision:** ✅ Meilisearch
**Rationale:** Modern, fast, easy to deploy, great UX with typo tolerance. Less resource-intensive than Elasticsearch. Perfect for notes and document search.

**Implementation:**
- Index notes and documents on creation/update
- Webhook from Ash Resource to Meilisearch
- Support fuzzy search, typo tolerance, faceted filters
- Real-time indexing via Oban background jobs

**Meilisearch Integration:**
```elixir
defmodule Mcp.Search.NoteIndexer do
  use Oban.Worker

  @impl Oban.Worker
  def perform(%{note_id: note_id}) do
    note = Mcp.Shared.Note.get!(note_id)

    Meilisearch.add_documents("notes", [%{
      id: note.id,
      owner_type: note.owner_type,
      owner_id: note.owner_id,
      content: note.content,
      tags: note.tags,
      created_at: note.created_at
    }])
  end
end
```

**Search API:**
```elixir
# Search notes across all entities user has access to
Meilisearch.search("notes", "delivery preference", %{
  filter: "owner_type = merchant AND owner_id IN #{accessible_merchant_ids}"
})
```
