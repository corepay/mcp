# Underwriting Production Readiness Plan

This plan outlines the hardening steps required to transition the Underwriting and Boarding infrastructure from "Functional Implementation" to "Full Production Readiness."

## 🎯 Objectives
*   **Security**: Implement strict Ash Policies for all new resources.
*   **Resilience**: Establish robust error handling and failure states for external API integrations.
*   **Observability**: Create an immutable decision audit log for placement intelligence.
*   **Quality**: 100% test coverage for the "Steel Thread" (Submission to Funding).

## 📊 Deployment Roadmap

### Phase 1: Security & Policy Hardening (P0)
- [X] **PR-01**: Implement `Ash.Policy.Authorizer` on `Processor`, `BankProfile`, and `Boarding`.
- [X] **PR-02**: Enforce Platform Admin vs. Tenant User permissions (Tenants read-only for Banks, Private for Boardings).
- [X] **PR-03**: Audit Cross-Tenant data leaks in `PlacementIntelligence`.

### Phase 2: Resilience & Error Handling (P1)
- [X] **PR-04**: Implement async boarding status polling (for processors that aren't synchronous).
- [X] **PR-05**: Robust failure handling in `BoardingService` (transition to `:failed` status with error metadata).
- [X] **PR-06**: Circuit breaker pattern for the `QorPayBoarding` adapter.

### Phase 3: Observability & Rationale Log (DONE)
- [x] **PR-07**: Add `rationale` field to `Boarding` resource.
- [x] **PR-08**: Persist the `MatchingResult` rationale from `PlacementIntelligence`.
- [x] **PR-09**: Implement Audit Log UI for boarding history (Side Drawer & Lineage).

### Phase 4: Zero Defects & Steel Thread (DONE)
- [X] **PR-10**: Create `test/mcp/underwriting/steel_thread_test.exs` (E2E flow).
- [x] **PR-11**: Full `credo` and `dialyzer` sweep on Underwriting domain.
- [x] **PR-12**: Performance profiling on appetite matching logic (ensure <50ms for large bank profiles).

## 🛠️ Task Board

| Task ID | Description | Status | Priority |
| :--- | :--- | :--- | :--- |
| **PR-01** | Secure Boarding/Bank resources with Ash Policies | DONE | HIGH |
| **PR-05** | Implement `:failed` state & Error Metadata | DONE | HIGH |
| **PR-07** | Decision Rationale Persistence | DONE | MED |
| **PR-04** | Async Boarding Polling Infrastructure | DONE | HIGH |
| **PR-06** | Circuit Breaker Pattern for Adapters | DONE | HIGH |
| **PR-10** | E2E Steel Thread Integration Test | DONE | HIGH |

---
*Created: 2026-01-17*
*Owner: Antigravity*
