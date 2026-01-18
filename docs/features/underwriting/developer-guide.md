# Developer Guide: Sovereign Underwriting Engine

## 🏗️ Architectural Philosophy

The engine is built on the principle of **"Exception as a First-Class Entity."** Instead of straight-through processing which masks risk, we use an asymmetric model where "Clean" deals are automated, and "Amber" deals trigger deep cognitive dives.

### Module Topology

```
lib/mcp/underwriting/
├── gateway.ex              # Unified screening & risk entry
├── vendor_router.ex        # Multivendor KYC/KYB & AML orchestration
├── atlas/
│   ├── agent.ex            # The "Atlas" Cognitive Core (Onboarding Concierge)
│   └── context_hints.ex    # Graph-aware context harvesting
├── engine/
│   ├── orchestrator.ex     # Stage management (Document -> KYB -> Risk)
│   └── agent_runner.ex     # LLM integration & Vision processing
├── services/
│   ├── placement_intelligence.ex  # Profit-Aware Router
│   └── boarding_service.ex        # MID/TID Automation
└── resources/
    ├── playbook.ex         # Human-authored Markdown rules
    ├── risk_assessment.ex  # SHA-256 Attribution & Evidence
    └── boarding.ex         # Transactional lineage
```

## 🤵 The Atlas Concierge (Intelligent Intake)

Atlas is a proactive agent that lives in the frontend (LiveView) but is governed by the backend `Atlas.Agent` module.

### Interaction Workflow
1. **Behavior Monitoring**: The frontend sends "idle" or "focus" events to the backend.
2. **Context Enrichment**: `Atlas.Agent` fetches the `ConversationContext` (missing fields, current step, form data).
3. **Response Generation**: The agent generates a `proactive_help`, `suggestion`, or `encouragement` response via the `AgentRunner`.
4. **Resilience**: If the LLM is down, `Atlas` falls back to a deterministic pattern-matching system to ensure the user is never left without help.

## 🧠 Cognitive Logic: Playbooks & Lineage

### The Playbook Pattern
Playbooks replace hardcoded Elixir logic with Markdown-indexed rules. This allows underwriters to update policy without code changes.

```elixir
# lib/mcp/underwriting/resources/playbook.ex
attribute :rules_markdown, :string # "Reject if business type is 'crypto'..."
attribute :hash, :string           # SHA-256 fingerprint
```

### Immutable Decision Lineage
When a `RiskAssessment` is created, it captures the `hash` of the active `Playbook`. This ensures that even if a policy changes 6 months later, the platform can prove exactly which rules were in effect at the time of the decision.

## 👁️ Multimodal Forensics: "The Eye"

"The Eye" is our vision-processing agent integrated into the `AgentRunner`. It is triggered during the **Amber Zone** phase.

- **Capabilities**: Analyzes storefront imagery, identity document holographic integrity, and "vibe" consistency.
- **Implementation**: Uses `image_url` context in the Agent pipeline, processed via multimodal LLMs (Ollama/OpenRouter).

## 💰 Profit-Aware Routing (Placement Intelligence)

Matches applications to bank profiles with sub-5ms matching across 500+ profiles. Verified via `test/mcp/underwriting/performance_test.exs`.

### Scoring & Matching Pattern
1. **Regional Filtering**: Filters processors based on `supported_regions`.
2. **Appetite Validation**: Validates `appetite_rules` (Min Score, Industries, Max Volume).
3. **Yield Optimization**: Prefers profiles with the highest margin (`risk_weight` proximity).

## 🌉 Boarding Service & Resilience

### Circuit Breaker Standardization
All external adapters (QorPay, ComplyCube, Idenfy) are wrapped in `Utils.CircuitBreaker`.
- **Threshold**: 5 consecutive failures opens the circuit.
- **Automatic Recovery**: Retries after 60 seconds.

### Async Status Polling
Boarding uses an Oban-powered worker to poll for MID activation, ensuring high-frequency status updates without blocking.

## 🧪 Testing Strategy: The Steel Thread

We use a "Steel Thread" integration suite (`test/mcp/underwriting/steel_thread_test.exs`) that bypasses non-critical mocks to test the **actual** Ash resources and Service interactions.

### Key Verification points:
1. **Multitenancy**: Ensuring cross-tenant isolation.
2. **Atomic Integrity**: `Application.status` transitions from `:submitted` -> `:under_review` -> `:funded`.
3. **Lineage Consistency**: Verification that `RiskAssessment.policy_hash` matches the active `Playbook`.
