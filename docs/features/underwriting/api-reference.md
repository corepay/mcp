# API Reference: Sovereign Underwriting Engine

## 🤵 Merchant Atlas Concierge API

The `Atlas.Agent` provides proactive guidance and "healing" capabilities for merchant applications.

### generate_response/2

Generates a contextual response based on the user's current step and message.

```elixir
Mcp.Underwriting.Atlas.Agent.generate_response(user_message, context)
```

**Response Types**:

- `:proactive_help` - Unsolicited assistance (e.g., when a user is idle).
- `:answer` - Direct response to a merchant's question.
- `:suggestion` - Advice on improving an entry (e.g., "Business Description too short").
- `:encouragement` - Positive feedback on application progress.

---

## 🧠 Intelligence Factory APIs

### Atlas Analysis Reactor (`AnalyzeApplication`)

The primary engine for autonomous triage and forensic signal classification.

| Action   | Input                     | Description                                                                                           |
| -------- | ------------------------- | ----------------------------------------------------------------------------------------------------- |
| `run`    | `application_id`, `actor` | Orchestrates the four-phase cognitive pipeline: Harvesting -> Triage -> Classification -> Assessment. |
| `status` | `application_id`          | Returns the current progress of the intelligence scan.                                                |

**Signal Classification**:
Signals extracted during scan are categorized into:

- `ENTITY`: Business registration, tax ID, and SOS standing.
- `FINANCIAL`: Transaction patterns, average ticket, and liquidity exposure.
- `REPUTATION`: Web footprint, ratings, and social legitimacy.
- `IDENTITY`: Beneficial owner KYC and sanctions screening.

### Playbooks

The `Playbook` resource governs the AI's logic for a specific industry or risk tier.

| Action   | Parameters                                         | Description                                                     |
| -------- | -------------------------------------------------- | --------------------------------------------------------------- |
| `create` | `name`, `industry`, `rules_markdown`, `thresholds` | Creates a new policy version with auto-calculated SHA-256 hash. |
| `active` | N/A                                                | Returns all active playbooks for the current tenant.            |

### Risk Assessment (SHA-256 Lineage)

Risk assessments are the terminal output of the cognitive pipeline.

| Attribute        | Type      | Description                                                     |
| ---------------- | --------- | --------------------------------------------------------------- |
| `score`          | `integer` | 0-100 (Safe to High-Risk).                                      |
| `recommendation` | `atom`    | `:approve`, `:reject`, `:manual_review`.                        |
| `policy_hash`    | `string`  | The SHA-256 fingerprint of the `Playbook` used.                 |
| `evidence_vault` | `map`     | Links to document IDs and agent summaries supporting the score. |

---

## 💰 Routing & Boarding APIs

### Placement Intelligence

Matches an approved application to the optimal processor.

#### suggest_placement/3

```elixir
PlacementIntelligence.suggest_placement(app_id, assessment_id, tenant_schema)
```

- **Returns**: `{:ok, %{profile: BankProfile, rationale: String.t()}}`
- **Error**: `{:error, :no_eligible_banks}`

### Boarding Service

Asynchronous activation of processor accounts.

#### board/4

```elixir
BoardingService.board(app_id, profile_id, tenant_schema, opts)
```

- **Options**:
  - `:rationale` (Required) - String matching logic.
  - `:actor` (Optional) - User ID or System PID.
- **Workflow**: Transitions `Boarding` status through `:pending` -> `:active`.

---

## 🏛️ Ash Resources (Extended)

### Boarding

- `mid` / `tid`: Merchant & Terminal IDs (assigned post-activation).
- `status`: `:pending`, `:active`, `:failed`.
- `rationale`: Persisted matching logic from PlacementIntelligence.
- `error_metadata`: Captured API fail-reasons for forensic review.

### BankProfile

- `risk_weight`: Target score proximity for yield optimization.
- `appetite_rules`:
  - `allowed_industries`: list
  - `min_score`: integer
  - `max_volume`: integer (per month)

### VendorSettings (Tenant Config)

- `sla_hours`: Dynamic threshold for "Overdue" status calculations.
- `auto_approve_threshold`: Score required to bypass human review.
- `webhook_token`: Secure identifier for processor callback routing.

---

## 🛑 Error Identification System

The engine uses a tiered error system for precision troubleshooting.

| Code                | Layer        | Description                                                 |
| ------------------- | ------------ | ----------------------------------------------------------- |
| `circuit_open`      | Network      | External vendor is down; failover active.                   |
| `no_eligible_banks` | Logic        | Application does not meet any profile's appetite or region. |
| `policy_mismatch`   | Security     | Application subject_type does not match Playbook scope.     |
| `kyc_failed`        | Verification | Physical identity verification unsuccessful.                |
| `kyb_failed`        | Verification | Business registration or EIN lookup failed.                 |
