# Core Platform Services Overview

The **Core Platform** is the high-performance foundation of the multi-tenant SaaS architecture. It provides the essential "plumbing" for identity, isolation, security, and infrastructure management across all domains.

## 1. Core Functions
- **Identity & Access**: Determining *who* is making a request (User/API Key).
- **Tenancy**: Resolving the target environment (Tenant Context) via subdomains or slugs.
- **Isolation**: enforcing strict boundaries between tenants at the Database (Schema) and Cache (Redis) levels.
- **Security**: Validating authentication tokens, API keys, and cross-tenant permissions.
- **Infrastructure**: Automating the lifecycle of tenants, including provisioning, migrations, backups, and custom domains.

## 2. Key Components

### 2.1. Service Layer Decomposition
The platform uses a modular infrastructure to avoid "God Object" anti-patterns:
- **`Mcp.Infrastructure.TenantManager`**: Handles tenant resolution (host/slug), schema provision status, and high-level platform configuration.
- **`Mcp.Infrastructure.Context`**: A framework-agnostic carrier struct used to propagate `tenant_id`, `user_id`, and `permissions` throughout the service layer.
- **`Mcp.Infrastructure.CacheManager`**: Centralized Redis (`Redix`) orchestration for high-performance lookups.

### 2.2. Web Pipeline (Plugs)
- **`McpWeb.Plugs.ContextPlug`**:
    - Resolves the `Tenant` context early in the request lifecycle using the `Host` header.
    - Utilizes a 5-minute TTL Redis cache (`tenant_host:<host>`) to eliminate redundant DB lookups.
- **`McpWeb.Plugs.ApiAuthPlug`**:
    - Secures API routes via `X-API-Key` or `Authorization: Bearer` headers.
    - Authenticates against the `Mcp.Platform.ApiKey` resource.
- **`McpWeb.Plugs.SessionPlug`**:
    - Manages browser-based user sessions and verifies tenant-user membership.

### 2.3. Multi-Tenant Storage
Built on S3-compatible storage (MinIO), the platform provides secure object management:
- **Private Buckets**: For secure documents (e.g., invoices). Requires presigned URLs (`GptCore.Storage.PresignedUrl`).
- **Public Buckets**: For branding assets (e.g., logos).
- **Quota Enforcement**: Automatic storage limit tracking and enforcement during file uploads.

## 3. Platform Capabilities

### 3.1. Tenant Lifecycle & Onboarding
- **Invitations (Epic 7)**: A secure, token-based system for onboarding users into specific tenants or entities.
- **Custom Domains (Epic 11)**: Allows tenants to verify and use their own domains via DNS TXT records (`Mcp.Infrastructure.DnsVerifier`).
- **Schema Provisioning**: automated creation and migration of isolated Postgres schemas for new tenants.

### 3.2. Communications (Epic 12)
- **Webhooks**: Reliable event delivery system built on `Oban` and `Req`, with HMAC-SHA256 signature verification.

## 4. Solid Core Standards
The "Zero Defects" methodology is strictly applied to core services:
- **Discrete Execution Helpers**: Complex logic (backups, branding deactivation) is extracted from resource hooks into named service handlers to keep code complexity low (≤ 9) and nesting shallow (≤ 2).
- **Pristine Metadata**: Cache keys and logs are consistently prefixed (e.g., `tenant:{id}:*`) to ensure observability without cross-contamination.
- **Strict Verification**: Clean builds (`warnings-as-errors`) and comprehensive integration tests (requiring explicit host resolution) are mandatory quality gates.
