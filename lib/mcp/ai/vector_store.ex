defmodule Mcp.AI.VectorStore do
  @moduledoc """
  Manages AI vector operations (pgvector) for similarity search and recommendations.
  """

  alias Mcp.Repo
  alias Mcp.Infrastructure.Context

  @tenant_schema_prefix "acq_"

  def create_vector_index(tenant_schema_name, table_name, column_name, index_name \\ nil) do
    _schema_name = @tenant_schema_prefix <> tenant_schema_name
    index_name = index_name || "#{table_name}_#{column_name}_vector_idx"

    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      CREATE INDEX #{index_name}
      ON #{table_name}
      USING ivfflat (#{column_name} vector_cosine_ops)
      WITH (lists = 100)
      """

      Repo.query(query)
    end)
  end

  def create_hnsw_index(tenant_schema_name, table_name, column_name, index_name \\ nil) do
    _schema_name = @tenant_schema_prefix <> tenant_schema_name
    index_name = index_name || "#{table_name}_#{column_name}_hnsw_idx"

    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      CREATE INDEX #{index_name}
      ON #{table_name}
      USING hnsw (#{column_name} vector_cosine_ops)
      WITH (m = 16, ef_construction = 64)
      """

      Repo.query(query)
    end)
  end

  def vector_similarity_search(
        tenant_schema_name,
        table_name,
        column_name,
        query_vector,
        limit \\ 10
      ) do
    _schema_name = @tenant_schema_prefix <> tenant_schema_name

    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT *, 1 - (#{column_name} <=> $1) as similarity
      FROM #{table_name}
      ORDER BY #{column_name} <=> $1
      LIMIT $2
      """

      Repo.query(query, [query_vector, limit])
    end)
  end

  def ai_merchant_recommendations(tenant_schema_name, merchant_vector, limit \\ 5) do
    vector_similarity_search(
      tenant_schema_name,
      "merchants",
      "ai_risk_score",
      merchant_vector,
      limit
    )
  end

  def ai_mid_routing_optimization(tenant_schema_name, transaction_vector, limit \\ 3) do
    vector_similarity_search(
      tenant_schema_name,
      "mids",
      "processing_vector",
      transaction_vector,
      limit
    )
  end
end
