# Graph Domain Strategy

This document details the implementation strategy for the three core domains:
Tenants, Merchants, and Customers.

---

## 1. Tenants (The Container)

### What

The Tenant is the **boundary** of the graph. In our multi-tenant system, graph
data is strictly isolated.

- **Node**: `(:Tenant {id: "..."})`
- **Role**: Root node for all other entities.

### How

- **Isolation**: Every Cypher query must include a tenant filter:
  `MATCH (n) WHERE n.tenant_id = $tenant_id`.
- **Context**: Use `Mcp.Graph.TenantContext` to automatically inject this
  filter.

### Why

- **Security**: Prevents data leakage between resellers/merchants.
- **Performance**: Partitioning graph data by tenant keeps queries fast.

### When

- **Now**: The infrastructure supports this.
- **Next**: Implement the `TenantContext` module to enforce this isolation.

### Where

- **Database**: `ag_catalog` (AGE's internal schema).
- **Code**: `lib/mcp/graph/tenant_context.ex`.

---

## 2. Merchants (The Hub)

### What

The Merchant is the **central hub** of the graph. Most relationships radiate
from here.

- **Node**: `(:Merchant {id: "...", risk_score: 50})`
- **Edges**: `(:Merchant)-[:HAS_STORE]->(:Store)`,
  `(:Merchant)-[:PROCESSED]->(:Transaction)`

### How

- **Ingestion**: When a Merchant is created/updated in Ash, a `GraphNotifier`
  syncs the node properties.
- **Risk Analysis**: Periodically run graph algorithms (e.g., PageRank,
  Community Detection) to update the `risk_score`.

### Why

- **B2B Relationships**: Visualize complex ownership structures (Reseller ->
  Merchant -> Franchise).
- **Risk Rings**: Detect if multiple high-risk merchants share the same
  beneficial owner or bank account.

### When

- **Phase 2**: Implement the synchronization logic.
- **Phase 3**: Build the risk analysis queries.

### Where

- **Code**: `Mcp.Platform.Merchant` (DSL definition).

---

## 3. Customers (The Network)

### What

Customers are the **nodes in the network**. Their value comes from their
connections to other entities.

- **Node**: `(:Customer {id: "...", email: "..."})`
- **Edges**: `(:Customer)-[:BOUGHT_FROM]->(:Merchant)`,
  `(:Customer)-[:USED_DEVICE]->(:Device)`

### How

- **Shared Attributes**: Link customers to shared entities like `(:Device)` or
  `(:IPAddress)`.
- **Traversal**: Query for "Customers who used Device X" to find linked
  accounts.

### Why

- **Fraud Detection**: Identify "synthetic identities" or account takeovers by
  analyzing device/IP sharing.
- **Recommendations**: "People who bought this also bought that" (Collaborative
  Filtering).
- **Marketing**: Identify "Influencers" (highly connected nodes) for targeted
  campaigns.

### When

- **Phase 4**: This is an advanced feature. Start with Merchants/Risk first.

### Where

- **Code**: `Mcp.Platform.Customer` (DSL definition - currently disabled).
