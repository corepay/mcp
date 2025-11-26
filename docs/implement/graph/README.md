# Graph Database Implementation Strategy

## Overview

This document outlines the strategy for implementing a Graph Database within the
MCP platform using `Apache AGE` (A Graph Extension for PostgreSQL). By
leveraging a graph database alongside our relational data, we can unlock
powerful capabilities for fraud detection, recommendation engines, and complex
relationship mapping that are difficult or slow to perform in standard SQL.

## The Opportunity: Why Graph?

Relational databases (SQL) are excellent for storing structured records
(Ledgers, User Profiles). Graph databases are superior for analyzing
**relationships** and **patterns**.

### Key Benefits

1. **Fraud Detection (Ring Fraud)**: Quickly identify clusters of accounts
   sharing attributes (IPs, Devices, Cards) that indicate organized fraud rings.
2. **Recommendation Engines**: "Customers who bought X also bought Y" or
   "Merchants similar to you use these settings."
3. **Hierarchy Management**: Efficiently querying deep, recursive hierarchies
   (e.g., Reseller -> Merchant -> Store -> Terminal).
4. **360-Degree Views**: Linking disparate data points (Support Tickets,
   Transactions, Logs) to form a holistic view of an entity.

## Current Status

**✅ Implemented (The "Blueprint")**

- **Ash Extension (`Mcp.Graph.Extension`)**: A custom DSL extension for Ash
  Resources.
- **DSL Syntax**: Resources can define `node_type` and `graph_relationship`
  directly in their module.
- **Infrastructure**: `apache_age` extension is enabled in the Postgres
  database.

**🚧 To Be Built (The "Engine")**

- **Data Synchronization**: A mechanism (Reactor/Notifier) to listen for Ash
  resource changes and automatically update the Graph nodes/edges.
- **Query Context**: `Mcp.Graph.TenantContext` to execute Cypher queries
  securely within tenant boundaries.

## Roadmap & Recommendations

### Phase 1: Foundation (Complete)

- [x] Enable `apache_age` in Postgres.
- [x] Build Ash DSL Extension.
- [x] Verify compilation in core resources (`Merchant`).

### Phase 2: The Engine (Next Steps)

- [ ] **Implement `GraphNotifier`**: An Ash Notifier that hooks into
      `create/update/destroy` actions.
  - _Logic_: When a Merchant is created, execute Cypher
    `CREATE (:Merchant {id: ...})`.
- [ ] **Implement `GraphContext`**: A module to wrap `Agex` or `Postgrex` calls
      with tenant isolation logic.
  - _Logic_: Ensure every Cypher query includes
    `WHERE n.tenant_id = $tenant_id`.

### Phase 3: Pilot Use Case (Fraud)

- [ ] **Model the Fraud Graph**: Define nodes for `IPAddress`, `Device`,
      `CreditCard`.
- [ ] **Ingest Data**: Backfill existing data into the graph.
- [ ] **Query**: Write a Cypher query to find "Merchants sharing the same IP
      address".

### Phase 4: Advanced Features

- [ ] **Recommendation Engine**: Suggest settings or products based on graph
      proximity.
- [ ] **Visualizer**: Integrate a graph visualization library (e.g., D3.js,
      Cytoscape) in the admin dashboard.
