# Implementation Plan - Graph RAG (AshAi + Apache AGE)

This plan details the implementation of a "Graph RAG" system that combines **Apache AGE** (for structural reasoning) with **AshAi v0.4** (for vectorization and tool orchestration).

**Core AI Strategy**:

- **LLM Provider**: **OpenRouter** (via `ChatOpenAI` adapter with custom `base_url`) to access **Gemini 2.0 Pro** and other best-in-class models.
- **Embedding Model**: **OpenAI via OpenRouter** (text-embedding-3-small) as the platform standard for 1536-dimensional vectors.

## User Review Required

> [!IMPORTANT]
> **Apache AGE Dependency**: This plan assumes the `age` extension is available in the Postgres environment. We must verify this before deploying.
>
> **AshAi v0.4 Compliance**: We are strictly adhering to `ash_ai ~> 0.4` patterns (`vectorize` block, `tool` DSL).
>
> **Multi-tenancy**: Graph data will be isolated per-tenant using Postgres Schemas (`acq_<tenant>`), consistent with the platform's "Bulletproof Multi-tenancy" rule.

## Proposed Changes

### 1. Infrastructure (Graph Engine)

#### [NEW] `lib/mcp/graph/tenant_context.ex`

- **Purpose**: Securely execute Cypher queries within a Tenant's specific schema/graph context.
- **Key Logic**:
  - `SET search_path TO acq_<slug>, public, ag_catalog;`
  - `LOAD 'age';`
  - `SET age.graph_name = 'acq_<slug>_graph';`
  - **Rooted Traversal**: Enforce that all queries start from the Actor's ID to prevent cross-tenant data leakage.

### 2. Integration with AshAi (Vectorization)

#### [MODIFY] `lib/mcp/ai/document.ex` (and others)

- Refactor to use **native AshAi v0.4 DSL** instead of manual `pgvector` index management.
- **Change**:
  ```elixir
  use Ash.Resource, extensions: [AshAi]
  ai do
    vectorize do
      strategy :ash_oban            # Async updates via Oban
      embedding_model Mcp.Ai.OpenAiEmbeddingModel # Or local
      full_text do
        text(fn record -> ... end)
      end
    end
  end
  ```

### 3. Data Ingestion ("The Shadow Notifier")

#### [NEW] `lib/mcp/graph/notifier.ex`

- **Purpose**: Keep the AGE Graph in sync with Ash Resources.
- **Mechanism**:
  - Listens to PubSub events (or Ash Notifier hooks) on key resources (`Merchant`, `Reseller`).
  - **Action**: On `create/update`, executes Cypher `MERGE (n:Merchant {id: ...}) ...` to update the graph node.
  - **Strategy**: Async implementation to avoid blocking user actions, using `AshOban` if possible or standard `GenServer` listeners.

### 4. Agent Tools ("The Librarian")

#### [NEW] `lib/mcp/graph/tools.ex` (Domain)

- **Purpose**: Expose Graph capabilities to the LLM.
- **Tools**:
  - `graph_traversal(start_node_id, relationship_type, depth)`: Returns a JSON representation of the subgraph.
  - `find_connected_risks(merchant_id)`: Specialized query for the "Risk" use case.

#### [MODIFY] `lib/mcp/ai.ex` (Domain)

- Register the new capabilities in the `AshAi` domain logic.

## Verification Plan

### Automated Tests

1.  **Graph Isolation Test**:
    - Create Tenant A and Tenant B.
    - Insert Nodes into Tenant A's graph.
    - Attempt to query Tenant A's nodes using Tenant B's context.
    - **Expect**: Empty result / Auth error.
    - _Command_: `mix test test/mcp/graph/isolation_test.exs`

2.  **Ingestion Sync Test**:
    - Create a `Merchant` resource via standard Ash Action.
    - Query the AGE Graph directly via SQL.
    - **Expect**: The Node exists in AGE with correct properties.
    - _Command_: `mix test test/mcp/graph/ingestion_test.exs`

3.  **AshAi Integration Test**:
    - Trigger an embedding update.
    - Verify `ash_oban` job behavior.
    - _Command_: `mix test test/mcp/ai/vector_test.exs`

### Manual Verification

1.  **REPL Check**:
    - Run `Mcp.Graph.TenantContext.execute_cypher(...)` in `iex` and verify output.
2.  **Agent Interaction**:
    - Use the Chat UI to ask: "Who is the owner of Merchant X and what other merchants do they own?"
    - Verify the Agent calls the `graph_traversal` tool.
