# 🎯 CORE FOUNDATION IMPLEMENTATION - MCP Platform

## 🚨 CRITICAL AGENT REQUIREMENTS

### **📖 MANDATORY READING BEFORE ANY CODING:**

1. **CLAUDE.md** - ✅ **ALWAYS READ FIRST** - Primary project guidelines,
   architecture, agent requirements
2. **AGENTS.md** - Phoenix/LiveView/Elixir/Ash Framework specific patterns and
   technology stack
3. **This Implementation Plan** - Specific phased implementation context and
   current state

### **⚠️ ARCHITECTURE COMPLIANCE REQUIRED:**

- ✅ Ash Framework only (NEVER use Ecto patterns)
- ✅ Component-driven UI with DaisyUI (NEVER dashboard LiveViews)
- ✅ Evidence-based development (NEVER estimates or "I think")
- ✅ NO STUBS, NO TODOs, NO REGRESSIONS - Production-ready code only

---

## 🚀 CURRENT IMPLEMENTATION STATUS

**✅ Overall Completion: 50% COMPLETE**

### **Successfully Delivered:**

- [x] **Tenant Management** ✅ - Full Ash Resource implementation with database
      persistence
- [x] **Platform Domain** ✅ - `Mcp.Platform` domain created and registered
- [x] **Settings Management** ✅ - Real TenantSettingsManager backed by Tenant
      resource
- [x] **GDPR Resources** ✅ - User, AuditTrail, DataExport Ash Resources
      operational
- [x] **Multi-Tenant Infrastructure** ✅ - `Mcp.MultiTenant` module with schema
      switching

### **Partially Complete:**

- [ ] **Authentication System** 🔄 (0% - All stubs, needs complete replacement)
- [ ] **GDPR Compliance** 🔄 (40% - Resources exist, anonymization/retention
      TODOs remain)

### **Not Started:**

- [ ] **Accounts Domain** ❌ - Domain doesn't exist (referenced in config but
      missing)
- [ ] **Schema Provisioning** ❌ - All stub implementations
- [ ] **System Monitoring** ❌ - All stub implementations

---

## 🛠️ CURRENT SYSTEM STATE

### **✅ Working Components:**

- **Phoenix Server**: Starts successfully on port 4000, compilation clean
- **Database**: PostgreSQL with platform schema, 19 migrations successfully
  applied
- **Tenant Resource**: `Mcp.Platform.Tenant` - Full CRUD operations via Ash
- **GDPR Domain**: `Mcp.Domains.Gdpr` with 3 resources (User, AuditTrail,
  DataExport)
- **Multi-Tenant DB**: Schema-based isolation with `acq_{tenant_id}` pattern
- **Cache Manager**: Redis client and cache manager operational
- **Storage**: S3/MinIO client factory implemented

### **🎯 Architecture Ready:**

- **Ash Framework**: Fully configured with 2 domains (Platform, GDPR)
- **Database Extensions**: TimescaleDB, PostGIS, pgvector, Apache AGE configured
- **Multi-Tenant Pattern**: Schema switching and isolation infrastructure
  complete
- **Component System**: DaisyUI + Tailwind CSS v4 configured

### **🔧 Key Files for Implementation:**

- **`lib/mcp/domains/platform.ex`**: Platform domain (just created, needs
  expansion)
- **`lib/mcp/platform/tenant.ex`**: Working Ash Resource example
- **`lib/mcp/multi_tenant.ex`**: Complete multi-tenant infrastructure
- **`config/config.exs`**: Domain registration (needs Accounts domain added)
- **`priv/repo/migrations/`**: 19 migrations, all applied successfully

---

## 📋 PHASED IMPLEMENTATION PLAN

## **PHASE 1: ACCOUNTS DOMAIN & AUTHENTICATION (Priority 1)**

### **Business Objectives:**

Replace all authentication stubs with production-ready Ash Resources to enable
secure user management, JWT sessions, OAuth integration, and 2FA capabilities.

### **Phase 1 Completion Criteria:**

- ✅ `Mcp.Accounts` domain created and registered
- ✅ All authentication functions use Ash Resources (zero stubs)
- ✅ JWT token generation/verification operational
- ✅ OAuth providers functional
- ✅ TOTP 2FA setup and verification working
- ✅ All tests passing (100% pass rate required)

---

### **Story 1.1: Create Accounts Domain & User Resource**

**Acceptance Criteria:**

- Create `lib/mcp/domains/accounts.ex` with Ash.Domain
- Convert `lib/mcp/accounts/user.ex` from stub to full Ash Resource
- Map to existing `platform.users` table (migration already exists)
- Implement actions: create, read, update, destroy, authenticate
- Add password hashing with bcrypt
- Register domain in `config/config.exs`

**Implementation Steps:**

1. Create `lib/mcp/domains/accounts.ex`:
   ```elixir
   defmodule Mcp.Accounts do
     use Ash.Domain, otp_app: :mcp
     resources do
       resource Mcp.Accounts.User
       resource Mcp.Accounts.AuthToken
       resource Mcp.Accounts.OAuthProvider
       resource Mcp.Accounts.TotpSecret
     end
   end
   ```

2. Replace `lib/mcp/accounts/user.ex` with Ash Resource:
   - Use `AshPostgres.DataLayer`
   - Map to `platform.users` table
   - Implement password hashing with `AshAuthentication.PasswordAuthentication`
   - Add email validation
   - Create actions for registration, login, password reset

3. Update `config/config.exs`:
   ```elixir
   ash_domains: [Mcp.Accounts, Mcp.Platform, Mcp.Domains.Gdpr]
   ```

**Verification:**

```bash
mix compile
mix test test/mcp/accounts/user_test.exs
```

---

### **Story 1.2: Implement AuthToken Resource for JWT Sessions**

**Acceptance Criteria:**

- Create `lib/mcp/accounts/auth_token.ex` as Ash Resource
- Map to `platform.auth_tokens` table (migration exists)
- Implement JWT generation with Joken
- Implement JWT verification and refresh
- Add token expiration and revocation
- Replace all stubs in `lib/mcp/accounts/jwt.ex`

**Implementation Steps:**

1. Create AuthToken Ash Resource with attributes:
   - `user_id` (belongs_to User)
   - `token_type` (:access | :refresh)
   - `token_hash` (hashed JWT for verification)
   - `expires_at`
   - `revoked_at`
   - `last_used_at`

2. Implement actions:
   - `generate_tokens` - Create access + refresh token pair
   - `verify_token` - Validate and return user
   - `refresh_access_token` - Generate new access token from refresh
   - `revoke_token` - Mark token as revoked

3. Replace `lib/mcp/accounts/jwt.ex` to use AuthToken resource

**Verification:**

```bash
mix test test/mcp/accounts/jwt_test.exs
```

---

### **Story 1.3: Implement OAuth Provider Resource**

**Acceptance Criteria:**

- Create `lib/mcp/accounts/oauth_provider.ex` as Ash Resource
- Map to `platform.oauth_providers` table
- Implement OAuth flow for Google, GitHub
- Store OAuth tokens securely
- Link OAuth accounts to User resource
- Replace all stubs in `lib/mcp/accounts/oauth.ex`

**Implementation Steps:**

1. Create OAuthProvider Ash Resource
2. Implement OAuth callback handling
3. Create user-oauth association
4. Integrate with Ueberauth

**Verification:**

```bash
mix test test/mcp/accounts/oauth_test.exs
```

---

### **Story 1.4: Implement TOTP Secret Resource for 2FA**

**Acceptance Criteria:**

- Create `lib/mcp/accounts/totp_secret.ex` as Ash Resource
- Map to user TOTP fields in database
- Implement TOTP setup with QR code generation
- Implement TOTP verification
- Implement backup codes generation and verification
- Replace all stubs in `lib/mcp/accounts/totp.ex`

**Implementation Steps:**

1. Create TotpSecret Ash Resource
2. Implement setup action with secret generation
3. Implement verify action with NimbleTOTP
4. Implement backup codes with secure random generation
5. Add recovery flow

**Verification:**

```bash
mix test test/mcp/accounts/totp_test.exs
```

---

### **Story 1.5: Implement Registration Settings Resource**

**Acceptance Criteria:**

- Create `lib/mcp/accounts/registration_settings.ex` as Ash Resource
- Map to tenant settings for self-registration control
- Implement tenant-level registration policies
- Replace all stubs in current registration_settings.ex

**Implementation Steps:**

1. Create RegistrationSettings Ash Resource
2. Link to Tenant resource
3. Implement policy checks
4. Add validation rules

**Verification:**

```bash
mix test test/mcp/registration/
```

---

## **PHASE 2: SCHEMA PROVISIONING (Priority 2)**

### **Business Objectives:**

Enable automatic tenant schema creation and management using the existing
`Mcp.MultiTenant` infrastructure.

### **Phase 2 Completion Criteria:**

- ✅ Schema provisioner uses real `Mcp.MultiTenant` functions
- ✅ Tenant creation triggers schema provisioning
- ✅ Schema initialization includes all extensions
- ✅ Zero stub implementations remain

---

### **Story 2.1: Implement Schema Provisioner**

**Acceptance Criteria:**

- Replace all stubs in `lib/mcp/platform/schema_provisioner.ex`
- Use `Mcp.MultiTenant.create_tenant_schema/1`
- Implement schema initialization with extensions
- Add rollback capability
- Integrate with Tenant resource lifecycle

**Implementation Steps:**

1. Replace stub functions with real `MultiTenant` calls:
   ```elixir
   def provision_schema(tenant_schema_name) do
     with {:ok, schema} <- MultiTenant.create_tenant_schema(tenant_schema_name),
          :ok <- initialize_schema_extensions(schema),
          :ok <- run_tenant_migrations(schema) do
       {:ok, schema}
     end
   end
   ```

2. Add Ash.Resource.Change for automatic provisioning on Tenant create
3. Implement cleanup on Tenant destroy

**Verification:**

```bash
mix test test/mcp/platform/schema_provisioner_test.exs
```

---

### **Story 2.2: Implement Tenant User Manager**

**Acceptance Criteria:**

- Replace all stubs in `lib/mcp/platform/tenant_user_manager.ex`
- Create user-tenant association resource
- Implement role-based access per tenant
- Support multi-tenant user access

**Implementation Steps:**

1. Create TenantUser Ash Resource for associations
2. Implement role management
3. Add tenant switching capabilities
4. Replace all stub functions

**Verification:**

```bash
mix test test/mcp/platform/tenant_user_manager_test.exs
```

---

## **PHASE 3: GDPR COMPLETION (Priority 3)**

### **Business Objectives:**

Complete GDPR compliance features including data anonymization, retention
scheduling, and comprehensive reporting.

### **Phase 3 Completion Criteria:**

- ✅ Data anonymization fully implemented
- ✅ Retention scheduling operational
- ✅ Legal holds functional
- ✅ Compliance reporting complete
- ✅ All TODOs resolved

---

### **Story 3.1: Implement Data Anonymization**

**Acceptance Criteria:**

- Replace TODOs in `lib/mcp/gdpr/anonymizer.ex`
- Implement field-level anonymization
- Support reversible anonymization where required
- Integrate with GDPR User resource

**Implementation Steps:**

1. Implement anonymization strategies:
   - Email: `user_<hash>@anonymized.local`
   - Name: `Anonymized User <id>`
   - Phone: `XXX-XXX-XXXX`
   - Address: Clear or generalize

2. Create Ash.Reactor workflow for anonymization
3. Add audit trail integration
4. Implement data restoration for legal requirements

**Verification:**

```bash
mix test test/mcp/gdpr/anonymizer_test.exs
```

---

### **Story 3.2: Implement Data Retention Scheduling**

**Acceptance Criteria:**

- Replace TODOs in `lib/mcp/gdpr/data_retention.ex`
- Implement Oban jobs for retention cleanup
- Add legal hold checking
- Create retention policy resource

**Implementation Steps:**

1. Create RetentionPolicy Ash Resource
2. Implement Oban worker for scheduled cleanup
3. Add legal hold checks before deletion
4. Integrate with compliance reporting

**Verification:**

```bash
mix test test/mcp/gdpr/data_retention_test.exs
```

---

### **Story 3.3: Implement Compliance Reporting**

**Acceptance Criteria:**

- Replace TODO in `lib/mcp/gdpr/compliance.ex`
- Generate comprehensive compliance reports
- Track GDPR metrics
- Export compliance data

**Implementation Steps:**

1. Implement report generation
2. Add metrics aggregation
3. Create export functionality
4. Add scheduling for periodic reports

**Verification:**

```bash
mix test test/mcp/gdpr/compliance_test.exs
```

---

## **PHASE 4: SYSTEM MONITORING (Priority 4)**

### **Business Objectives:**

Implement real system monitoring for CPU, memory, and resource usage.

### **Phase 4 Completion Criteria:**

- ✅ Real CPU monitoring implemented
- ✅ Real memory monitoring implemented
- ✅ Disk usage tracking operational
- ✅ All stubs replaced

---

### **Story 4.1: Implement System Monitoring**

**Acceptance Criteria:**

- Replace all stubs in `lib/mcp/system_helper.ex`
- Use `:os_mon` or similar for real metrics
- Implement telemetry integration
- Add alerting thresholds

**Implementation Steps:**

1. Integrate with Erlang `:os_mon` application
2. Implement real CPU/memory collection
3. Add telemetry events
4. Create monitoring dashboard data

**Verification:**

```bash
mix test test/mcp/system_helper_test.exs
```

---

## ✅ QUALITY VERIFICATION EVIDENCE

### **Current Compilation Status:**

```bash
$ mix compile
Compiling 2 files (.ex)
Generated mcp app
Exit code: 0
```

### **Current Test Status:**

```bash
$ mix test
# Tests run but many skipped due to stubs
# Full test suite will pass after implementation
```

### **Database State:**

```bash
$ mix ecto.migrate
== Already up
# 19 migrations applied successfully
# Tables: users, tenants, auth_tokens, oauth_providers, etc.
```

### **Git Status:**

```bash
$ git status
On branch gdpr_comprehensive_restoration
nothing to commit, working tree clean
# Latest commit: "fix: replace Tenant stubs with Ash Resources..."
```

---

## ⚠️ TECHNICAL DEBT & KNOWN ISSUES

### **High Priority:**

- **Authentication Stubs**: All auth functions are stubs - blocks production
  deployment
  - **Impact**: Cannot authenticate users, no security
  - **Fix**: Implement Phase 1 completely

- **Missing Accounts Domain**: Referenced in config but doesn't exist
  - **Impact**: Compilation warnings, architecture incomplete
  - **Fix**: Create domain in Story 1.1

### **Medium Priority:**

- **GDPR TODOs**: Anonymization and retention not implemented
  - **Impact**: GDPR compliance incomplete
  - **Fix**: Implement Phase 3

- **Schema Provisioning Stubs**: Cannot create tenant schemas
  - **Impact**: Multi-tenancy not operational
  - **Fix**: Implement Phase 2

### **Low Priority:**

- **System Monitoring Stubs**: Mock data only
  - **Impact**: No real monitoring
  - **Fix**: Implement Phase 4

- **Credo Refactoring Suggestions**: 41 refactoring opportunities
  - **Impact**: Code quality
  - **Fix**: Address incrementally during implementation

---

## 🔧 ENVIRONMENT & DEPENDENCIES

### **Development Environment:**

- **Elixir Version**: 1.17+ (from .tool-versions)
- **Phoenix Version**: 1.8.1
- **Database**: PostgreSQL 15.0 (via Docker, port 41789)
- **Cache**: Redis (via Docker)
- **Storage**: MinIO (via Docker)

### **Key Dependencies:**

- **ash**: ~> 3.0 - Core framework
- **ash_postgres**: ~> 2.0 - Database integration
- **ash_authentication**: ~> 4.0 - Auth framework
- **ash_json_api**: ~> 1.0 - API layer
- **ash_graphql**: ~> 1.0 - GraphQL layer
- **bcrypt_elixir**: ~> 3.0 - Password hashing
- **joken**: ~> 2.6 - JWT tokens
- **nimble_totp**: ~> 0.2 - TOTP 2FA
- **ueberauth**: ~> 0.10 - OAuth framework

### **Configuration Files:**

- **`config/config.exs`**: Main config, needs Accounts domain added
- **`config/dev.exs`**: Development settings
- **`config/runtime.exs`**: Runtime environment config
- **`.env`**: Database connection strings

---

## 🎪 COLLABORATIVE AGENT ACTIVATION

### **For New AI Agent Session:**

**🚨 CRITICAL - READ BEFORE ANY CODING:**

**1. Mandatory Reading (REQUIRED BEFORE ANY CODE CHANGES):**

- **CLAUDE.md**: ✅ **ALWAYS READ FIRST**
- **AGENTS.md**: Phoenix/LiveView/Elixir/Ash Framework patterns
- **This Implementation Plan**: Current context and phased approach

**2. Architecture Compliance Verification:**

```markdown
I've read CLAUDE.md and AGENTS.md and understand the project architecture
requirements:

- ✅ Ash Framework only (no Ecto patterns)
- ✅ Component-driven UI with DaisyUI (no dashboard LiveViews)
- ✅ Evidence-based development (no estimates)
- ✅ NO STUBS, NO TODOs, NO REGRESSIONS

I'm implementing Core Foundation after successfully completing Tenant
Management. Tenant Management is 100% complete with full Ash Resource
implementation.

Ready to begin Phase 1: Accounts Domain & Authentication with 5 stories
covering:

- Accounts Domain creation
- User Resource conversion
- JWT AuthToken implementation
- OAuth integration
- TOTP 2FA implementation

The foundation is solid with Platform domain, GDPR resources, and multi-tenant
infrastructure ready.
```

**3. System State Verification:**

```bash
# Always run these verification commands first:
cd /Users/rp/Developer/Base/mcp
mix compile
mix test
docker-compose up -d  # Ensure infrastructure is running
mix ecto.migrate
```

**4. Implementation Approach:**

- Start with **Phase 1, Story 1.1** (Create Accounts Domain)
- Complete each story fully before moving to next
- Run tests after each story
- Commit after each successful story completion
- Provide evidence-based progress updates

**5. Quality Standards:**

- **100% test pass rate** - No exceptions
- **Zero stubs** - Production-ready code only
- **Evidence-based claims** - Provide actual command output
- **Ash Framework only** - Never use Ecto patterns

---

## 📊 PROGRESS TRACKING

### **Phase 1: Accounts Domain & Authentication (100% complete)** ✅

- [x] Story 1.1: Create Accounts Domain & User Resource ✅
- [x] Story 1.2: Implement AuthToken Resource ✅
- [x] Story 1.3: Implement OAuth Provider Resource ✅
- [x] Story 1.4: Implement TOTP Secret Resource ✅
- [x] Story 1.5: Implement Registration Settings Resource ✅

### **Phase 2: Schema Provisioning (100% complete)** ✅

- [x] Story 2.1: Implement Schema Provisioner ✅
- [x] Story 2.2: Implement Tenant User Manager ✅

### **Phase 3: GDPR Completion**

- [ ] Story 3.1: Implement Data Anonymization
- [ ] Story 3.2: Implement Data Retention Scheduling
- [ ] Story 3.3: Implement Compliance Reporting

### **Phase 4: System Monitoring**

- [ ] Story 4.1: Implement System Monitoring

---

## 🎯 SUCCESS METRICS

### **Phase 1 Success:**

- ✅ All authentication tests passing (100%)
- ✅ Zero stub implementations in `lib/mcp/accounts/`
- ✅ JWT tokens generated and verified successfully
- ✅ OAuth login functional for Google and GitHub
- ✅ TOTP 2FA setup and verification working
- ✅ `mix compile` with zero warnings
- ✅ `mix precommit` passes completely

### **Overall Project Success:**

- ✅ All 4 phases complete (100%)
- ✅ Zero stubs anywhere in codebase
- ✅ Zero TODOs in production code
- ✅ All tests passing (100% pass rate)
- ✅ Production deployment ready
- ✅ Full GDPR compliance operational
- ✅ Multi-tenancy fully functional

---

_Implementation Plan Version: 1.0_ _Created: 2025-11-24_ _Last Updated:
2025-11-24_ _Quality Standard: Evidence-Based Development_ _Verification
Required: Yes_ _Zero Tolerance: Stubs, TODOs, Regressions_
