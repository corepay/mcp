# Tenant Isolation Architecture

The platform provides strict isolation between tenants using multi-schema PostgreSQL architecture and context-aware application logic.

## 1. Schema-Based Isolation
Data is partitioned across three distinct schema layers:
- **Platform Schema (`platform` / `public`)**: System-wide resources (Users, Tenants, API Keys).
- **Tenant Schemas (`acq_...` / `tenant_...`)**: Isolated business data for each organization.
- **Audit Schema (`ag_catalog` / `audit`)**: Shared audit trails and ledger logs.

### 1.1. Context Switching
Ash Framework's `multitenancy strategy :context` handles the dynamic schema switching. When a request is identified as tenant-scoped, the `ContextPlug` resolves the tenant and the application calls `Ash.set_tenant(tenant.company_schema)`.

## 2. Cache Isolation
To prevent cross-tenant leakage in high-performance paths (Redis), the platform utilizes the `TenantIsolation` pattern (or `CacheManager` prefixes).
- **Namespace**: `tenant:{id}:*`
- **Isolation Scope**: The `with_tenant_cache(tenant_id)` macro ensures that all cache operations within its block are automatically prefixed, preventing accidental access to other orgs' data.

## 3. Storage Isolation
Built on S3/MinIO, the storage system provisions dedicated identifiers for each tenant:
- **Private/Public Buckets**: Each tenant is provisioned with unique, slug-based buckets.
- **Identifier Resolution**: Workers must resolve the physical bucket `name` from the logical `bucket_id` (UUID) to ensure robustness against naming migrations.

## 4. Entity Hierarchy and Scope
Resources are either **Global**, **Platform-Scoped**, or **Tenant-Scoped**.

| Resource Level | Example | Scope |
| :--- | :--- | :--- |
| **Global** | `Users` | System-wide, shared auth. |
| **Platform** | `Tenant`, `ApiKey` | Org settings and access gates. |
| **Tenant** | `Merchant`, `Order` | Isolated organization data. |

### 4.1. Scoped Lookups
Global lookups for tenant-isolated resources (e.g., `Merchant.by_slug/1`) are prohibited. The platform enforces **Hierarchical Resolution**:
1. Resolve the Tenant (via subdomain/context).
2. Pass the tenant schema to the resource action.
3. Resource performs a scoped query within the isolated schema.
