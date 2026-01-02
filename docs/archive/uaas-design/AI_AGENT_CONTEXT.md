# AI Agent Context: Agentic UaaS

> **System Note**: This document is the **Single Source of Truth** for AI Agents
> working on the Underwriting domain.

## 1. Domain Overview

The **Underwriting as a Service (UaaS)** domain is an **Agentic Orchestration
Platform**.

- **Core Responsibility**: Execute a `Pipeline` of `Specialty Agents` to assess
  a `Subject`.
- **Key Invariant**: Agents are generic (`Blueprints`). They must be configured
  by `InstructionSets` (Tenant Policy) before execution.

## 2. Architectural Constraints

### 2.1. The "Headless" First Principle

- **DO NOT** couple agent logic to the UI.
- **ALWAYS** design agents to be triggered via API (`POST /assess`).
- **REASON**: We support 3rd party integrations (Mortgage Lenders) who bring
  their own UI.

### 2.2. Instruction Injection

- **DO NOT** hardcode business rules (e.g., "Max DTI is 43%") in the Agent
  Blueprint.
- **ALWAYS** inject these rules from the `InstructionSet`.
- **REASON**: Every Tenant has different risk appetites.

## 3. Key Resources

| Resource         | Purpose                 | Key Fields                                 |
| :--------------- | :---------------------- | :----------------------------------------- |
| `Pipeline`       | Ordered list of stages. | `stages` (List of Blueprints)              |
| `AgentBlueprint` | The generic skill.      | `base_prompt`, `tools`                     |
| `InstructionSet` | The tenant's policy.    | `instructions` (Natural Language)          |
| `Execution`      | The runtime state.      | `status`, `results` (Map of Agent Outputs) |

## 4. Common Tasks & Patterns

### Task: Creating a New Specialty Agent

1. Define the `AgentBlueprint` (e.g., `CryptoAnalyst`).
2. Define the `Tools` it needs (e.g., `check_wallet_balance`).
3. Write the `Base Prompt` ("You are an expert in cryptocurrency risk...").

### Task: Debugging an Execution

1. Look at the `Execution` record.
2. Inspect the `InstructionSet` used.
3. Compare the `Agent Output` vs the `Instructions`. Did the agent follow the
   policy?

## 5. Terminology

- **Blueprint**: The "Class" of an agent.
- **Instruction Set**: The "Configuration" instance.
- **Pipeline**: The "Workflow".
- **Digital Employee**: The marketing term for a configured Agent.
