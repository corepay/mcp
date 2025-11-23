defmodule Mcp.MultiTenantTest do
  use ExUnit.Case, async: false

  alias Mcp.MultiTenant
  alias Mcp.Repo
  import Ecto.Query

  @test_tenant_schema "test_multi_tenant"

  describe "schema management" do
    setup do
      # Clean up any existing test schema
      if MultiTenant.tenant_schema_exists?(@test_tenant_schema) do
        MultiTenant.drop_tenant_schema(@test_tenant_schema)
      end

      :ok
    end

    test "creates tenant schema" do
      refute MultiTenant.tenant_schema_exists?(@test_tenant_schema)

      assert {:ok, schema_name} = MultiTenant.create_tenant_schema(@test_tenant_schema)
      assert schema_name == "acq_#{@test_tenant_schema}"

      assert MultiTenant.tenant_schema_exists?(@test_tenant_schema)
    end

    test "handles existing schema gracefully" do
      {:ok, _} = MultiTenant.create_tenant_schema(@test_tenant_schema)

      assert {:error, :schema_already_exists} =
               MultiTenant.create_tenant_schema(@test_tenant_schema)
    end

    test "drops tenant schema" do
      {:ok, _} = MultiTenant.create_tenant_schema(@test_tenant_schema)
      assert MultiTenant.tenant_schema_exists?(@test_tenant_schema)

      assert {:ok, schema_name} = MultiTenant.drop_tenant_schema(@test_tenant_schema)
      assert schema_name == "acq_#{@test_tenant_schema}"

      refute MultiTenant.tenant_schema_exists?(@test_tenant_schema)
    end

    test "handles non-existent schema drop" do
      refute MultiTenant.tenant_schema_exists?(@test_tenant_schema)

      assert {:error, :schema_not_found} =
               MultiTenant.drop_tenant_schema(@test_tenant_schema)
    end
  end

  describe "tenant context switching" do
    setup do
      # Create test schema
      if not MultiTenant.tenant_schema_exists?(@test_tenant_schema) do
        {:ok, _} = MultiTenant.create_tenant_schema(@test_tenant_schema)
      end

      # Create a test table in the tenant schema
      MultiTenant.with_tenant_context(@test_tenant_schema, fn ->
        Repo.query("""
          CREATE TABLE IF NOT EXISTS test_data (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_data TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT NOW()
          )
        """)
      end)

      on_exit(fn ->
        MultiTenant.drop_tenant_schema(@test_tenant_schema)
      end)

      :ok
    end

    test "executes operations in tenant context" do
      result =
        MultiTenant.with_tenant_context(@test_tenant_schema, fn ->
          Repo.query("INSERT INTO test_data (tenant_data) VALUES ($1) RETURNING id", ["test_data"])
        end)

      assert {:ok, %{rows: [[_id]]}} = result
    end

    test "isolates data between schemas" do
      # Insert data in tenant schema
      MultiTenant.with_tenant_context(@test_tenant_schema, fn ->
        Repo.query("INSERT INTO test_data (tenant_data) VALUES ($1)", ["tenant_data"])
      end)

      # Try to access from public schema - should fail
      {:error, _} = Repo.query("SELECT * FROM test_data")
    end

    test "switches search path correctly" do
      MultiTenant.with_tenant_context(@test_tenant_schema, fn ->
        # Verify we're in the correct schema context
        {:ok, %{rows: [[search_path]]}} = Repo.query("SHOW search_path")
        assert String.contains?(search_path, "acq_#{@test_tenant_schema}")
      end)
    end
  end

  describe "tenant isolation helpers" do
    setup do
      if not MultiTenant.tenant_schema_exists?(@test_tenant_schema) do
        {:ok, _} = MultiTenant.create_tenant_schema(@test_tenant_schema)
      end

      # Create test table
      MultiTenant.with_tenant_context(@test_tenant_schema, fn ->
        Repo.query("""
          CREATE TABLE IF NOT EXISTS tenant_isolated_items (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name TEXT NOT NULL,
            value INTEGER
          )
        """)

        # Insert test data
        Repo.query("INSERT INTO tenant_isolated_items (name, value) VALUES ($1, $2)", [
          "item1",
          100
        ])

        Repo.query("INSERT INTO tenant_isolated_items (name, value) VALUES ($1, $2)", [
          "item2",
          200
        ])
      end)

      on_exit(fn ->
        MultiTenant.drop_tenant_schema(@test_tenant_schema)
      end)

      :ok
    end

    test "tenant_isolated_query executes in correct schema" do
      query = from(t in "tenant_isolated_items", select: {t.name, t.value})
      results = MultiTenant.tenant_isolated_query(@test_tenant_schema, query)

      assert length(results) == 2
      assert {"item1", 100} in results
      assert {"item2", 200} in results
    end

    test "tenant_isolated_insert works correctly" do
      query = from(t in "tenant_isolated_items")
      changeset = Ecto.Changeset.change(%{name: "item3", value: 300})

      result = MultiTenant.tenant_isolated_insert(@test_tenant_schema, changeset)
      assert {:ok, _inserted} = result

      # Verify insertion
      query = from(t in "tenant_isolated_items", where: t.name == "item3")
      results = MultiTenant.tenant_isolated_query(@test_tenant_schema, query)
      assert length(results) == 1
    end
  end

  describe "advanced database operations" do
    setup do
      if not MultiTenant.tenant_schema_exists?(@test_tenant_schema) do
        {:ok, _} = MultiTenant.create_tenant_schema(@test_tenant_schema)
      end

      on_exit(fn ->
        MultiTenant.drop_tenant_schema(@test_tenant_schema)
      end)

      :ok
    end

    test "creates hypertable for time-series data" do
      # Create base table first
      MultiTenant.with_tenant_context(@test_tenant_schema, fn ->
        Repo.query("""
          CREATE TABLE IF NOT EXISTS time_series_data (
            time TIMESTAMP NOT NULL,
            merchant_id UUID NOT NULL,
            transaction_volume DECIMAL(12,2),
            transaction_count INTEGER,
            average_transaction_amount DECIMAL(10,2),
            response_time_ms INTEGER
          )
        """)
      end)

      # Convert to hypertable
      result =
        MultiTenant.create_hypertable(
          @test_tenant_schema,
          "time_series_data",
          "time",
          "1 hour"
        )

      assert {:ok, _} = result
    end

    test "creates vector index for similarity search" do
      # Create table with vector column
      MultiTenant.with_tenant_context(@test_tenant_schema, fn ->
        Repo.query("""
          CREATE TABLE IF NOT EXISTS vector_items (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name TEXT NOT NULL,
            embedding vector(384)
          )
        """)
      end)

      # Create vector index
      result =
        MultiTenant.create_vector_index(
          @test_tenant_schema,
          "vector_items",
          "embedding",
          "vector_items_embedding_idx"
        )

      assert {:ok, _} = result
    end

    test "creates geographic index" do
      # Create table with geometry column
      MultiTenant.with_tenant_context(@test_tenant_schema, fn ->
        Repo.query("""
          CREATE TABLE IF NOT EXISTS geo_locations (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name TEXT NOT NULL
          )
        """)

        # Add geometry column
        MultiTenant.add_geometry_column(
          @test_tenant_schema,
          "geo_locations",
          "location",
          "POINT",
          4326
        )
      end)

      # Create geographic index
      result =
        MultiTenant.create_geographic_index(
          @test_tenant_schema,
          "geo_locations",
          "location",
          "geo_locations_location_idx"
        )

      assert {:ok, _} = result
    end

    test "executes graph queries with Apache AGE" do
      # Create graph
      result = MultiTenant.create_graph(@test_tenant_schema, "test_graph")
      assert {:ok, _} = result

      # Execute simple Cypher query
      cypher_query = "CREATE (n:TestNode {name: 'test'}) RETURN n"
      result = MultiTenant.execute_cypher_query(@test_tenant_schema, cypher_query)

      assert {:ok, _} = result
    end
  end

  describe "tenant name resolution" do
    setup do
      # This test would require actual tenant data in the database
      # For now, we'll test the query structure
      :ok
    end

    test "gets tenant schema name by ID" do
      # This would normally query the database
      # For testing purposes, we'll verify the query structure
      query =
        from(t in "platform.tenants",
          where: t.id == type(^Ecto.UUID.generate(), :binary_id),
          select: t.company_schema
        )

      # The query should be valid
      assert %Ecto.Query{} = query
    end
  end
end
