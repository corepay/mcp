defmodule Mcp.Platform.Graph do
  @moduledoc """
  Manages Graph operations (Apache AGE) for relationship analysis.
  """

  alias Mcp.Repo
  alias Mcp.Infrastructure.Context

  @tenant_schema_prefix "acq_"

  def create_graph(tenant_schema_name, graph_name \\ "tenant_graph") do
    _schema_name = @tenant_schema_prefix <> tenant_schema_name

    Context.with_tenant_context(tenant_schema_name, fn ->
      # SECURITY: graph_name should be validated
      query = "SELECT * FROM ag_catalog.create_graph($1)"
      Repo.query(query, [graph_name])
    end)
  end

  def execute_cypher_query(tenant_schema_name, cypher_query, graph_name \\ "tenant_graph") do
    _schema_name = @tenant_schema_prefix <> tenant_schema_name

    Context.with_tenant_context(tenant_schema_name, fn ->
      # Load AGE extension with proper search path
      Repo.query("LOAD 'age'; SET search_path TO ag_catalog, public;")

      # SECURITY: graph_name must be a valid identifier.
      if not Regex.match?(~r/^[a-zA-Z0-9_]+$/, graph_name) do
        raise ArgumentError, "Invalid graph name: #{graph_name}"
      end

      # Execute Cypher query with proper result handling
      # Note: graph_name and query must be literals.
      # We use dollar quoting for the query to handle quotes within it.
      # SECURITY: cypher_query must be trusted!
      # We select 1 to avoid agtype decoding issues in Postgrex for now
      query =
        "SELECT 1 FROM ag_catalog.cypher('#{graph_name}', $$#{cypher_query}$$) AS (result ag_catalog.agtype);"

      Repo.query(query)
    end)
  end

  def find_similar_merchants(tenant_schema_name, merchant_id, _similarity_threshold \\ 0.8) do
    # SECURITY: merchant_id should be validated or parameterized if possible within cypher
    # Note: AGE cypher parameterization can be tricky, ensuring merchant_id is safe is key.
    # Assuming merchant_id is a UUID or integer, basic validation helps.
    cypher_query = """
    MATCH (m:Merchant)-[:SIMILAR_TO]->(other:Merchant)
    WHERE id(m) = '#{merchant_id}'
    RETURN other, similarity
    """

    execute_cypher_query(tenant_schema_name, cypher_query)
  end

  def create_merchant_relationship_graph(tenant_schema_name) do
    cypher_query = """
    CREATE CONSTRAINT merchant_id IF NOT EXISTS
    FOR (m:Merchant) REQUIRE m.id IS NOT NULL;

    CREATE INDEX merchant_name_index IF NOT EXISTS
    FOR (m:Merchant) ON (m.name);

    CREATE CONSTRAINT mid_id IF NOT EXISTS
    FOR (mid:MID) REQUIRE mid.id IS NOT NULL;
    """

    execute_cypher_query(tenant_schema_name, cypher_query)
  end
end
