# 🛡️ CORE AUDIT & REMEDIATION PLAN

**Date:** 2025-11-25 **Status:** DRAFT **Target:** Core Foundation Remediation

## 🚨 EXECUTIVE SUMMARY

A comprehensive audit of the `Mcp` Core Foundation has revealed a critical
discrepancy between the reported status ("100% Complete") and the actual
codebase state. While the architectural structure (Ash Resources, Domains) is in
place, the implementation logic for critical paths—specifically Authentication,
Registration, and GDPR Retention—relies heavily on **stubs** and **TODOs**.

**Current Risk Level:** 🔴 **CRITICAL**

- **Security Risk:** Authentication functions return static/stubbed responses.
- **Compliance Risk:** GDPR retention scheduling and cleanup are not
  operational.
- **Stability Risk:** Oban workers are misconfigured or point to non-existent
  logic.

This document outlines the **Remediation Plan** to convert these stubs into
production-ready, testable code, strictly adhering to the "Zero Stubs" policy.

---

## 🔍 DETAILED AUDIT FINDINGS

### 1. Identity & Access Management (Critical)

| Component           | File                                           | Issue                                                                                                            | Severity    |
| ------------------- | ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ----------- |
| **Auth Context**    | `lib/mcp/accounts/auth.ex`                     | All functions (`authenticate`, `create_user_session`, etc.) are stubs returning static `{:error, ...}` or `:ok`. | 🔴 Critical |
| **JWT Service**     | `lib/mcp/accounts/jwt.ex`                      | Contains `raise` placeholders. No actual token generation or verification logic using `Joken`.                   | 🔴 Critical |
| **Registration**    | `lib/mcp/registration/registration_service.ex` | Stubs for user creation and tenant linking. No actual persistence or email triggers.                             | 🔴 Critical |
| **Accounts Domain** | `lib/mcp/domains/accounts.ex`                  | File exists but is effectively empty (missing resource definitions for `User`, `AuthToken`, etc.).               | 🔴 Critical |
| **OAuth**           | `lib/mcp/accounts/oauth.ex`                    | Unsafe error handling (`raise` on missing email) and potential stubbed flow.                                     | 🟡 Medium   |

### 2. GDPR & Data Lifecycle (High)

| Component             | File                                             | Issue                                                                                     | Severity  |
| --------------------- | ------------------------------------------------ | ----------------------------------------------------------------------------------------- | --------- |
| **Data Retention**    | `lib/mcp/gdpr/data_retention.ex`                 | Logic for scheduling and legal holds is missing (marked with TODOs).                      | 🔴 High   |
| **Retention Worker**  | `lib/mcp/jobs/gdpr/retention_cleanup_worker.ex`  | Worker does not trigger the `RetentionReactor`. Logic is commented out or stubbed.        | 🔴 High   |
| **Retention Reactor** | `lib/mcp/gdpr/retention_reactor.ex`              | Missing integration with `AuditTrail`. Deletions are not being logged.                    | 🔴 High   |
| **Oban Config**       | `config/config.exs`                              | Cron jobs schedule `ComplianceWorker` twice; `RetentionCleanupWorker` is never scheduled. | 🔴 High   |
| **User Deletion**     | `lib/mcp/gdpr/reactors/user_deletion_reactor.ex` | No logic to cancel pending Oban jobs when a user is deleted.                              | 🟠 Medium |

### 3. Operational & Compliance (Medium)

| Component         | File                             | Issue                                                                              | Severity  |
| ----------------- | -------------------------------- | ---------------------------------------------------------------------------------- | --------- |
| **Compliance**    | `lib/mcp/gdpr/compliance.ex`     | Reporting generation is stubbed.                                                   | 🟠 Medium |
| **Session Store** | `lib/mcp/cache/session_store.ex` | Cross-tenant session limits are disabled (`@max_sessions_per_user` commented out). | 🟡 Low    |

---

## 🛠️ PHASED REMEDIATION PLAN

### PHASE 1: Identity & Security Hardening (Immediate Priority)

**Goal:** Replace all Auth/Account stubs with working Ash/Elixir code.

1. **Fix Accounts Domain Definition**
   - Update `lib/mcp/domains/accounts.ex` to properly register `User`,
     `AuthToken`, `OAuthProvider`, `TotpSecret`, and `RegistrationSettings`
     resources.
2. **Implement JWT Service (`Mcp.Accounts.JWT`)**
   - Implement `generate_token/2` using `Joken`.
   - Implement `verify_token/2`.
   - Implement `refresh_token/2` with sliding window logic.
3. **Implement Auth Context (`Mcp.Accounts.Auth`)**
   - Replace `authenticate/3` with real `Ash.Query` against `User` resource +
     Bcrypt verification.
   - Replace `create_user_session/2` to use `AuthToken` resource.
   - Implement `revoke_session` logic.
4. **Implement Registration Service (`Mcp.Registration.RegistrationService`)**
   - Wire up `register_user` to `Mcp.Accounts.User.create`.
   - Implement tenant association logic.
5. **Verification**
   - Add comprehensive tests in `test/mcp/accounts/`.
   - Ensure `mix test` passes with **zero skips** for these modules.

### PHASE 2: GDPR & Data Integrity (High Priority)

**Goal:** Operationalize the Data Retention and Cleanup pipelines.

1. **Implement Data Retention Logic (`Mcp.Gdpr.DataRetention`)**
   - Implement `get_retention_schedule/1`.
   - Implement `check_legal_holds/1`.
2. **Fix Retention Worker & Reactor**
   - Update `Mcp.Jobs.Gdpr.RetentionCleanupWorker` to query overdue data and
     trigger the Reactor.
   - Update `Mcp.Gdpr.RetentionReactor` to create `AuditTrail` entries upon
     deletion.
3. **Correct Oban Configuration**
   - Update `config/config.exs` to schedule `RetentionCleanupWorker` correctly.
4. **Verification**
   - Test the full pipeline: Create data -> Fast forward time -> Run Worker ->
     Verify Deletion & Audit Log.

### PHASE 3: Compliance & Polish (Medium Priority)

**Goal:** Complete reporting and clean up technical debt.

1. **Implement Compliance Reporting**
   - Flesh out `Mcp.Gdpr.Compliance.generate_report/1`.
2. **User Deletion Safety**
   - Add Oban job cancellation to `UserDeletionReactor`.
3. **Code Cleanup**
   - Remove all `# TODO` comments.
   - Enable `credo` strict checks.

---

## 📉 SUCCESS METRICS

- **Zero Stubs:** No function in `lib/mcp/accounts/` or `lib/mcp/gdpr/` returns
  a hardcoded static value.
- **100% Test Coverage:** All new implementations have corresponding unit tests.
- **Working Auth:** Can register, login, get JWT, and refresh token via actual
  API calls.
- **Working GDPR:** Expired data is automatically deleted and audited by the
  background worker.

## 📝 NEXT STEPS

1. **Approve this plan.**
2. **Begin Phase 1** immediately, starting with `Mcp.Domains.Accounts` and
   `Mcp.Accounts.JWT`.
