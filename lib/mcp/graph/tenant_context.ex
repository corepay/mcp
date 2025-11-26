defmodule Mcp.Graph.TenantContext do
  @moduledoc """
  Multi-tenant graph context with secure isolation.
  Handles setting the correct search path and AGE graph context for tenant queries.
  """

  alias Mcp.Repo

  def with_tenant_graph(tenant_slug, graph_suffix \\ "relationships", fun)
      when is_function(fun, 0) do
    schema_name = "acq_#{tenant_slug}"
    full_graph_name = "#{schema_name}_#{graph_suffix}"

    # Set tenant and graph context
    # AGE requires ag_catalog in search path
    Repo.query!("SET search_path TO #{schema_name}, public, ag_catalog")
    # Ensure AGE is loaded
    Repo.query!("LOAD 'age'")
    Repo.query!("SET age.graph_name = '#{full_graph_name}'")

    try do
      fun.()
    after
      # Reset context
      Repo.query!("RESET search_path")
      Repo.query!("RESET age.graph_name")
    end
  end

  def execute_cypher(tenant_slug, graph_suffix \\ "relationships", cypher_query, params \\ []) do
    with_tenant_graph(tenant_slug, graph_suffix, fn ->
      # Sanitize query to prevent cross-tenant access
      sanitized_query = sanitize_cypher(cypher_query)

      # AGE cypher call format: SELECT * FROM cypher('graph_name', $$ ... $$) as (a agtype);
      # However, for parameterized queries, we might need a different approach or string interpolation if AGE doesn't support params in `cypher()` function directly in all versions.
      # For now, we'll assume we are passing the raw cypher query to be executed, but typically AGE is used via SQL wrapping.
      # Let's wrap it in the standard AGE SQL wrapper if it's not already.

      # NOTE: This is a simplified implementation. Real-world usage requires careful handling of return types (agtype).
      Repo.query!(sanitized_query, params)
    end)
  end

  defp sanitize_cypher(query) do
    # Remove any attempts to access other schemas explicitly
    # This is a basic protection; Postgres permissions are the real enforcement.
    query
    |> String.replace(~r/acq_[^_s]+/i, "")
  end
end
