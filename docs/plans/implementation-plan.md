# Implementation Plan - Phase 1 Gap Closure

**Generated:** 2026-01-01
**Sources:** domain_brief.md, phase_1_epics.md, todo_elimination.md, code analysis
**Status Tracking:** docs/sprint-artifacts/sprint-status.yaml

---

## Executive Summary

| Category | Total | Done | In Progress | TODO |
|----------|-------|------|-------------|------|
| Phase 1 Stories | 109 | 48 | 12 | 49 |
| TODO Items | 13 | 12 | 1 | 0 |
| Domain Requirements | 22 | 15 | 4 | 3 |

**Overall Implementation:** ~55% complete

---

## Priority 1: Critical Path (Must Complete First)

These items block other work or are security-critical:

### 1.1 OAuth Authentication (Story 2.4)
**Gap:** OAuth module exists but not wired to AshAuthentication strategies
**Effort:** 2 days
**Files:**
- `lib/mcp/accounts/oauth.ex` - Exists
- `lib/mcp/accounts/user.ex` - Add strategies
- `config/runtime.exs` - Add OAuth config

**Implementation:**
```elixir
# In lib/mcp/accounts/user.ex, add to authentication block:
authentication do
  strategies do
    password :password do
      # existing password strategy
    end

    oauth2 :google do
      client_id Application.get_env(:mcp, :google_client_id)
      client_secret Application.get_env(:mcp, :google_client_secret)
      redirect_uri "https://platform.base.do/auth/google/callback"
      authorize_url "https://accounts.google.com/o/oauth2/v2/auth"
      token_url "https://oauth2.googleapis.com/token"
      user_info_url "https://www.googleapis.com/oauth2/v3/userinfo"
    end

    oauth2 :github do
      client_id Application.get_env(:mcp, :github_client_id)
      client_secret Application.get_env(:mcp, :github_client_secret)
      redirect_uri "https://platform.base.do/auth/github/callback"
      authorize_url "https://github.com/login/oauth/authorize"
      token_url "https://github.com/login/oauth/access_token"
      user_info_url "https://api.github.com/user"
    end
  end
end
```

### 1.2 API Authentication Plug (Story 10.7)
**Gap:** No plug to authenticate API requests via API-Key header
**Effort:** 2 days
**Files:**
- `lib/mcp_web/plugs/api_auth_plug.ex` - Create
- `lib/mcp_web/router.ex` - Add to API pipeline

**Implementation:**
```elixir
defmodule McpWeb.Plugs.ApiAuthPlug do
  import Plug.Conn
  alias Mcp.Platform.ApiKey

  def init(opts), do: opts

  def call(conn, _opts) do
    with [key] <- get_req_header(conn, "api-key"),
         {:ok, api_key} <- validate_key(key),
         :ok <- check_expiration(api_key) do
      conn
      |> assign(:api_key, api_key)
      |> assign(:api_actor, load_entity(api_key))
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{code: "invalid_api_key", message: "Invalid or missing API key"}})
        |> halt()
    end
  end
end
```

### 1.3 Remaining TODO: Instruction Set Lookup (TODO-7)
**Gap:** Only remaining TODO in codebase at `orchestrator.ex:35`
**Effort:** 0.5 days
**File:** `lib/mcp/underwriting/engine/orchestrator.ex`

**Implementation:** See todo_elimination.md Section 7 for complete code

---

## Priority 2: Core UX Features (This Sprint)

### 2.1 Context Switching (Stories 4.4, 4.5, 4.6)
**Gap:** Context switch flow incomplete, no Discovery portal
**Effort:** 3 days
**Files:**
- `lib/mcp/accounts/context_switch_reactor.ex` - Create
- `lib/mcp_web/live/discovery_live/index.ex` - Create
- `lib/mcp_web/components/context_switcher.ex` - Create

### 2.2 Branding Cascade (Story 8.11)
**Gap:** Branding not cascading platform → tenant → merchant → store
**Effort:** 1 day
**Files:**
- `lib/mcp_web/branding.ex` - Create resolver
- `lib/mcp_web/plugs/context_plug.ex` - Integrate branding

### 2.3 Customer/Vendor Self-Registration (Story 2.9)
**Gap:** Need merchant settings flags for self-registration
**Effort:** 2 days
**Files:**
- `lib/mcp/platform/merchant.ex` - Add settings fields
- `lib/mcp_web/live/auth_live/register.ex` - Conditional display

**Migration:**
```elixir
alter table(:merchants) do
  add :settings, :jsonb, default: "{}"
end

# Default settings structure:
# %{
#   customer_self_registration: false,
#   vendor_self_registration: false
# }
```

---

## Priority 3: Missing Shared Entities (Epic 9 Gaps)

### 3.1 Socials Resource (Story 9.4)
**Gap:** No Social resource for social media links
**Effort:** 0.5 days

```elixir
# lib/mcp/platform/social.ex
defmodule Mcp.Platform.Social do
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :owner_type, :string, allow_nil?: false
    attribute :owner_id, :uuid, allow_nil?: false
    attribute :platform, :string, allow_nil?: false  # twitter, linkedin, etc
    attribute :handle, :string
    attribute :url, :string
    timestamps()
  end
end
```

### 3.2 Images Resource (Story 9.5)
**Gap:** No Image resource with MinIO storage
**Effort:** 1 day

### 3.3 Documents Resource (Story 9.6)
**Gap:** No Document resource with encrypted storage
**Effort:** 1.5 days

### 3.4 Todos Resource (Story 9.7)
**Gap:** No Todo resource with assignment
**Effort:** 0.5 days

### 3.5 Notes Resource (Story 9.8)
**Gap:** No Note resource with Meilisearch
**Effort:** 1 day

---

## Priority 4: Field-Level Policies (Epic 6 Gap)

### 4.1 Reseller Data Visibility (Story 6.6)
**Gap:** Resellers can see all merchant data, should only see payment data
**Effort:** 1 day
**Files:**
- `lib/mcp/platform/merchant.ex` - Add field policies

```elixir
field_policies do
  # Payment data - visible to resellers
  field_policy [:id, :name, :slug, :status, :payment_volume, :mids] do
    authorize_if always()
  end

  # Business data - hidden from resellers
  field_policy [:customers, :products, :pricing, :settings] do
    forbid_if actor_attribute_equals(:role, :reseller)
    authorize_if always()
  end
end
```

---

## Priority 5: UI Components (Management UIs)

### 5.1 Team Management UI (Story 6.8)
**Gap:** No LiveView for team CRUD
**Effort:** 2 days
**Path:** `lib/mcp_web/live/teams_live/`

### 5.2 Invitation Management UI (Story 7.8)
**Gap:** No LiveView for invitation management
**Effort:** 1.5 days
**Path:** `lib/mcp_web/live/invitations_live/`

### 5.3 API Key Management UI (Story 10.6)
**Gap:** No LiveView for API key management
**Effort:** 1.5 days
**Path:** `lib/mcp_web/live/api_keys_live/`

### 5.4 Custom Domain Management UI (Story 11.9)
**Gap:** No LiveView for domain management
**Effort:** 1 day
**Path:** `lib/mcp_web/live/settings_live/custom_domains.ex`

---

## Priority 6: Custom Domains & SSL (Epic 11 Gaps)

### 6.1 DNS Verification (Stories 11.2, 11.3)
**Gap:** No DNS challenge generation or verification
**Effort:** 2 days

### 6.2 SSL Provisioning (Stories 11.4, 11.5, 11.6)
**Gap:** No ACME integration for Let's Encrypt
**Effort:** 3 days
**Dependencies:** DNS verification must work first

### 6.3 CustomDomainPlug (Story 11.8)
**Gap:** No plug to resolve custom domains
**Effort:** 0.5 days

---

## Priority 7: Test Coverage (All Epics)

Each epic has a test coverage story. Total effort: 5 days

| Epic | Test Story | Status |
|------|------------|--------|
| 2 | Story 2.12 | TODO |
| 3 | Story 3.8 | IN_PROGRESS |
| 4 | Story 4.10 | TODO |
| 5 | Story 5.10 | TODO |
| 6 | Story 6.10 | TODO |
| 7 | Story 7.10 | TODO |
| 8 | Story 8.12 | TODO |
| 9 | Story 9.10 | TODO |
| 10 | Story 10.10 | TODO |
| 11 | Story 11.10 | TODO |

---

## Implementation Timeline

### Sprint 1 (This Week)
- [ ] OAuth Authentication (2.4) - 2d
- [ ] API Authentication Plug (10.7) - 2d
- [ ] TODO-7 Instruction Set Lookup - 0.5d
- [ ] Branding Cascade (8.11) - 1d

### Sprint 2 (Next Week)
- [ ] Context Switching (4.4, 4.5, 4.6) - 3d
- [ ] Customer/Vendor Self-Registration (2.9) - 2d
- [ ] Field-Level Policies (6.6) - 1d

### Sprint 3
- [ ] Missing Shared Entities (9.4-9.8) - 4.5d
- [ ] Team Management UI (6.8) - 2d

### Sprint 4
- [ ] Invitation Management UI (7.8) - 1.5d
- [ ] API Key Management UI (10.6) - 1.5d
- [ ] Custom Domain UI (11.9) - 1d

### Sprint 5
- [ ] DNS Verification (11.2, 11.3) - 2d
- [ ] SSL Provisioning (11.4-11.6) - 3d

### Sprint 6
- [ ] Test Coverage (all epics) - 5d

---

## Files to Archive

Based on analysis, these files in `docs/planning/` should be archived:

| File | Reason | Action |
|------|--------|--------|
| `todo_elimination.md` | 92% complete (12/13 done) | Archive to `docs/archive/planning/` |
| `workflows.yaml` | Empty template, unused | Delete |

Files to **keep active**:
- `domain_brief.md` - Core requirements reference
- `phase_1_epics.md` - Implementation roadmap (still ~45% remaining)

---

## Verification Commands

```bash
# After each implementation
mix compile --warnings-as-errors
mix format
mix credo --strict
mix test

# Final verification
mix test --cover
mix credo --only todo  # Should return 0
```

---

## Success Criteria

- [ ] All 109 stories marked DONE in sprint-status.yaml
- [ ] `mix credo --only todo` returns 0 results
- [ ] All tests pass with >80% coverage
- [ ] OAuth login works for Google and GitHub
- [ ] API keys can authenticate API requests
- [ ] Context switching works across entities
- [ ] Custom domains provision with SSL automatically
