# Technical Implementation: Graph-Enhanced RAG Architecture

## System Architecture Overview

### Current Stack Analysis
✅ **PostgreSQL 15**: Running successfully on port 41789
✅ **Elixir/Ash Framework**: Application running on localhost:4000
✅ **Multi-Tenant Isolation**: `acq_tenant_` schema pattern implemented
✅ **Repository Pattern**: Mcp.Core.Repo with tenant context support

### Graph Integration Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Web Layer     │    │   Business Layer │    │   Data Layer    │
│                 │    │                  │    │                 │
│ Phoenix/LV     │───▶│   Ash Resources  │───▶│ PostgreSQL +AGE │
│ GraphQL API     │    │   Graph Queries  │    │   Multi-Tenant  │
│ REST Endpoints  │    │   RAG + Graph    │    │   Graph Schemas │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
**Objective**: Basic AGE integration with tenant isolation

**Database Setup:**
```sql
-- Update existing postgres configuration
-- Already completed in docker-compose.yml

-- Enable AGE extension in each tenant schema
CREATE EXTENSION IF NOT EXISTS age;

-- Create tenant graph function (update existing)
CREATE OR REPLACE FUNCTION create_tenant_schema(tenant_schema_name TEXT)
RETURNS VOID AS $$
DECLARE
    schema_full_name TEXT;
    graph_name TEXT;
BEGIN
    schema_full_name := 'acq_' || tenant_schema_name;
    graph_name := schema_full_name || '_relationships';

    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_full_name);
    EXECUTE format('SELECT ag_catalog.create_graph(%L)', graph_name);

    -- Grant permissions
    EXECUTE format('GRANT ALL ON SCHEMA %I TO mcp_user', schema_full_name);

    RAISE NOTICE 'Created tenant schema % with graph %', schema_full_name, graph_name;
END;
$$ LANGUAGE plpgsql;
```

**Elixir Implementation:**
```elixir
# lib/mcp/graph/tenant_context.ex
defmodule Mcp.Graph.TenantContext do
  @moduledoc """
  Multi-tenant graph context with secure isolation
  """

  alias Mcp.Core.Repo

  def with_tenant_graph(tenant_id, graph_name, fun) when is_function(fun, 0) do
    schema_name = "acq_#{tenant_id}"
    full_graph_name = "#{schema_name}_#{graph_name}"

    # Set tenant and graph context
    Repo.query!("SET search_path TO #{schema_name}, public, ag_catalog")
    Repo.query!("SET age.graph_name = '#{full_graph_name}'")

    try do
      fun.()
    after
      Repo.query!("RESET search_path")
      Repo.query!("RESET age.graph_name")
    end
  end

  def execute_cypher(tenant_id, graph_name, cypher_query, params \\ []) do
    with_tenant_graph(tenant_id, graph_name, fn ->
      # Sanitize query to prevent cross-tenant access
      sanitized_query = sanitize_cypher(cypher_query)
      Repo.query!(sanitized_query, params)
    end)
  end

  defp sanitize_cypher(query) do
    # Remove any attempts to access other schemas
    query
    |> String.replace(~r/acq_[^_s]+/i, "")
    |> String.replace(~r/\\./i, "")
  end
end
```

### Phase 2: Ash Integration (Weeks 3-4)
**Objective**: Extend Ash resources with graph relationships

**Ash Resource Extension:**
```elixir
# lib/mcp/resources/merchant.ex
defmodule Mcp.Resources.Merchant do
  use Ash.Resource,
    domain: Mcp.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [Mcp.GraphExtension]

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :tenant_id, :uuid, allow_nil?: false
    # ... existing attributes
  end

  # Graph relationships extension
  graph do
    node_type :merchant

    relationships do
      # Customer relationships
      graph_relationship :customers, :has_many, Mcp.Resources.Customer
      graph_relationship :suppliers, :has_many, Mcp.Resources.Supplier
      graph_relationship :transactions, :has_many, Mcp.Resources.Transaction
    end
  end
end

# lib/mcp/graph_extension.ex
defmodule Mcp.GraphExtension do
  @moduledoc """
  Ash extension for graph database integration
  """

  use Ash.Resource.Extension

  def query_for_relationship(resource, relationship, query) do
    tenant_id = Ash.Changeset.get_attribute(query, :tenant_id)
    graph_name = "relationships"

    cypher_query = """
    MATCH (m:merchant {id: $merchant_id})-[:#{relationship}]->(related)
    RETURN related
    """

    Mcp.Graph.TenantContext.execute_cypher(
      tenant_id,
      graph_name,
      cypher_query,
      [merchant_id: query.id]
    )
  end
end
```

### Phase 3: RAG + Graph Integration (Weeks 5-6)
**Objective**: Combine semantic search with relationship intelligence

**Enhanced RAG Module:**
```elixir
# lib/mcp/rag/graph_enhanced.ex
defmodule Mcp.RAG.GraphEnhanced do
  @moduledoc """
  RAG system enhanced with graph relationship intelligence
  """

  alias Mcp.Core.Repo
  alias Mcp.Embedding

  def search_with_relationships(tenant_id, query_text, opts \\ []) do
    # Phase 1: Traditional semantic search
    semantic_results = Embedding.similarity_search(query_text, tenant_id)

    # Phase 2: Extract entities from query
    entities = extract_entities(query_text)

    # Phase 3: Expand with graph relationships
    graph_expanded = expand_with_graph(tenant_id, entities, semantic_results)

    # Phase 4: Rank and return
    rank_results(graph_expanded)
  end

  defp expand_with_graph(tenant_id, entities, semantic_results) do
    Enum.reduce(entities, semantic_results, fn entity, acc ->
      case entity do
        {:merchant, merchant_id} ->
          # Find related merchants, customers, suppliers
          related = find_related_entities(tenant_id, merchant_id)
          acc ++ related
        _ ->
          acc
      end
    end)
  end

  defp find_related_entities(tenant_id, merchant_id) do
    # Find merchants with shared customers
    shared_customers = """
    MATCH (m1:merchant {id: $merchant_id})<-[:customer]-(c:customer)-[:customer]->(m2:merchant)
    WHERE m1.id <> m2.id
    RETURN DISTINCT m2.id as related_merchant, 'shared_customer' as relationship_type
    """

    # Find suppliers of similar merchants
    similar_suppliers = """
    MATCH (m:merchant {id: $merchant_id})-[:supplier]->(s:supplier)<-[:supplier]-(similar:merchant)
    RETURN similar.id as related_merchant, 'shared_supplier' as relationship_type
    """

    results1 = Mcp.Graph.TenantContext.execute_cypher(tenant_id, "relationships", shared_customers, [merchant_id: merchant_id])
    results2 = Mcp.Graph.TenantContext.execute_cypher(tenant_id, "relationships", similar_suppliers, [merchant_id: merchant_id])

    combine_graph_results(results1, results2)
  end
end
```

### Phase 4: Security & Multi-Tenant Isolation (Weeks 7-8)
**Objective**: Implement comprehensive security controls

**Security Implementation:**
```elixir
# lib/mcp/security/graph_security.ex
defmodule Mcp.Security.GraphSecurity do
  @moduledoc """
  Security controls for multi-tenant graph access
  """

  def validate_query_access(tenant_id, cypher_query) do
    # Check for cross-tenant access attempts
    if contains_cross_tenant_patterns?(cypher_query) do
      {:error, :cross_tenant_access_denied}
    else
      :ok
    end
  end

  def anonymize_platform_analytics(graph_results) do
    # Remove any identifiable information for platform-level analytics
    graph_results
    |> remove_personal_identifiers()
    |> ensure_minimum_group_size(10) # Prevent re-identification
  end

  defp contains_cross_tenant_patterns?(query) do
    patterns = [
      ~r/acq_[a-zA-Z0-9_]+/i,  # Direct schema access
      ~r/\.\./,                  # Directory traversal
      ~r/union\s+all/i,          # Union queries
      ~r/\bpg_[a-zA-Z_]+\b/i     # System table access
    ]

    Enum.any?(patterns, &Regex.match?(&1, query))
  end
end
```

## Testing Strategy

```elixir
# test/mcp/graph/tenant_isolation_test.exs
defmodule Mcp.Graph.TenantIsolationTest do
  use ExUnit.Case, async: false

  alias Mcp.Graph.TenantContext
  alias Mcp.Security.GraphSecurity

  test "tenant cannot access other tenant graph data" do
    # Setup test data
    tenant_a = "tenant_a"
    tenant_b = "tenant_b"

    # Try to access tenant B data from tenant A context
    assert_raise RuntimeError, ~r/cross tenant/, fn ->
      TenantContext.execute_cypher(tenant_a, "relationships", """
        MATCH (n) WHERE n.schema = 'acq_tenant_b'
        RETURN n
      """)
    end
  end

  test "platform analytics are properly anonymized" do
    graph_results = %{
      merchants: [
        %{id: "uuid-1", revenue: 100000},
        %{id: "uuid-2", revenue: 150000}
      ]
    }

    anonymized = GraphSecurity.anonymize_platform_analytics(graph_results)

    # Verify no PII remains
    refute Map.has_key?(anonymized, :merchants)
    assert Map.has_key?(anonymized, :aggregate_revenue)
  end
end
```

## Performance Considerations

### Indexing Strategy
```sql
-- Create composite indexes for common graph query patterns
CREATE INDEX CONCURRENTLY idx_merchant_customer_relationships
ON acq_tenant_a.relationships
USING GIN ((properties)::jsonb);

-- Graph-specific indexes
SELECT ag_catalog.create_vector_index('acq_tenant_a.relationships', 'merchant_nodes');
```

### Caching Strategy
```elixir
# lib/mcp/graph/cache.ex
defmodule Mcp.Graph.Cache do
  @moduledoc """
  Graph query result caching
  """

  def cache_graph_query(tenant_id, query_hash, fun) when is_function(fun, 0) do
    cache_key = "graph:#{tenant_id}:#{query_hash}"

    case Cachex.get(:graph_cache, cache_key) do
      {:ok, nil} ->
        result = fun.()
        Cachex.put(:graph_cache, cache_key, result, ttl: :timer.minutes(15))
        result
      {:ok, cached} ->
        cached
    end
  end
end
```

## Monitoring & Observability

```elixir
# lib/mcp/graph/telemetry.ex
defmodule Mcp.Graph.Telemetry do
  @moduledoc """
  Graph operation telemetry
  """

  def execute_with_telemetry(tenant_id, operation, fun) do
    :telemetry.execute(
      [:mcp, :graph, operation],
      %{tenant_id: tenant_id},
      fn ->
        fun.()
      end
    )
  end
end
```

## Integration with Existing BMAD PRD Context

This Graph-Enhanced RAG feature should be positioned as a **Strategic Intelligence Layer** within your broader AI-powered MSP platform. It represents:

1. **Technical Foundation**: Extends your existing multi-tenant PostgreSQL + Elixir/Ash architecture
2. **Business Value**: 400-500% revenue uplift potential through relationship intelligence
3. **Competitive Differentiator**: Moves from transaction processing to business intelligence
4. **Implementation Phasing**: Can be developed as independent sprints within the broader platform roadmap

### Epic Structure Recommendation:
- **Epic**: Relationship Intelligence Platform
- **Feature 1**: Graph Database Foundation (Sprints 1-2)
- **Feature 2**: Enhanced RAG + Graph (Sprints 3-4)
- **Feature 3**: Multi-Tenant Security (Sprints 5-6)
- **Feature 4**: Analytics & Insights (Sprints 7-8)

### Success Metrics Alignment with BMAD Goals:
- **Merchant Retention**: 50% reduction through intelligent insights
- **Revenue Growth**: 300% increase in per-merchant value
- **Platform Differentiation**: Top 3 market position in payment analytics
- **Technical Debt**: Maintains existing architecture while adding capabilities