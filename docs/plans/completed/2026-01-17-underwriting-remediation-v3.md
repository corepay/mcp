# Underwriting Remediation & Innovation Plan v3.0

> **Mission:** Transform Underwriting into a Cognitive Decision Platform through Human-Architected Playbooks and Autonomous Agentic Negotiation.

**Version:** 3.0 (The Sovereign Agent Release)
**Status:** ACTIVE
**Revised Policy:** All tasks must be logged in `UNDERWRITING_TASK_BOARD.md`.

---

## 🏗️ Sprint 1: Critical Stability & Infrastructure (The Base)
*Focus: Resolving Audit CRIT/HIGH findings and enforcing multitenancy.*

### Task UW-01: Synchronous CircuitBreaker Reset
- **Problem**: `Utils.CircuitBreaker.reset/1` is `cast` (async), causing test race conditions.
- **Solution**: Change to `handle_call` for synchronous state wiping.
- **Files**: `lib/mcp/utils/circuit_breaker.ex`

### Task UW-02: Router & Gateway Migration
- **Problem**: Runtime errors due to `Mcp.Underwriting.CircuitBreaker` usage.
- **Solution**: Point `VendorRouter` and `Gateway` to `Mcp.Utils.CircuitBreaker`.
- **Constraint**: Must use `open?/1` (boolean) instead of `:ok` atoms.

### Task UW-03: Duplicate Cleanup
- **Action**: Delete `lib/mcp/underwriting/circuit_breaker.ex`. 

### Task UW-04: Enforced Multitenancy (DocumentAnalysis)
- **Problem**: Data leakage risk in `DocumentAnalysis`.
- **Solution**: Relocate to `resources/`, add `strategy :context`, and update the Underwriting domain registry.

### Task UW-05: Record Check & Webhook Tokens
- **Problem**: Missing audit trail for KYB.
- **Solution**: Implement `record_kyb_check/3`. Add `webhook_token` to `VendorSettings` for secure tenant routing.

---

## 🧠 Sprint 2: High Priority & Refinement (The Brain)
*Focus: Implementing the logic for Sovereign Authority and Playbooks.*

### Task UW-07: Tenant-Aware SLA Calculator
- **Action**: Fetch SLA hours from `VendorSettings` instead of hardcoded 4 hours.

### Task UW-08: Configurable Risk Thresholds
- **Action**: Implement `determine_status(score, opts)` in `Gateway`.

### Task UW-10: Idenfy Watchlist Integration
- **Action**: Fully implement `check_watchlist` to call the Idenfy API (AML screening).

---

## 🧪 Sprint 3 & 4: The Innovation Layer (Intelligence & Forensics)
*Focus: Playbooks, The Eye, and the Deal Room.*

### Task UW-11: Playbook Resource
- **Schema**: `id`, `name`, `industry`, `rules_markdown`, `thresholds` (map).

### Task UW-12: Playbook Concierge (The Architect)
- **Agent**: Specialized LLM tool to help underwriters write consistent Markdown rules with web-search capabilities for risk intelligence.

### Task UW-13: "The Eye" Multimodal Forensics
- **Implementation**: Integrate vision-processing for storefront and document "vibe" analysis. Triggered via Atlas in the Amber Zone.

### Task UW-14: Asymmetric Deal Room
- **Merchant UX**: Atlas-led "Healing" chat + Task Ledger.
- **Underwriter UX**: Sovereign Brief (Recommendation backed by Evidence Vault).

---

## 💰 Sprint 5: Yield & Boarding (The Business)
*Focus: Processor Optimization.*

### Task UW-17: Profit-Aware Router
- **Logic**: Selects processors based on a balance of Yield (Margin) vs. Time-to-Board (Speed).

---

## 📒 Success Metrics
- 95% Automated/Negotiated Resolution.
- < 15min Time-to-Approval for "Clean" deals.
- 10% EBITDA increase via Processor Placement.
