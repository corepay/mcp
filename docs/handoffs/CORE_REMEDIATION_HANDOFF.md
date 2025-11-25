# 🎯 CORE REMEDIATION HANDOFF

## 🚨 CRITICAL AGENT REQUIREMENTS

### **📖 MANDATORY READING BEFORE ANY CODING:**

1. **CLAUDE.md** - ✅ **ALWAYS READ FIRST** - Primary project guidelines,
   architecture, agent requirements
2. **AGENTS.md** - Phoenix/LiveView/Elixir/Ash Framework specific patterns and
   technology stack
3. **This Handoff** - Specific implementation context and current state

### **⚠️ ARCHITECTURE COMPLIANCE REQUIRED:**

- ✅ Ash Framework only (NEVER use Ecto patterns)
- ✅ Component-driven UI with DaisyUI (NEVER dashboard LiveViews)
- ✅ Evidence-based development (NEVER estimates or "I think")
- ✅ Follow project-specific technology stack exactly

---

## 🚀 CURRENT IMPLEMENTATION STATUS

**✅ Overall Completion: 40% COMPLETE** (Downgraded from 50% due to stub
discovery)

### **Successfully Delivered:**

- [x] **Tenant Management** ✅ - Full Ash Resource implementation
- [x] **Multi-Tenant Infrastructure** ✅ - Schema switching operational
- [x] **Database Schema** ✅ - 19 migrations applied

### **Partially Complete:**

- [ ] **Accounts Domain** 🔄 (10% - Domain exists but resources are
      missing/stubbed)
- [ ] **GDPR Compliance** 🔄 (20% - Resources exist but logic is stubbed/TODO)

### **Not Started:**

- [ ] **Authentication Logic** ❌ (Currently 100% stubs)
- [ ] **Retention Scheduling** ❌ (Currently 100% TODOs)
- [ ] **Compliance Reporting** ❌

---

## 🛠️ CURRENT SYSTEM STATE

### **✅ Working Components:**

- **Phoenix Server**: Compiles and starts
- **Database**: PostgreSQL with platform schema
- **Tenant Resource**: `Mcp.Platform.Tenant` (CRUD works)

### **🎯 Architecture Ready:**

- **Ash Framework**: Configured and running
- **Oban**: Configured (but needs worker fix)
- **Domains**: `Mcp.Platform`, `Mcp.Accounts` (shell), `Mcp.Domains.Gdpr`

### **🔧 Key Files for Next Phase:**

- **`lib/mcp/domains/accounts.ex`**: Needs full resource definition
- **`lib/mcp/accounts/jwt.ex`**: Needs Joken implementation
- **`lib/mcp/accounts/auth.ex`**: Needs Ash Query implementation
- **`lib/mcp/gdpr/data_retention.ex`**: Needs scheduling logic

---

## 📋 NEXT IMPLEMENTATION OBJECTIVES

### **Business Objectives:**

Eliminate all "fake" code (stubs) in the Authentication and GDPR modules to
ensure the system is actually secure and compliant, rather than just looking
like it is.

### **Key Implementation Stories:**

**Story 1.1: Hardening Accounts Domain**

- Define `User`, `AuthToken`, `OAuthProvider`, `TotpSecret` in
  `Mcp.Domains.Accounts`
- Ensure all resources are properly registered in `config.exs`

**Story 1.2: Real Authentication Implementation**

- Implement `Mcp.Accounts.JWT` with `Joken` (generate/verify/refresh)
- Replace `Mcp.Accounts.Auth` stubs with real Ash queries
- Implement `Mcp.Registration.RegistrationService` with real persistence

**Story 2.1: GDPR Retention Pipeline**

- Implement `Mcp.Gdpr.DataRetention` scheduling logic
- Wire `RetentionCleanupWorker` to `RetentionReactor`
- Ensure `AuditTrail` is updated on deletion

---

## ✅ QUALITY VERIFICATION EVIDENCE

### **Compilation Status:**

```
mix compile
# Generated mcp app
# Exit code: 0
```

### **Test Results:**

```
mix test
# == Compilation error in file test/mcp/cache/multi_tenant_performance_test.exs ==
# ** (ArgumentError) module Mcp.Cache.CacheManager is not a behaviour
# Exit code: 1
```

_Note: Tests are currently failing due to a mock definition error in
`multi_tenant_performance_test.exs`._

### **Database State:**

```
mix ecto.migrate
# 05:15:42.496 [info] Migrations already up
```

---

## ⚠️ TECHNICAL DEBT & KNOWN ISSUES

### **High Priority:**

- **Authentication Stubs**: `Mcp.Accounts.Auth` returns static `{:error, ...}`.
  - _Impact_: No users can actually log in.
  - _Fix_: Implement Phase 1 of Remediation Plan.
- **Test Suite Broken**: `multi_tenant_performance_test.exs` fails to compile.
  - _Impact_: Cannot verify new changes reliably.
  - _Fix_: Fix mock behaviour definition or skip test temporarily.

### **Medium Priority:**

- **Oban Misconfiguration**: `config.exs` schedules `ComplianceWorker` twice.
  - _Impact_: Retention cleanup never runs.
  - _Fix_: Update config to schedule `RetentionCleanupWorker`.

---

## 🔧 ENVIRONMENT & DEPENDENCIES

### **Development Environment:**

- **Elixir Version**: 1.17+
- **Phoenix Version**: 1.7+
- **Database**: PostgreSQL 15
- **Cache**: Redis

### **Key Dependencies:**

- **ash**: ~> 3.0
- **ash_authentication**: ~> 4.0
- **joken**: ~> 2.6

---

## 🎪 COLLABORATIVE AGENT ACTIVATION

### **For New AI Agent Session:**

**1. Mandatory Reading:**

- **CLAUDE.md**
- **AGENTS.md**
- **This Handoff**

**2. Context Loading:**

```markdown
I've read CLAUDE.md and AGENTS.md. I understand the goal is to REMEDIATE the
Core Foundation by replacing stubs with real code. I will start by fixing the
`Mcp.Domains.Accounts` definition and then implementing `Mcp.Accounts.JWT`.
```

**3. System State Verification:**

```bash
mix compile
mix test  # Expect failure in multi_tenant_performance_test.exs
mix ecto.migrate
```
