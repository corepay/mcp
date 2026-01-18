defmodule Mcp.Graph.Query do
  @moduledoc """
  A manual resource to provide Graph RAG capabilities as AshAi tools.
  """
  use Ash.Resource,
    domain: Mcp.Graph,
    extensions: [AshAi]

  resource do
    require_primary_key? false
  end

  actions do
    read :traversal do
      description "Perform a graph traversal starting from a specific node."
      argument :start_node_id, :string, allow_nil?: false
      argument :relationship_type, :string, allow_nil?: true
      argument :depth, :integer, default: 2

      manual fn query, _opts, _context ->
        tenant_slug = Mcp.Graph.Notifier.get_tenant_slug(query.context.tenant)

        rel_clause =
          if query.arguments.relationship_type do
            "[:#{query.arguments.relationship_type}*1..#{query.arguments.depth}]"
          else
            "[*1..#{query.arguments.depth}]"
          end

        cypher = """
        MATCH (start {id: $start_id})-#{rel_clause}->(related)
        RETURN start, related
        LIMIT 50
        """

        case Mcp.Graph.TenantContext.execute_cypher(tenant_slug, "graph", cypher,
               start_id: query.arguments.start_node_id
             ) do
          results when is_list(results) ->
            result_text =
              "Graph Traversal Results:\n" <> Enum.map_join(results, "\n", &inspect/1)

            {:ok, [struct(__MODULE__, result: result_text)]}

          {:error, error} ->
            {:error, error}
        end
      end
    end

    read :find_connected_risks do
      description "Find potentially connected risky entities in the graph for a given merchant."
      argument :merchant_id, :string, allow_nil?: false

      manual fn query, _opts, _context ->
        tenant_slug = Mcp.Graph.Notifier.get_tenant_slug(query.context.tenant)

        cypher = """
        MATCH (m:Merchant {id: $merchant_id})-[*1..3]-(other:Merchant)
        WHERE other.risk_level IN ['high', 'medium']
        RETURN other.business_name as name, other.risk_level as risk, other.id as id
        """

        case Mcp.Graph.TenantContext.execute_cypher(tenant_slug, "graph", cypher,
               merchant_id: query.arguments.merchant_id
             ) do
          results when is_list(results) ->
            result_text =
              "Connected Risks Found:\n" <> Enum.map_join(results, "\n", &inspect/1)

            {:ok, [struct(__MODULE__, result: result_text)]}

          {:error, error} ->
            {:error, error}
        end
      end
    end
  end

  attributes do
    attribute :result, :string do
      public? true
    end
  end
end
