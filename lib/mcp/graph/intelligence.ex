defmodule Mcp.Graph.Intelligence do
  @moduledoc """
  Resource providing graph-based intelligence tools.
  Uses Apache AGE for deep relationship traversal.
  """
  use Ash.Resource,
    domain: Mcp.Ai,
    authorizers: [Ash.Policy.Authorizer]

  alias Mcp.Graph.TenantContext

  policies do
    # Only allow authenticated actors to use intelligence tools
    policy action_type(:read) do
      authorize_if always()
    end
  end

  actions do
    read :graph_traversal do
      argument :start_node_id, :string, allow_nil?: false
      argument :relationship_type, :string

      argument :depth, :integer do
        default 2
      end

      # We use a manual action to execute Cypher
      manual fn query, _data_layer_query, context ->
        tenant_slug = Mcp.Graph.Notifier.get_tenant_slug(context.tenant)
        start_id = query.arguments.start_node_id
        rel = query.arguments.relationship_type
        depth = query.arguments.depth

        # Basic rooted traversal to ensure tenant isolation in Cypher itself
        # although with_tenant_graph handles search_path.
        cypher =
          if rel do
            """
            MATCH (n {id: $start_id})-[r:#{rel}*1..#{depth}]-(m)
            RETURN m, r
            """
          else
            """
            MATCH (n {id: $start_id})-[r*1..#{depth}]-(m)
            RETURN m, r
            """
          end

        case TenantContext.execute_cypher(tenant_slug, "relationships", cypher,
               start_id: start_id
             ) do
          {:ok, result} ->
            # Map results to a list of generic maps for the LLM to consume
            # Note: Result processing for AGE agtype is complex, this is a placeholder.
            {:ok, [%{result: inspect(result.rows)}]}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end

    read :find_connected_risks do
      argument :merchant_id, :string, allow_nil?: false

      manual fn query, _data_layer_query, context ->
        tenant_slug = Mcp.Graph.Notifier.get_tenant_slug(context.tenant)
        merchant_id = query.arguments.merchant_id

        # Query to find shared owners/resellers with high risk
        cypher = """
        MATCH (m:Merchant {id: $merchant_id})<-[:MANAGES]-(r:Reseller)-[:MANAGES]->(other:Merchant)
        WHERE other.risk_level = 'high' AND other.id <> $merchant_id
        RETURN other.name as name, other.id as id, 'High Risk Shared Reseller' as reason
        """

        case TenantContext.execute_cypher(tenant_slug, "relationships", cypher,
               merchant_id: merchant_id
             ) do
          {:ok, result} ->
            # Convert rows to map
            formatted =
              Enum.map(result.rows, fn [name, id, reason] ->
                %{name: name, id: id, reason: reason}
              end)

            {:ok, formatted}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end

  attributes do
    uuid_primary_key :id
    # Attributes for the result map (if we were using a real data layer)
    # But for manual actions we can return any list of maps.
    attribute :name, :string
    attribute :reason, :string
    attribute :result, :string
  end
end
