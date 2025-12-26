# Platform Optimization & Gap Closure Plan

**Goal:** Achieve "Zero Defects" and "Solid Core" status by addressing all identified gaps from the Architecture Audit.
**Scope:** Performance (Redis), Security (RLS, Shared Entities), Architecture (Refactoring), and Missing Features (API Keys, Custom Domains).

## User Review Required
> [!IMPORTANT]
> **Breaking Change:** Refactoring `Mcp.MultiTenant` will require updating all callsites. This is a high-risk, high-reward architectural change.
> **Security Audit:** We are enabling RLS (Row-Level Security). This is a fundamental change to how data access is enforced.

## Proposed Changes

### Phase 1: Critical Optimizations (Performance & Security)

#### 1. ContextPlug Redis Caching (Epic 8)
- [ ] **Infrastructure:** Ensure `Redix` is configured for caching.
- [ ] **Feature:** Update `McpWeb.Plugs.ContextPlug` to check Redis before DB.
  - Key: `routing:{hostname}`
  - TTL: 300 seconds (5 mins)
  - Value: `{:ok, context_type, entity_slug}`
- [ ] **Test:** Verify cache hits/misses in `ContextPlugTest`.

#### 2. Shared Entities Remediation (Epic 9)
**Goal:** Fix insecure `policy always()` and implement true polymorphism.
- [ ] **Database:** Create RLS Helper Function `platform.can_access_owner(user, type, id)`.
- [ ] **Resource:** Refactor `Mcp.Platform.Address`:
  - Enforce `owner_type` enum (user, tenant, merchant, etc.).
  - Remove `allow_nil?: false` from non-critical fields if needed.
  - **Security:** Replace `policy always()` with proper actor checks.
  - **Feature:** Implement `AshGeo` or PostGIS logic for `location`.
- [ ] **Resource:** Refactor `Mcp.Platform.Email` & `Mcp.Platform.Phone`:
  - Secure policies.
  - Implement `primary` toggle logic (atomic updates).

### Phase 2: Architectural Refactoring

#### 3. Decompose `Mcp.MultiTenant` God Object
- [ ] **New Module:** `Mcp.Infrastructure.TenantManager`
  - Handle Schema creation, migrations, and specialized tenant lifecycle tasks.
- [ ] **New Module:** `Mcp.Infrastructure.Context`
  - Handle process-dictionary logic for `put_tenant`, `get_tenant`.
- [ ] **Refactor:** Find and replace all `Mcp.MultiTenant` usages.

### Phase 3: Missing Feature Infrastructure

#### 4. API Keys (Epic 10)
- [ ] **Resource:** Create `Mcp.Platform.ApiKey` (3-tier model: Developer, Merchant, Reseller).
- [ ] **Security:** Implement `McpWeb.Plugs.ApiAuthPlug`.
  - Header: `API-Key`.
  - Scope validation.
- [ ] **UI:** Create LiveViews for Key Management.

#### 5. Custom Domains (Epic 11)
- [ ] **Resource:** Create `Mcp.Platform.CustomDomain`.
- [ ] **Automation:** Implement `ProvisionReactor` (DNS Check -> Cert -> Routing).

## Verification Plan

### Automated Tests
- `mix test test/mcp_web/plugs/context_plug_test.exs` (Cache verification)
- `mix test test/mcp/domains/shared` (New shared entity tests)
- `mix check` (Ensure no regressions from refactoring)

### Manual Verification
- Verify Redis keys are created on portal access.
- Verify RLS policies prevent cross-tenant access in `iex`.
