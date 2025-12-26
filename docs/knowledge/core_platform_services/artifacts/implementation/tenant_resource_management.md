# Tenant Resource Management

Lifecycle and security of organization-level infrastructure.

## 1. Storage provisioning
Tenants are provisioned with standardized buckets upon creation:
- **Public**: `#{slug}-public` for branding.
- **Private**: `#{slug}-private` for documents, protected by presigned URLs.

## 2. Storage Quota Logic
Quotas are dynamic and based on purchased credit blocks.
- **Formula**: `1GB (Base) + (Storage_Blocks * 5GB)`.
- **Enforcement**: Checked during `sign_upload` requests.

## 3. Custom Domains
managed via `Mcp.Platform.CustomDomain`. 
- Status Flow: `pending_verification` -> `verified` -> `active`.
- Uses `DnsVerifier` to bypass local resolver caches.

## 4. Diagnostic Workflow
- **404 Organization Not Found**: Verify `subdomain` vs `host`. Check Redis cache for stale routing data.
- **NoSuchBucket**: Resolve the physical name from UUID-based settings.
- **Quota Exceeded**: Verify billing balance and aggregated object sizes.
