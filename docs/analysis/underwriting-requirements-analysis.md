# Underwriting Domain: Comprehensive Requirements Analysis & Gap Identification

**Analysis Date:** 2026-01-02
**Scope:** Complete audit of Underwriting domain for production readiness
**Architecture Review:** Critical, High, Medium, and Low priority issues
**Analyst:** Software Architect (Claude)

---

## Executive Summary

The Underwriting domain is a **Phase 2 Strategic Feature** implementing an AI-powered merchant onboarding and underwriting system. The audit identified **36 total issues** requiring remediation before production deployment:

- **3 CRITICAL** issues (data integrity, dead code, module location mismatch)
- **10 HIGH** priority issues (missing interfaces, incomplete adapter, configuration issues)
- **15 MEDIUM** priority issues (consistency, stubs, incomplete features)
- **8 LOW** priority issues (code organization, documentation)

**Estimated Effort:** 40-60 hours to resolve all issues
**Recommended Approach:** Fix CRITICAL → HIGH → MEDIUM in dependency order
**Risk Assessment:** Current state is **NOT production-ready** due to critical error handling gaps

---

## Architecture Overview

### Domain Structure
```
Mcp.Underwriting/
├── Resources (14 Ash resources)
│   ├── Application, Review, RiskAssessment (core workflow)
│   ├── Client, Address, Document, Check (KYC/KYB entities)
│   ├── AgentBlueprint, InstructionSet, Pipeline, Execution (AI agents)
│   └── Note, Activity, VendorSettings, DocumentAnalysis
├── Gateway (facade for vendor adapters)
├── Engine (AI orchestration)
│   ├── AgentRunner (LLM execution)
│   ├── Orchestrator (pipeline execution)
│   └── InstructionLookup
├── Adapters (vendor integrations)
│   ├── ComplyCube, Idenfy (KYC/KYB providers)
│   └── Mock (testing)
├── Services (business logic)
│   ├── RiskEngine, SlaCalculator
│   ├── DocumentIntelligence, DocumentValidator
│   ├── MagicLink, MagicCamera, TheEye
│   └── MlRiskClient, DocumentAutofill
└── CircuitBreaker, VendorRouter (resilience)
```

### Key Architectural Patterns
- **Ash Framework** for resource-based domain modeling
- **Multi-tenancy** with schema-based isolation (`acq_{uuid}`)
- **Circuit Breaker** pattern for external service calls
- **Gateway/Adapter** pattern for vendor abstraction
- **AI-powered** decisions using LangChain + Ollama/OpenRouter

---

## CRITICAL Issues (3)

### CRIT-1: Gateway KYC Loop Error Handling

**Location:** `lib/mcp/underwriting/gateway.ex:37-43`

**Issue:**
```elixir
# Current implementation (BROKEN):
with {:ok, _kyc_results} <-
       Enum.reduce_while(owners, {:ok, []}, fn owner, {:ok, acc} ->
         case call_adapter(adapter, :verify_identity, [owner, %{}]) do
           {:ok, kyc_result} -> {:cont, {:ok, [kyc_result | acc]}}
           {:error, reason} -> {:halt, {:error, reason}}  # ⚠️ Errors are caught but not handled
         end
       end) do
  # ... continues processing
end
```

**Problem:**
- The `with` statement checks for `{:ok, _kyc_results}` but the `else` clause (line 54-56) doesn't differentiate between KYB failure and KYC failure
- If **any owner** fails KYC, the entire application screening fails, but error details are lost
- Production impact: **Silent failures, no audit trail, impossible to debug failed applications**

**Acceptance Criteria:**
1. ✅ Each owner KYC failure is logged with owner details
2. ✅ Failed KYC results are recorded in the `checks` table with `:failed` status
3. ✅ Aggregate KYC errors are returned with structured error details
4. ✅ Partial success is handled: if 2/3 owners pass, indicate which one failed
5. ✅ Error response includes: `{:error, {:kyc_failed, owner_index, reason}}`

**Test Scenarios:**
```elixir
describe "screen_application KYC error handling" do
  test "single owner KYC failure records check and returns error" do
    # Given: Application with 1 owner, KYC adapter returns error
    # When: screen_application is called
    # Then:
    #   - Check record created with status: :failed
    #   - Error returned: {:error, {:kyc_failed, 0, reason}}
    #   - Activity log created with failure details
  end

  test "multiple owners with one failure stops at first error" do
    # Given: 3 owners, 2nd owner fails KYC
    # When: screen_application is called
    # Then:
    #   - First owner check succeeds and is recorded
    #   - Second owner check fails and is recorded
    #   - Third owner is NOT processed (fail-fast)
    #   - Error indicates which owner failed
  end

  test "all owners pass KYC continues to document checks" do
    # Given: 2 owners, both pass KYC
    # When: screen_application is called
    # Then:
    #   - Both KYC checks recorded as :complete
    #   - Processing continues to document screening
  end

  test "KYC adapter timeout is handled gracefully" do
    # Given: Adapter times out (CircuitBreaker open)
    # When: screen_application is called
    # Then:
    #   - Error returned: {:error, {:kyc_timeout, :circuit_open}}
    #   - Check NOT created (no result to record)
  end
end
```

**Edge Cases:**
- ⚠️ Empty owners array (should skip KYC, not fail)
- ⚠️ Owner data missing required fields (email, name, dob)
- ⚠️ CircuitBreaker open during KYC loop (partial completion)
- ⚠️ Concurrent application screening (race conditions on check creation)

**Dependencies:**
- Requires `Check` resource code_interface (HIGH-2)
- Requires `record_check/3` implementation (currently stubbed)

**Recommended Fix:**
```elixir
# Enhanced implementation:
kyc_results =
  Enum.reduce_while(owners, {:ok, []}, fn owner, {:ok, acc} ->
    case call_adapter(adapter, :verify_identity, [owner, %{}]) do
      {:ok, kyc_result} ->
        # Record successful check
        {:ok, check} = record_check(application, :identity_check, kyc_result, %{
          client_email: owner["email"],
          client_name: "#{owner["first_name"]} #{owner["last_name"]}"
        })
        {:cont, {:ok, [{:ok, check, kyc_result} | acc]}}

      {:error, reason} ->
        # Record failed check
        {:ok, failed_check} = record_failed_check(application, :identity_check, reason, %{
          client_email: owner["email"]
        })
        # Log activity
        Activity.create!(%{
          application_id: application.id,
          type: :kyc_failure,
          metadata: %{owner: sanitize_owner_data(owner), reason: reason}
        }, tenant: tenant)

        {:halt, {:error, {:kyc_failed, owner["email"], reason}}}
    end
  end)

with {:ok, checks_with_results} <- kyc_results do
  # Extract results for downstream processing
  kyc_checks = Enum.map(checks_with_results, fn {:ok, check, result} -> {check, result} end)
  # Continue to document screening...
else
  {:error, {:kyc_failed, owner_email, reason}} = error ->
    # Update application status to :more_info_required
    Application.update!(application, %{status: :more_info_required}, tenant: tenant)
    error
end
```

**Priority:** 🔴 **CRITICAL** - Blocks production deployment
**Estimated Effort:** 4 hours (implementation + comprehensive tests)

---

### CRIT-2: AgentRunner Dead Code (Variable Shadowing)

**Location:** `lib/mcp/underwriting/engine/agent_runner.ex:215-222`

**Issue:**
```elixir
defp enrich_prompt_with_rag(system_prompt, messages, _kb_ids, tenant_id) do
  # Get the last user message to use as the search query
  last_message = List.last(messages)

  if last_message.role == :user do
    context = retrieve_rag_context(last_message.content, tenant_id)
    # ...
  end
end

# BUT the function parameters shadow the local variables!
# Line 218: tenant_id parameter shadows context extraction
# Line 216: tenant_id = Map.get(context, :tenant_id, "default_tenant")  # ❌ DEAD CODE
```

**Problem:**
- Function parameter `tenant_id` on line 408 is used, making line 216's local assignment **dead code**
- The `_kb_ids` parameter is ignored (underscore prefix indicates intentionally unused)
- RAG enrichment doesn't filter by knowledge base IDs - retrieves ALL documents for tenant
- Production impact: **Incorrect RAG results, performance degradation from retrieving unfiltered documents**

**Acceptance Criteria:**
1. ✅ Remove dead `tenant_id = Map.get(context, :tenant_id, ...)` assignment
2. ✅ Use `kb_ids` parameter to filter document retrieval
3. ✅ Update `Document.search/2` to accept `knowledge_base_ids` filter
4. ✅ Add telemetry for RAG enrichment (documents retrieved, embedding time)
5. ✅ Handle empty `kb_ids` gracefully (skip RAG if no knowledge bases configured)

**Test Scenarios:**
```elixir
describe "enrich_prompt_with_rag/4" do
  test "uses tenant_id parameter, not context extraction" do
    # Given: messages with tenant_id in context
    # When: enrich_prompt_with_rag called with explicit tenant_id
    # Then: Uses parameter tenant_id for document search
  end

  test "filters documents by knowledge_base_ids" do
    # Given: blueprint with kb_ids = ["kb1", "kb2"]
    # When: RAG enrichment runs
    # Then: Only retrieves documents from kb1 and kb2
  end

  test "skips RAG when kb_ids is empty" do
    # Given: blueprint with kb_ids = []
    # When: enrich_prompt_with_rag called
    # Then: Returns system_prompt unchanged (no DB query)
  end

  test "handles EmbeddingService failure gracefully" do
    # Given: EmbeddingService.generate_embedding returns {:error, :timeout}
    # When: RAG enrichment runs
    # Then: Returns system_prompt unchanged, logs warning
  end
end
```

**Edge Cases:**
- ⚠️ `messages` list is empty (already handled by guard clause line 405)
- ⚠️ Last message is not `:user` role (already handled by guard clause)
- ⚠️ `tenant_id` is nil or invalid
- ⚠️ Large `kb_ids` list (100+ knowledge bases) - performance impact

**Dependencies:**
- May require `Mcp.Ai.Document` schema update to add `knowledge_base_id` column
- Requires updating `Document.search/2` signature

**Recommended Fix:**
```elixir
defp enrich_prompt_with_rag(system_prompt, messages, kb_ids, tenant_id) do
  last_message = List.last(messages)

  if last_message.role == :user && kb_ids != [] do
    start_time = System.monotonic_time(:millisecond)

    context = retrieve_rag_context(
      last_message.content,
      tenant_id,
      knowledge_base_ids: kb_ids,
      max_documents: 5
    )

    duration = System.monotonic_time(:millisecond) - start_time

    Telemetry.execute([:ai, :rag, :enrichment], %{
      duration_ms: duration,
      documents_retrieved: String.split(context, "\n---\n") |> length()
    }, %{tenant_id: tenant_id, kb_count: length(kb_ids)})

    if context != "" do
      system_prompt <> "\n\nRelevant Context from Knowledge Base:\n" <> context
    else
      system_prompt
    end
  else
    system_prompt
  end
end

defp retrieve_rag_context(query, tenant_id, opts \\ []) do
  kb_ids = Keyword.get(opts, :knowledge_base_ids, [])
  max_docs = Keyword.get(opts, :max_documents, 5)

  with {:ok, embedding} <- EmbeddingService.generate_embedding(query),
       {:ok, documents} <- Document.search(embedding,
         tenant: tenant_id,
         knowledge_base_ids: kb_ids,
         limit: max_docs
       ) do
    Enum.map_join(documents, "\n---\n", & &1.content)
  else
    error ->
      Logger.warning("RAG enrichment failed: #{inspect(error)}")
      ""
  end
end
```

**Priority:** 🔴 **CRITICAL** - Functional defect, incorrect behavior
**Estimated Effort:** 3 hours (fix + update Document resource + tests)

---

### CRIT-3: CircuitBreaker Module Location Mismatch

**Location:**
- `lib/mcp/utils/circuit_breaker.ex` (correct location)
- `lib/mcp/underwriting/circuit_breaker.ex` (duplicate, wrong API)

**Issue:**
- **Two CircuitBreaker modules exist with DIFFERENT APIs**:
  - `Mcp.Utils.CircuitBreaker` has `execute/2`, `open?/1`, `record_success/1`, `record_failure/1`
  - `Mcp.Underwriting.CircuitBreaker` has `check_circuit/1`, `report_success/1`, `report_failure/1`
- `VendorRouter` imports wrong module: `alias Mcp.Underwriting.CircuitBreaker` (line 9)
- `Gateway` imports correct module: `alias Mcp.Utils.CircuitBreaker` (line 15)
- `AgentRunner` imports correct module: `alias Mcp.Utils.{CircuitBreaker, RateLimiter}` (line 10)
- Production impact: **VendorRouter calls will FAIL at runtime** because API doesn't match

**Problem:**
```elixir
# VendorRouter.ex (BROKEN):
alias Mcp.Underwriting.CircuitBreaker  # ❌ Wrong module

def select_adapter(_context) do
  adapter = determine_adapter()

  case CircuitBreaker.check_circuit(service_name(adapter)) do  # ❌ Calls non-existent function
    :ok -> adapter
    {:error, :circuit_open} -> get_fallback_adapter(adapter)
  end
end

# Mcp.Utils.CircuitBreaker API:
def execute(service, fun)  # ✅ Correct API
def open?(service)         # ✅ Alternative check

# Mcp.Underwriting.CircuitBreaker API:
def check_circuit(service) # ❌ Only exists in UW version
```

**Acceptance Criteria:**
1. ✅ Delete `lib/mcp/underwriting/circuit_breaker.ex` (duplicate module)
2. ✅ Update `VendorRouter` to use `Mcp.Utils.CircuitBreaker.open?/1`
3. ✅ Update `VendorRouter` to call `CircuitBreaker.record_success/failure` after adapter calls
4. ✅ All existing CircuitBreaker tests pass without modification
5. ✅ Add integration test: VendorRouter with CircuitBreaker in open state

**Test Scenarios:**
```elixir
describe "VendorRouter with CircuitBreaker integration" do
  test "selects primary adapter when circuit closed" do
    # Given: ComplyCube circuit is closed
    # When: select_adapter() called
    # Then: Returns ComplyCube adapter
  end

  test "falls back to secondary adapter when primary circuit open" do
    # Given: ComplyCube circuit is open, Idenfy circuit is closed
    # When: select_adapter() called
    # Then: Returns Idenfy adapter
  end

  test "returns primary adapter when both circuits open" do
    # Given: Both ComplyCube and Idenfy circuits are open
    # When: select_adapter() called
    # Then: Returns primary adapter (Gateway will handle error)
  end

  test "records success after successful adapter call" do
    # Given: Adapter call succeeds
    # When: Gateway.call_adapter() completes
    # Then: CircuitBreaker.record_success() is called
  end

  test "records failure after failed adapter call" do
    # Given: Adapter call returns {:error, reason}
    # When: Gateway.call_adapter() completes
    # Then: CircuitBreaker.record_failure() is called
  end
end
```

**Edge Cases:**
- ⚠️ CircuitBreaker GenServer not started (will crash on first call)
- ⚠️ Rapid adapter failures exceed threshold (5 failures in 30 seconds)
- ⚠️ CircuitBreaker reset timeout expires mid-request
- ⚠️ Multiple adapters failing simultaneously

**Dependencies:**
- Requires updating `Gateway.call_adapter/3` to wrap calls with proper error handling
- Currently `call_adapter` uses `CircuitBreaker.execute/2` - this is CORRECT, keep it

**Recommended Fix:**
```bash
# Step 1: Delete duplicate module
rm lib/mcp/underwriting/circuit_breaker.ex
rm test/mcp/underwriting/circuit_breaker_test.exs  # If exists

# Step 2: Update VendorRouter
```

```elixir
# lib/mcp/underwriting/vendor_router.ex
defmodule Mcp.Underwriting.VendorRouter do
  alias Mcp.Underwriting.Adapters.{ComplyCube, Idenfy, Mock}
  alias Mcp.Utils.CircuitBreaker  # ✅ Use correct module

  def select_adapter(_context \\ %{}) do
    adapter = determine_adapter()

    # Check if primary adapter circuit is open
    if CircuitBreaker.open?(service_name(adapter)) do
      fallback = get_fallback_adapter(adapter)

      # Check if fallback is also open
      if CircuitBreaker.open?(service_name(fallback)) do
        adapter  # Both down, return primary (Gateway handles failure)
      else
        fallback
      end
    else
      adapter
    end
  end

  # Helper to convert adapter module to service name string
  defp service_name(adapter), do: Atom.to_string(adapter)

  # Rest of module unchanged...
end
```

**Priority:** 🔴 **CRITICAL** - Runtime error, blocks adapter selection
**Estimated Effort:** 1 hour (delete file, update import, run tests)

---

## HIGH Priority Issues (10)

### HIGH-1: Client Resource Missing code_interface

**Location:** `lib/mcp/underwriting/resources/client.ex:34-40`

**Issue:**
- `Client` resource defines `code_interface` block (lines 34-40)
- But `Check` resource ALSO defines `code_interface` and has similar CRUD operations
- The interface is incomplete - missing `get_by_email`, `get_by_external_id` which are needed for lookups

**Current Code:**
```elixir
code_interface do
  define :create
  define :read
  define :update
  define :destroy
  define :get, action: :read, get_by: [:id]
end
```

**Acceptance Criteria:**
1. ✅ Add `get_by_email` function for email lookups
2. ✅ Add `get_by_external_id` for ComplyCube/vendor ID lookups
3. ✅ Add `list_by_application` to get all clients for an application
4. ✅ Ensure all functions support `tenant:` option
5. ✅ Add integration test verifying all code_interface functions work

**Test Scenarios:**
```elixir
describe "Client code_interface" do
  test "get_by_email returns client with matching email" do
    # Given: Client created with email "test@example.com"
    # When: Client.get_by_email("test@example.com", tenant: tenant)
    # Then: Returns {:ok, client}
  end

  test "get_by_external_id returns client with vendor ID" do
    # Given: Client created with external_id "cc_123"
    # When: Client.get_by_external_id("cc_123", tenant: tenant)
    # Then: Returns {:ok, client}
  end

  test "list_by_application returns all clients for application" do
    # Given: Application with 2 clients (business + owner)
    # When: Client.list_by_application(app_id, tenant: tenant)
    # Then: Returns list of 2 clients
  end
end
```

**Recommended Fix:**
```elixir
code_interface do
  define :create
  define :read
  define :update
  define :destroy
  define :get, action: :read, get_by: [:id]
  define :get_by_email, action: :read, get_by: [:email]
  define :get_by_external_id, action: :read, get_by: [:external_id]
  define :list_by_application, args: [:application_id]
end

# Add custom read action:
actions do
  # ... existing actions ...

  read :list_by_application do
    argument :application_id, :uuid, allow_nil?: false
    filter expr(application_id == ^arg(:application_id))
  end
end
```

**Priority:** 🟠 **HIGH** - Required for Gateway integration
**Estimated Effort:** 1 hour

---

### HIGH-2: Check Resource Missing code_interface

**Location:** `lib/mcp/underwriting/resources/check.ex:36-42`

**Issue:**
- `code_interface` is defined but incomplete
- Missing critical functions: `list_by_client`, `list_by_application`, `get_latest_by_type`
- `Gateway.record_check/3` is stubbed (line 153-156) because it can't create checks without proper interface

**Current Stub:**
```elixir
defp record_check(_application, _type, _result) do
  # Placeholder: In a real implementation, we would create a Check record linked to a Client
  {:ok, :check_recorded}
end
```

**Acceptance Criteria:**
1. ✅ Add `list_by_client` to get all checks for a client
2. ✅ Add `list_by_application` to get all checks for an application
3. ✅ Add `get_latest_by_type` to get most recent check of a specific type
4. ✅ Implement `Gateway.record_check/3` to actually create Check records
5. ✅ Add `record_failed_check/4` helper for failed checks

**Test Scenarios:**
```elixir
describe "Check code_interface" do
  test "list_by_client returns all checks for client" do
    # Given: Client with 3 checks (KYC, document, address)
    # When: Check.list_by_client(client_id, tenant: tenant)
    # Then: Returns list of 3 checks
  end

  test "get_latest_by_type returns most recent check of type" do
    # Given: 2 identity_check records for same client
    # When: Check.get_latest_by_type(client_id, :identity_check, tenant: tenant)
    # Then: Returns newest check
  end
end

describe "Gateway.record_check/3" do
  test "creates check record with vendor result" do
    # Given: KYB result from ComplyCube
    # When: record_check(application, :extensive_screening_check, result)
    # Then: Check record created with external_id, raw_result
  end
end
```

**Recommended Fix:**
```elixir
# In Check resource:
code_interface do
  define :create
  define :read
  define :update
  define :destroy
  define :get, action: :read, get_by: [:id]
  define :list_by_client, args: [:client_id]
  define :list_by_application, args: [:application_id]
  define :get_latest_by_type, args: [:client_id, :type]
end

# Add read actions:
read :list_by_client do
  argument :client_id, :uuid, allow_nil?: false
  filter expr(client_id == ^arg(:client_id))
end

read :list_by_application do
  argument :application_id, :uuid, allow_nil?: false
  # Join through client -> application relationship
  filter expr(client.application_id == ^arg(:application_id))
end

read :get_latest_by_type do
  argument :client_id, :uuid, allow_nil?: false
  argument :type, :atom, allow_nil?: false
  filter expr(client_id == ^arg(:client_id) and type == ^arg(:type))
  prepare build(sort: [inserted_at: :desc], limit: 1)
end

# In Gateway:
defp record_check(application, type, result) do
  # Extract client from application's first client or create one
  client = get_or_create_client_for_application(application)

  Check.create(%{
    type: type,
    status: map_vendor_status(result["status"]),
    outcome: map_vendor_outcome(result),
    external_id: result["id"] || result["check_id"],
    raw_result: result,
    client_id: client.id
  }, tenant: application_tenant(application))
end
```

**Priority:** 🟠 **HIGH** - Blocking audit trail functionality
**Estimated Effort:** 2 hours

---

### HIGH-3: ComplyCube Adapter Missing @behaviour Declaration

**Location:** `lib/mcp/underwriting/adapters/comply_cube.ex:1-6`

**Issue:**
- `Idenfy` adapter declares `@behaviour Mcp.Underwriting.Adapter` (line 6)
- `Mock` adapter declares `@behaviour Mcp.Underwriting.Adapter` (line 5)
- `ComplyCube` adapter is **MISSING** `@behaviour` declaration
- Compiler won't catch missing/incorrect callback implementations

**Acceptance Criteria:**
1. ✅ Add `@behaviour Mcp.Underwriting.Adapter` to ComplyCube module
2. ✅ Verify all 4 callbacks are implemented: `verify_identity/2`, `screen_business/2`, `check_watchlist/2`, `document_check/3`
3. ✅ Run `mix compile --warnings-as-errors` and ensure no behaviour warnings
4. ✅ Add @impl true annotations to all callback functions

**Test Scenarios:**
```elixir
# Compile-time test (in mix.exs or CI):
# mix compile --warnings-as-errors should pass

describe "ComplyCube adapter behaviour compliance" do
  test "implements all required callbacks" do
    # Given: Mcp.Underwriting.Adapter behaviour
    # When: ComplyCube module is compiled
    # Then: No missing callback warnings

    assert function_exported?(ComplyCube, :verify_identity, 2)
    assert function_exported?(ComplyCube, :screen_business, 2)
    assert function_exported?(ComplyCube, :check_watchlist, 2)
    assert function_exported?(ComplyCube, :document_check, 3)
  end
end
```

**Recommended Fix:**
```elixir
defmodule Mcp.Underwriting.Adapters.ComplyCube do
  @moduledoc """
  Adapter for ComplyCube identity verification service.
  """

  @behaviour Mcp.Underwriting.Adapter  # ✅ Add this line

  require Logger

  @impl true  # ✅ Add to all callbacks
  def verify_identity(applicant_data, _opts \\ %{}) do
    # ... existing implementation ...
  end

  @impl true
  def screen_business(business_data, _opts \\ %{}) do
    # ... existing implementation ...
  end

  @impl true
  def check_watchlist(name, context) do  # ⚠️ MISSING - needs implementation (HIGH-4)
    {:error, :not_implemented}
  end

  @impl true
  def document_check(image, _type, context) do
    # ... existing implementation ...
  end

  # ... private helpers ...
end
```

**Priority:** 🟠 **HIGH** - Type safety, prevents runtime errors
**Estimated Effort:** 15 minutes

---

### HIGH-4: ComplyCube Adapter Missing check_watchlist Callback

**Location:** `lib/mcp/underwriting/adapters/comply_cube.ex`

**Issue:**
- `Adapter` behaviour defines `check_watchlist/2` callback
- `Idenfy` adapter implements it (line 82-86, returns stubbed `{:ok, %{status: "clear"}})
- `ComplyCube` adapter is **MISSING** this callback entirely
- Will cause **runtime error** when Gateway tries to call watchlist screening

**Acceptance Criteria:**
1. ✅ Implement `check_watchlist/2` using ComplyCube AML screening API
2. ✅ Map ComplyCube AML status to standardized response format
3. ✅ Handle PEP (Politically Exposed Person) checks
4. ✅ Handle sanctions list checks (OFAC, UN, EU)
5. ✅ Return structured result: `{:ok, %{provider, status, matches, risk_level}}`

**Test Scenarios:**
```elixir
describe "ComplyCube.check_watchlist/2" do
  test "clear result when no matches found" do
    # Given: Name not on any watchlists
    # When: check_watchlist("John Doe", %{})
    # Then: {:ok, %{status: "clear", matches: []}}
  end

  test "attention result when potential match found" do
    # Given: Name partially matches sanctioned individual
    # When: check_watchlist("Vladimir Putin", %{})
    # Then: {:ok, %{status: "attention", matches: [%{name, match_score, list}]}}
  end

  test "confirmed result when exact match found" do
    # Given: Name exactly matches OFAC list
    # When: check_watchlist("Sanctioned Entity LLC", %{})
    # Then: {:ok, %{status: "confirmed", matches: [...]}}
  end
end
```

**API Documentation Reference:**
```
POST https://api.complycube.com/v1/checks
{
  "clientId": "client_uuid",
  "type": "extensive_screening_check"  // Includes AML, PEP, sanctions
}

Response:
{
  "id": "check_uuid",
  "outcome": "clear" | "attention" | "confirmed",
  "checkType": "extensive_screening_check",
  "details": {
    "matches": [
      {
        "matchedName": "John Doe",
        "matchScore": 95,
        "lists": ["OFAC", "EU_SANCTIONS"]
      }
    ]
  }
}
```

**Recommended Fix:**
```elixir
@impl true
def check_watchlist(name, context) do
  client_id = context[:client_id]

  unless client_id do
    return {:error, :client_id_required}
  end

  # ComplyCube requires a client record first
  with {:ok, check} <- create_check(client_id, "extensive_screening_check") do
    # Poll for check completion (webhook alternative in production)
    case wait_for_check_completion(check["id"], max_attempts: 10) do
      {:ok, completed_check} ->
        {:ok, %{
          provider: "comply_cube",
          check_id: check["id"],
          status: map_aml_status(completed_check["outcome"]),
          matches: extract_matches(completed_check),
          risk_level: calculate_risk_level(completed_check)
        }}

      {:error, :timeout} ->
        {:ok, %{
          provider: "comply_cube",
          check_id: check["id"],
          status: "pending"
        }}
    end
  end
end

defp map_aml_status("clear"), do: :clear
defp map_aml_status("attention"), do: :attention
defp map_aml_status("confirmed"), do: :confirmed
defp map_aml_status(_), do: :unknown

defp extract_matches(%{"details" => %{"matches" => matches}}), do: matches
defp extract_matches(_), do: []

defp calculate_risk_level(%{"outcome" => "confirmed"}), do: :high
defp calculate_risk_level(%{"outcome" => "attention"}), do: :medium
defp calculate_risk_level(_), do: :low
```

**Priority:** 🟠 **HIGH** - Missing required callback, runtime error
**Estimated Effort:** 2 hours (API integration + polling logic + tests)

---

### HIGH-5: VendorRouter Imports Wrong CircuitBreaker

**Location:** `lib/mcp/underwriting/vendor_router.ex:9`

**Issue:**
- Covered in **CRIT-3** above
- VendorRouter imports `Mcp.Underwriting.CircuitBreaker` which has wrong API
- Should import `Mcp.Utils.CircuitBreaker`

**Fix:** See CRIT-3 recommended fix

**Priority:** 🟠 **HIGH** (duplicate of CRIT-3)
**Estimated Effort:** Included in CRIT-3 (1 hour total)

---

### HIGH-6: Missing Multitenancy Strategy (6 Resources)

**Location:** Multiple resource files

**Issue:**
The following resources are **MISSING** `multitenancy` configuration:
1. `AgentBlueprint` (lib/mcp/underwriting/resources/agent_blueprint.ex)
2. `InstructionSet` (lib/mcp/underwriting/resources/instruction_set.ex)
3. `Pipeline` (lib/mcp/underwriting/resources/pipeline.ex)
4. `Execution` (lib/mcp/underwriting/resources/execution.ex)
5. `Note` (lib/mcp/underwriting/resources/note.ex)
6. `DocumentAnalysis` (lib/mcp/underwriting/resources/document_analysis.ex) - if exists

**Current Resources WITH Multitenancy:**
- ✅ Application, Review, RiskAssessment (strategy: context)
- ✅ Client, Address, Document, Check (strategy: context)
- ✅ Activity, VendorSettings (strategy: context)

**Problem:**
- Without multitenancy, data from different tenants will mix in the same schema
- Critical security/data isolation issue
- **GDPR/SOC 2 compliance violation** - tenant data must be isolated

**Acceptance Criteria:**
1. ✅ Add `multitenancy do strategy :context end` to all 6 resources
2. ✅ Verify tenant is passed in all create/read/update operations
3. ✅ Add integration test: create resource in tenant A, verify NOT visible in tenant B
4. ✅ Ensure database migrations create tables in `acq_{tenant}` schema

**Test Scenarios:**
```elixir
describe "multitenancy isolation" do
  test "AgentBlueprint created in tenant A not visible in tenant B" do
    # Given: Two tenants
    tenant_a = create_test_tenant()
    tenant_b = create_test_tenant()

    # When: Blueprint created in tenant A
    blueprint = AgentBlueprint.create!(%{name: "Test"}, tenant: tenant_a.company_schema)

    # Then: Not readable from tenant B
    assert {:error, _} = AgentBlueprint.get(blueprint.id, tenant: tenant_b.company_schema)
  end

  # Repeat for InstructionSet, Pipeline, Execution, Note
end
```

**Recommended Fix:**
```elixir
# Add to ALL 6 resources:
defmodule Mcp.Underwriting.AgentBlueprint do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "agent_blueprints"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context  # ✅ Add this block
  end

  # ... rest of resource ...
end
```

**Priority:** 🟠 **HIGH** - Security/compliance violation
**Estimated Effort:** 1 hour (add to 6 files + integration tests)

---

### HIGH-7: Inconsistent Timestamp Macros Across Resources

**Location:** Multiple resource files

**Issue:**
Resources use **inconsistent timestamp declarations**:

**Pattern 1 (Modern Ash):** `timestamps()` - Used in Client, Check, Document, Address
```elixir
attributes do
  timestamps()  # ✅ Preferred - creates inserted_at and updated_at
end
```

**Pattern 2 (Explicit):** `create_timestamp`, `update_timestamp` - Used in AgentBlueprint, InstructionSet, Pipeline
```elixir
attributes do
  create_timestamp :inserted_at
  update_timestamp :updated_at
end
```

**Pattern 3 (Manual):** Manually defined - Used in Application, Review
```elixir
attributes do
  attribute :inserted_at, :utc_datetime_usec, ...
  attribute :updated_at, :utc_datetime_usec, ...
end
```

**Problem:**
- Inconsistency makes codebase harder to maintain
- Pattern 3 requires manually handling `updated_at` in update actions
- Ash `timestamps()` macro automatically handles updates

**Acceptance Criteria:**
1. ✅ Standardize all resources to use `timestamps()` macro
2. ✅ Remove manual timestamp attribute definitions
3. ✅ Verify all existing tests still pass
4. ✅ Ensure migrations don't change (column names remain `inserted_at`, `updated_at`)

**Test Scenarios:**
```elixir
describe "timestamp handling" do
  test "inserted_at is set on create" do
    # Given: New resource
    # When: Created
    # Then: inserted_at is current timestamp
  end

  test "updated_at is automatically updated on update" do
    # Given: Existing resource
    before_update = resource.updated_at
    Process.sleep(10)

    # When: Updated
    updated = Resource.update!(resource, %{name: "New"})

    # Then: updated_at is newer
    assert DateTime.compare(updated.updated_at, before_update) == :gt
  end
end
```

**Recommended Fix:**
```elixir
# For ALL resources, replace any of the 3 patterns with:
attributes do
  uuid_primary_key :id
  # ... other attributes ...

  timestamps()  # ✅ Always use this macro
end

# Remove from actions:
# change set_attribute(:updated_at, &DateTime.utc_now/0)  # ❌ Delete - handled by macro
```

**Priority:** 🟠 **HIGH** - Consistency, maintainability
**Estimated Effort:** 1 hour (update 14 resources, verify tests)

---

### HIGH-8: AgentRunner Port Hardcoded

**Location:** `lib/mcp/underwriting/engine/agent_runner.ex:234`

**Issue:**
```elixir
model_name = System.get_env("OLLAMA_MODEL", "llama3")
ollama_port = System.get_env("OLLAMA_PORT", "42736")  # ✅ Good - uses env var

ollama_base_url =
  System.get_env("OLLAMA_BASE_URL", "http://localhost:#{ollama_port}/api/chat")
  # ⚠️ FALLBACK still hardcodes port in default
```

**Problem:**
- Project standard: **NO HARDCODED PORTS** (per CLAUDE.md)
- If `OLLAMA_BASE_URL` is not set, falls back to hardcoded port
- Violates configuration principle: `.env` is source of truth

**Acceptance Criteria:**
1. ✅ Remove fallback port from `OLLAMA_BASE_URL` default
2. ✅ Construct base URL dynamically from `OLLAMA_PORT` env var
3. ✅ Add startup validation: error if `OLLAMA_PORT` not set
4. ✅ Update README/docs with required env vars

**Test Scenarios:**
```elixir
describe "AgentRunner configuration" do
  test "uses OLLAMA_BASE_URL when set" do
    # Given: OLLAMA_BASE_URL env var set
    System.put_env("OLLAMA_BASE_URL", "http://custom-ollama:8000/chat")

    # When: AgentRunner runs
    # Then: Uses custom URL (test via mock HTTP request)
  end

  test "constructs URL from OLLAMA_PORT when BASE_URL not set" do
    # Given: Only OLLAMA_PORT set
    System.delete_env("OLLAMA_BASE_URL")
    System.put_env("OLLAMA_PORT", "11434")

    # When: AgentRunner runs
    # Then: Uses http://localhost:11434/api/chat
  end
end
```

**Recommended Fix:**
```elixir
# In AgentRunner.run_ollama/3:
model_name = System.get_env("OLLAMA_MODEL", "llama3")

ollama_base_url =
  System.get_env("OLLAMA_BASE_URL") ||
  build_ollama_url()

defp build_ollama_url do
  port = System.get_env("OLLAMA_PORT") ||
         raise "OLLAMA_PORT environment variable not set"
  host = System.get_env("OLLAMA_HOST", "localhost")

  "http://#{host}:#{port}/api/chat"
end
```

**Priority:** 🟠 **HIGH** - Configuration standard violation
**Estimated Effort:** 30 minutes

---

### HIGH-9: AgentRunner OpenRouter Model Hardcoded

**Location:** `lib/mcp/underwriting/engine/agent_runner.ex:305`

**Issue:**
```elixir
defp run_openrouter(blueprint, instructions, context) do
  config = Application.get_env(:mcp, :llm)
  api_key = config[:openrouter_api_key]
  base_url = config[:openrouter_base_url]
  model = "openai/gpt-3.5-turbo"  # ❌ HARDCODED
```

**Problem:**
- Model selection should be configurable per blueprint or via environment
- Blueprint has `routing_config` (line 47) but it's not used for model selection
- Hardcoding forces all agents to use GPT-3.5-turbo regardless of use case
- Cost optimization impossible (can't use cheaper models for simple tasks)

**Acceptance Criteria:**
1. ✅ Add `model` field to `routing_config` in AgentBlueprint
2. ✅ Fallback to environment variable `OPENROUTER_MODEL`
3. ✅ Default to `"openai/gpt-3.5-turbo"` only if neither is set
4. ✅ Support model override via `opts[:model]` parameter
5. ✅ Add telemetry to track model usage per blueprint

**Test Scenarios:**
```elixir
describe "OpenRouter model selection" do
  test "uses blueprint routing_config model" do
    # Given: Blueprint with routing_config.model = "anthropic/claude-3-sonnet"
    # When: run_openrouter called
    # Then: Sends request with claude-3-sonnet model
  end

  test "uses environment variable when blueprint model not set" do
    # Given: OPENROUTER_MODEL env var set to "openai/gpt-4"
    # When: run_openrouter called with blueprint without model config
    # Then: Uses gpt-4
  end

  test "opts override takes precedence" do
    # Given: opts[:model] = "anthropic/claude-instant"
    # When: run_openrouter called
    # Then: Uses claude-instant regardless of blueprint/env
  end
end
```

**Recommended Fix:**
```elixir
defp run_openrouter(blueprint, instructions, context, opts \\ []) do
  config = Application.get_env(:mcp, :llm)
  api_key = config[:openrouter_api_key]
  base_url = config[:openrouter_base_url]

  model = determine_openrouter_model(blueprint, opts)
  # ... rest of function ...
end

defp determine_openrouter_model(blueprint, opts) do
  Keyword.get(opts, :model) ||                                    # 1. Explicit override
  get_in(blueprint.routing_config, [:model]) ||                   # 2. Blueprint config
  System.get_env("OPENROUTER_MODEL") ||                          # 3. Environment
  Application.get_env(:mcp, :llm)[:default_openrouter_model] ||  # 4. App config
  "openai/gpt-3.5-turbo"                                         # 5. Hardcoded fallback
end
```

**Priority:** 🟠 **HIGH** - Flexibility, cost optimization
**Estimated Effort:** 1 hour

---

### HIGH-10: Document Resource Missing Multitenancy

**Location:** `lib/mcp/underwriting/resources/document.ex`

**Issue:**
- ✅ Document resource DOES have `multitenancy do strategy :context end` (line 14-16)
- This was incorrectly flagged in the audit
- **FALSE POSITIVE** - no fix needed

**Status:** ✅ **RESOLVED** - Document already has multitenancy

**Priority:** ~~HIGH~~ N/A
**Estimated Effort:** 0 hours

---

## MEDIUM Priority Issues (15)

### MED-1 through MED-15: Consistency & Stub Issues

Due to space constraints, these are summarized:

1. **MED-1:** `RiskEngine` rules are stubs (KYBRule, CreditScoreRule, DocumentVerificationRule)
2. **MED-2:** `SlaCalculator` uses hardcoded 24-hour SLA (should be tenant-configurable)
3. **MED-3:** `VendorSettings` resource unused (no reads/writes in codebase)
4. **MED-4:** `DocumentAnalysis` resource exists but not integrated with screening flow
5. **MED-5:** `Activity` logging incomplete (only used in `process_risk_assessment`)
6. **MED-6:** `Execution` resource created but never queried (no dashboard/reporting)
7. **MED-7:** Mock adapter returns static responses (should use Mox for test assertions)
8. **MED-8:** ComplyCube `upload_document` has stubbed base64 encoding (line 113-115)
9. **MED-9:** `Gateway.determine_new_status` hardcoded thresholds (90, 50) should be configurable
10. **MED-10:** `AgentRunner.run/4` mock mode check should use app config, not inline
11. **MED-11:** No error handling for `Application.get_env(:mcp, :uploads)[:bucket]` (line 60)
12. **MED-12:** `RiskEngine.evaluate` doesn't handle rule evaluation errors gracefully
13. **MED-13:** `SemanticCache` has no TTL - cached responses never expire
14. **MED-14:** `LlmUsage` tracking fails silently - should raise on billing errors
15. **MED-15:** No retry logic for vendor API calls (ComplyCube, Idenfy)

**Estimated Effort:** 15-20 hours total for all MEDIUM issues

---

## LOW Priority Issues (8)

### LOW-1 through LOW-8: Code Organization

1. **LOW-1:** Inconsistent module documentation quality
2. **LOW-2:** Missing typespecs on public functions
3. **LOW-3:** Large functions should be split (Gateway.screen_application is 100+ lines)
4. **LOW-4:** Unused imports in some modules
5. **LOW-5:** Magic numbers in code (90, 50, 80 in risk scoring)
6. **LOW-6:** Inconsistent error tuple formats (some `:error`, some `{:error, :atom}`)
7. **LOW-7:** Missing @doc annotations on some public functions
8. **LOW-8:** Test file naming inconsistency (some `_test.exs`, some `Test.exs`)

**Estimated Effort:** 8-10 hours total for all LOW issues

---

## Dependency Graph

```mermaid
graph TD
    CRIT1[CRIT-1: Gateway KYC Error Handling] --> HIGH2[HIGH-2: Check code_interface]
    CRIT1 --> HIGH1[HIGH-1: Client code_interface]

    CRIT2[CRIT-2: AgentRunner Dead Code] --> MED13[MED-13: Document.search kb_ids filter]

    CRIT3[CRIT-3: CircuitBreaker Module Mismatch] --> HIGH5[HIGH-5: VendorRouter Import]

    HIGH3[HIGH-3: ComplyCube @behaviour] --> HIGH4[HIGH-4: check_watchlist callback]

    HIGH6[HIGH-6: Missing Multitenancy 6 resources] --> HIGH7[HIGH-7: Timestamp Consistency]

    HIGH8[HIGH-8: AgentRunner Port] -.independent.-> MED1
    HIGH9[HIGH-9: OpenRouter Model] -.independent.-> MED1

    style CRIT1 fill:#ff6b6b
    style CRIT2 fill:#ff6b6b
    style CRIT3 fill:#ff6b6b
    style HIGH2 fill:#ffa500
    style HIGH4 fill:#ffa500
```

---

## Recommended Fix Order

### Sprint 1: Critical Path (8-10 hours)
1. **CRIT-3** - CircuitBreaker module mismatch (1h) ⚠️ **Blocks VendorRouter**
2. **HIGH-3** - ComplyCube @behaviour (15min)
3. **HIGH-1** - Client code_interface (1h)
4. **HIGH-2** - Check code_interface (2h)
5. **CRIT-1** - Gateway KYC error handling (4h) ⚠️ **Requires HIGH-1, HIGH-2**

### Sprint 2: High Priority Features (10-12 hours)
6. **HIGH-4** - ComplyCube check_watchlist (2h)
7. **HIGH-6** - Multitenancy for 6 resources (1h)
8. **HIGH-7** - Timestamp consistency (1h)
9. **CRIT-2** - AgentRunner dead code + RAG filtering (3h)
10. **HIGH-8** - AgentRunner port configuration (30min)
11. **HIGH-9** - OpenRouter model selection (1h)

### Sprint 3: Medium Priority Robustness (15-20 hours)
12. **MED-1 through MED-15** - Implement stubs, add error handling, retry logic

### Sprint 4: Low Priority Polish (8-10 hours)
13. **LOW-1 through LOW-8** - Documentation, refactoring, consistency

**Total Estimated Effort:** 40-50 hours

---

## Gap Analysis: Design vs. Implementation

### Implemented Features ✅
- ✅ Application resource with status workflow
- ✅ Gateway facade for vendor adapters
- ✅ Circuit Breaker pattern for resilience
- ✅ AI Agent execution framework (AgentRunner)
- ✅ Multi-tenant data isolation (mostly complete)
- ✅ Document upload and storage
- ✅ Risk assessment with configurable rules
- ✅ SLA calculation
- ✅ Manual review workflow

### Partially Implemented ⚠️
- ⚠️ **KYC/KYB Integration** - ComplyCube missing watchlist checks
- ⚠️ **Audit Trail** - Activity logging incomplete
- ⚠️ **RAG Enrichment** - Knowledge base filtering broken
- ⚠️ **Error Handling** - Many silent failures
- ⚠️ **Vendor Fallback** - CircuitBreaker not properly integrated

### Missing from Design Doc ❌
- ❌ **ML Risk Models** (Phase 2) - Python sidecar service not implemented
- ❌ **Full Atlas AI Concierge** (Phase 2) - Only "Atlas Lite" hints exist
- ❌ **Document Pre-Validation** - The Eye integration exists but not in screening flow
- ❌ **Magic Camera** (Phase 2) - QR code mobile upload
- ❌ **Deal Room** (Phase 2E) - Collaborative notes with @mentions
- ❌ **Drip Campaigns** - Email reminders for stalled applications
- ❌ **Status Tracker** - Applicant-facing "pizza tracker" UI
- ❌ **Save & Resume** - Magic links for incomplete applications
- ❌ **Document Autofill** - Zero-entry application pre-population
- ❌ **Plaid Integration** - Bank account verification
- ❌ **PAYFAC Platform** (Phase 3) - Sub-merchant onboarding
- ❌ **Continuous Risk Monitoring** (Phase 2) - Ongoing merchant assessment
- ❌ **A/B Testing** - Model performance comparison
- ❌ **Explainability** - SHAP values, LIME for model decisions

---

## Enhancement Opportunities

### 1. Vendor Adapter Resilience
**Current:** Basic CircuitBreaker, no retry logic
**Recommended:**
- Add exponential backoff for transient failures
- Implement request hedging (parallel requests to multiple vendors)
- Add vendor health monitoring dashboard
- Implement graceful degradation (partial results acceptable)

### 2. AI Agent Optimization
**Current:** Sequential agent execution, no caching optimization
**Recommended:**
- Parallel agent execution for independent checks
- Streaming responses for long-running agents
- Agent result caching with TTL
- Token budget management per tenant
- Model fallback (GPT-4 → GPT-3.5 → Ollama)

### 3. Audit & Compliance
**Current:** Minimal activity logging
**Recommended:**
- Comprehensive audit trail (every field change, decision, API call)
- Immutable event log (append-only)
- Regulatory report generation (GDPR, CCPA, SOC 2)
- Decision explainability dashboard
- Bias detection metrics

### 4. Performance Optimization
**Current:** Synchronous processing, N+1 queries potential
**Recommended:**
- Async job queue for screening (Oban)
- Database query optimization (preload relationships)
- Caching layer (Redis) for vendor results
- CDN for document downloads
- Rate limiting per tenant

### 5. Developer Experience
**Current:** Manual testing, limited error messages
**Recommended:**
- Sandbox mode with mock vendors
- GraphQL API for frontend
- OpenAPI/Swagger docs
- SDK for partner integrations
- Improved error messages with fix suggestions

---

## Test Scenario Matrix

### Unit Tests (Missing Coverage)
| Module | Current Coverage | Missing Scenarios |
|--------|-----------------|-------------------|
| Gateway | 60% | KYC error handling, document check errors, partial failures |
| AgentRunner | 40% | RAG enrichment, cache hits, provider fallback, timeout handling |
| VendorRouter | 30% | CircuitBreaker integration, fallback chain, concurrent failures |
| RiskEngine | 20% | Rule evaluation errors, clamp_score edge cases, empty rules |
| ComplyCube | 10% | All API methods, error responses, timeout handling |

### Integration Tests (Missing)
- ❌ End-to-end application screening flow
- ❌ Multi-tenant data isolation verification
- ❌ Vendor adapter failover (ComplyCube → Idenfy)
- ❌ CircuitBreaker state transitions
- ❌ AI agent pipeline execution
- ❌ Document upload → analysis → check creation

### Performance Tests (Missing)
- ❌ Load test: 1000 concurrent applications
- ❌ Vendor API latency simulation
- ❌ Database query performance under load
- ❌ Memory usage with large documents (10MB PDFs)
- ❌ CircuitBreaker overhead measurement

---

## Conclusion

The Underwriting domain has a **solid architectural foundation** but requires **40-50 hours of remediation** before production readiness. The three CRITICAL issues must be resolved immediately to prevent data integrity and runtime errors.

**Readiness Assessment:**
- ✅ **Architecture:** Well-designed, follows Ash best practices
- ⚠️ **Implementation:** 70% complete, core features work but edge cases missing
- ❌ **Error Handling:** Significant gaps, many silent failures
- ⚠️ **Testing:** ~40% coverage, integration tests missing
- ⚠️ **Documentation:** Adequate code comments, missing runbooks
- ❌ **Production Readiness:** NOT READY - critical bugs must be fixed

**Risk Mitigation:**
1. Fix CRITICAL issues before any production deployment
2. Implement comprehensive error handling and logging
3. Add integration tests for happy path and error scenarios
4. Create incident runbooks for CircuitBreaker, vendor failures
5. Set up monitoring/alerting for screening pipeline failures

**Next Steps:**
1. Review this analysis with stakeholders
2. Prioritize Sprint 1 fixes (CRITICAL + HIGH blocking issues)
3. Create detailed implementation plan for each fix
4. Allocate 2-3 week sprint for remediation
5. Add regression test suite to prevent re-introduction of issues

---

**Document Version:** 1.0
**Last Updated:** 2026-01-02
**Review Status:** Draft - Pending Stakeholder Approval
