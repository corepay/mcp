# Underwriting System Reference

> **Single Source of Truth** - This document replaces all previous UW design docs.
> Last updated: 2026-01-01

## Overview

The Underwriting system handles merchant onboarding, risk assessment, and approval workflows. It supports AI-assisted application processing with a vendor-agnostic gateway pattern.

---

## Architecture

### Domain: `Mcp.Underwriting`

```
lib/mcp/underwriting/
├── adapter.ex              # Vendor behaviour contract
├── adapters/
│   ├── comply_cube.ex      # ComplyCube integration
│   ├── idenfy.ex           # Idenfy integration
│   └── mock.ex             # Testing adapter
├── gateway.ex              # Factory + orchestration facade
├── vendor_router.ex        # Smart routing logic
├── circuit_breaker.ex      # Resilience wrapper
├── risk_engine.ex          # Rule-based scoring
├── rules/
│   ├── kyb_rule.ex         # Business verification
│   ├── credit_score_rule.ex
│   └── document_verification_rule.ex
├── engine/
│   ├── orchestrator.ex     # Pipeline execution
│   ├── agent_runner.ex     # LLM agent execution
│   └── instruction_lookup.ex
├── resources/
│   ├── application.ex      # Core aggregate
│   ├── review.ex           # Decision records
│   ├── risk_assessment.ex  # Vendor results
│   ├── client.ex           # KYC subject
│   ├── document.ex         # Uploaded files
│   ├── activity.ex         # Audit log
│   ├── check.ex            # Vendor check results
│   ├── execution.ex        # Pipeline run
│   ├── pipeline.ex         # Stage configuration
│   ├── agent_blueprint.ex  # AI agent definitions
│   ├── instruction_set.ex  # Agent prompts
│   └── vendor_settings.ex  # Tenant vendor config
└── services/
    └── ...
```

### Key Patterns

**Gateway Pattern**: All vendor calls go through `Mcp.Underwriting.Gateway` which:
1. Routes to appropriate adapter via `VendorRouter`
2. Wraps calls with `CircuitBreaker` for resilience
3. Records results and updates application state

**Adapter Behaviour** (`Mcp.Underwriting.Adapter`):
```elixir
@callback verify_identity(applicant_data :: map(), context :: map()) :: {:ok, map()} | {:error, any()}
@callback screen_business(business_data :: map(), context :: map()) :: {:ok, map()} | {:error, any()}
@callback check_watchlist(name :: String.t(), context :: map()) :: {:ok, map()} | {:error, any()}
@callback document_check(document :: binary(), type :: atom(), context :: map()) :: {:ok, map()} | {:error, any()}
```

---

## Data Model

### Application States

```
draft → submitted → under_review → manual_review → approved
                                 ↘ rejected
                                 ↘ more_info_required
```

### Application Resource

| Field | Type | Description |
|-------|------|-------------|
| `subject_id` | UUID | Merchant/Individual ID |
| `subject_type` | atom | `:merchant`, `:individual`, `:property` |
| `status` | atom | Current workflow state |
| `application_data` | map | JSONB form responses |
| `risk_score` | integer | 0-100 calculated score |
| `submitted_at` | datetime | When submitted |
| `sla_due_at` | datetime | Review deadline |

### Risk Assessment

| Field | Type | Description |
|-------|------|-------------|
| `score` | integer | 0-100 |
| `factors` | map | KYB, documents, risk reasons |
| `recommendation` | atom | `:approve`, `:manual_review`, `:reject` |

---

## UI Components

### Tenant Portal (`/tenant/underwriting`)

| Route | LiveView | Status |
|-------|----------|--------|
| `/underwriting` | `UnderwritingLive` | ✅ Working - Queue list |
| `/underwriting/board` | `KanbanLive` | ✅ Working - Drag-drop board |
| `/underwriting/settings` | `SettingsLive` | ✅ Working - Config |
| `/underwriting/:id` | `ReviewLive` | ✅ Working - Application detail |

### OLA Portal (`/online-application`)

| Route | LiveView | Status |
|-------|----------|--------|
| `/` | `RegistrationLive` | ✅ Working - User registration |
| `/application` | `ApplicationLive` | ✅ Working - Multi-step form with chat |

### Reseller Portal (`/partners`)

| Route | LiveView | Status |
|-------|----------|--------|
| `/applications` | `ApplicationsLive` | ✅ Basic - List view |
| `/applications/:id` | `UnderwritingApplicationLive` | ✅ Basic - Detail view |

---

## Workflow: Application Screening

```
1. Application submitted
   ↓
2. Gateway.screen_application(application_id)
   ↓
3. KYB Check (screen_business)
   ↓
4. KYC Checks (verify_identity for each owner)
   ↓
5. Document Checks (document_check for uploads)
   ↓
6. RiskEngine.evaluate() → score + reasons
   ↓
7. Determine status:
   - score >= 90 → :approved
   - score < 50 → :rejected
   - else → :manual_review
   ↓
8. Activity logged, SLA calculated
```

---

## Risk Scoring

**Current Implementation**: Rule-based with pluggable rules

| Rule | Weight | Description |
|------|--------|-------------|
| KYB Rule | Variable | Business verification results |
| Credit Score Rule | Variable | Owner credit data |
| Document Verification | Variable | ID/doc validity |

**Scoring Logic**:
- Base score: 50
- Each rule adds/subtracts based on evaluation
- Clamped to 0-100

---

## Vendor Integrations

| Vendor | Adapter | Status |
|--------|---------|--------|
| ComplyCube | `adapters/comply_cube.ex` | ✅ Implemented |
| Idenfy | `adapters/idenfy.ex` | ✅ Implemented |
| Mock | `adapters/mock.ex` | ✅ For testing |

**Adding a new vendor**:
1. Create `adapters/new_vendor.ex` implementing `Adapter` behaviour
2. Add routing logic to `VendorRouter`
3. Configure in `VendorSettings` per tenant

---

## AI/Agent System

**Engine Components**:
- `AgentBlueprint`: Defines an AI agent's capabilities
- `InstructionSet`: Prompts/instructions for agents
- `Pipeline`: Ordered stages of agent execution
- `Execution`: A single pipeline run with context/results
- `AgentRunner`: Executes agents with LLM calls
- `Orchestrator`: Runs full pipeline, manages state

**Seeded Blueprints** (see `Mcp.Seeder`):
- Document Analyzer
- Risk Assessor
- Response Reviewer

---

## Gaps (Not Yet Implemented)

### High Priority

| Feature | Description |
|---------|-------------|
| **Atlas AI Concierge** | Contextual guidance during application |
| **Document Pre-Validation** | Check quality before submission |
| **ML Risk Models** | Replace rule-based with trained models |
| **Drip Campaigns** | Automated emails for stalled applications |

### Medium Priority

| Feature | Description |
|---------|-------------|
| **Magic Camera** | QR → phone camera → upload flow |
| **Save & Resume Links** | Email/SMS magic links |
| **Pizza Tracker** | Visual status timeline for applicants |
| **Deal Room** | Collaboration features (@mentions, notes) |
| **SLA Countdown UI** | Visual timer on cards |

### Future/Phase 2

| Feature | Description |
|---------|-------------|
| **PAYFAC Platform** | Sub-merchant management |
| **Best Offer Screen** | Payfac ↔ Retail bridge |
| **Graph RAG** | Relationship-based risk analysis |
| **The Eye Integration** | Document vision service |

---

## Configuration

### Tenant Settings

Each tenant can configure:
- Preferred vendor (`VendorSettings`)
- Auto-approve threshold
- SLA hours
- Required documents
- Agent instruction overrides

### Environment

```elixir
# Vendor API keys (in runtime config)
config :mcp, :underwriting,
  complycube_api_key: System.get_env("COMPLYCUBE_API_KEY"),
  idenfy_api_key: System.get_env("IDENFY_API_KEY")
```

---

## Testing

```bash
# Run UW tests
mix test test/mcp/underwriting/

# Key test files
test/mcp/underwriting/gateway_test.exs
test/mcp/underwriting/risk_engine_test.exs
test/mcp_web/live/tenant/underwriting_live_test.exs
```

---

## Related Documentation

- `docs/guides/multi-tenancy/` - Schema isolation
- `docs/guides/security/` - Data protection
- `CLAUDE.md` - Development guidelines

---

*This document is the authoritative reference for the Underwriting system. Old design docs have been archived to `docs/archive/underwriting-design/`.*
