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
- [x] **Infrastructure:** Ensure `Redix` is configured for caching.
- [x] **Feature:** Update `McpWeb.Plugs.ContextPlug` to check Redis before DB.
  - Key: `routing:{hostname}`
  - TTL: 300 seconds (5 mins)
  - Value: `{:ok, context_type, entity_slug}`
- [x] **Test:** Verify cache hits/misses in `ContextPlugTest`.

#### 2. Shared Entities Remediation (Epic 9)
**Goal:** Fix insecure `policy always()` and implement true polymorphism.
- [x] **Database:** Create RLS Helper Function `platform.can_access_owner(user, type, id)`.
- [x] **Resource:** Refactor `Mcp.Platform.Address`:
  - Enforce `owner_type` enum (user, tenant, merchant, etc.).
  - Remove `allow_nil?: false` from non-critical fields if needed.
  - **Security:** Replace `policy always()` with proper actor checks.
  - **Feature:** Implement `AshGeo` or PostGIS logic for `location`.
- [x] **Resource:** Refactor `Mcp.Platform.Email` & `Mcp.Platform.Phone`:
  - Secure policies.
  - Implement `primary` toggle logic (atomic updates).

### Phase 2: Architectural Refactoring

#### 3. Decompose `Mcp.MultiTenant` God Object
- [x] **New Module:** `Mcp.Infrastructure.TenantManager`
  - Handle Schema creation, migrations, and specialized tenant lifecycle tasks.
- [x] **New Module:** `Mcp.Infrastructure.Context`
  - Handle process-dictionary logic for `put_tenant`, `get_tenant`.
- [x] **Refactor:** Find and replace all `Mcp.MultiTenant` usages.

### Phase 3: Missing Feature Infrastructure

#### 4. API Keys (Epic 10)
- [x] **Resource:** Create `Mcp.Platform.ApiKey` (3-tier model: Developer, Merchant, Reseller).
- [x] **Security:** Implement `McpWeb.Plugs.ApiAuthPlug`.
  - Header: `API-Key`.
  - Scope validation.
- [x] **UI:** Create LiveViews for Key Management.

#### 5. Custom Domains (Epic 11)
- [ ] **Resource:** Create `Mcp.Platform.CustomDomain`.
- [ ] **Automation:** Implement `ProvisionReactor` (DNS Check -> Cert -> Routing).

### Phase 4: Billing Integration (New)

#### 6. M2M Billing Integration
- [x] **Service:** `Mcp.Billing.ApiUsage` (calculate and charge).
- [x] **Integration:** `ApiAuthPlug` triggers billing on success.
- [x] **Fix:** Resolve `Jason.Encoder` Tuple Error.
  - **Root Cause:** Missing Postgrex operators (`+`, `-`, `SUM`) for `money_with_currency` composite type.
  - **Resolution:** Implemented idempotent migration `20251226032956_add_money_with_currency_type_to_postgres.exs`.

## Verification Plan

### Automated Tests
- [x] `mix test test/mcp_web/plugs/context_plug_test.exs` (Cache verification)
- [x] `mix test test/mcp/platform/shared_entities_test.exs` (Shared entities policies)
- [x] `mix check` (Zero Defects verified: No Credo/Dialyzer issues)
- [x] `mix test test/mcp/billing` (Billing transfer verification)

### Manual Verification
- [x] Verify Redis keys are created on portal access.
- [x] Verify RLS policies prevent cross-tenant access in `iex`.

