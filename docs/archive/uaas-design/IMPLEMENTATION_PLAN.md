# Agentic UaaS Implementation Plan

> **Status**: Active **Phase**: 1 (Core Domain & Schema)

## 1. Goal Description

Build the core infrastructure for the **Agentic Underwriting as a Service
(UaaS)** platform. This involves transitioning from a hardcoded "Merchant
Onboarding" flow to a generic **Agentic Orchestration Engine** capable of
running any underwriting pipeline (Mortgage, Auto, etc.) using configured
"Digital Employees".

## 2. Proposed Changes

### 2.1. Domain & Schema (`Mcp.Underwriting`)

We will introduce new Ash Resources to model the Agentic architecture.

#### `Mcp.Underwriting.Pipeline`

- Defines the workflow stages.
- Fields: `name`, `stages` (list of blueprints).

#### `Mcp.Underwriting.AgentBlueprint`

- Defines the generic agent capability.
- Fields: `name`, `base_prompt`, `tools` (list of atoms).

#### `Mcp.Underwriting.InstructionSet`

- Defines the tenant's specific policy overlay.
- Fields: `tenant_id`, `blueprint_id`, `instructions` (text).

#### `Mcp.Underwriting.Execution`

- Represents a runtime instance of a pipeline.
- Fields: `pipeline_id`, `subject_id`, `status`, `results` (map), `context`
  (map).

### 2.2. Orchestration Engine (`Mcp.Underwriting.Engine`)

#### `Orchestrator`

- The "Brain" that runs the pipeline.
- Logic:
  1. Fetch `Pipeline` and `InstructionSets` for the tenant.
  2. Iterate through stages.
  3. For each stage, invoke the `AgentRunner`.
  4. Store results in `Execution`.

#### `AgentRunner`

- The interface to the LLM (LangChain / OpenAI).
- Merges `Blueprint.base_prompt` + `InstructionSet.instructions` + `Context`.

### 2.3. API Layer (`McpWeb`)

#### `AssessmentController`

- `POST /assess`: Triggers a new Execution.
- `GET /assess/:id`: Retrieves results.

#### `InstructionSetController`

- CRUD for Instruction Sets.

## 3. Task List

### Phase 1: Core Domain & Schema

- [x] Create `Mcp.Underwriting.AgentBlueprint` resource
- [x] Create `Mcp.Underwriting.InstructionSet` resource
- [x] Create `Mcp.Underwriting.Pipeline` resource
- [x] Create `Mcp.Underwriting.Execution` resource
- [x] Generate and run database migrations

### Phase 2: Orchestration Engine

- [x] Implement `Mcp.Underwriting.Engine.Orchestrator`
- [ ] Implement `Mcp.Underwriting.Engine.AgentRunner` (Real LLM Integration)
  - [ ] Add `langchain` dependency
  - [ ] Implement `Ollama` adapter
  - [ ] Implement `OpenRouter` adapter (fallback)
- [ ] Wire up `Oban` job for async execution

### Phase 3: API Layer

- [x] Create `McpWeb.Api.V1.AssessmentController`
- [x] Create `McpWeb.Api.V1.InstructionSetController`
- [x] Add routes to `router.ex`

### Phase 4: Verification

- [x] Write integration test for "Headless" assessment flow
- [x] Verify `InstructionSet` CRUD
