defmodule Mcp.Infrastructure.ContextTest do
  use Mcp.DataCase, async: false

  alias Mcp.Infrastructure.Context
  alias Mcp.Infrastructure.TenantManager

  @test_tenant_schema "test_context_manager"

  describe "tenant context switching" do
    setup do
      # Create test schema
      if not TenantManager.tenant_schema_exists?(@test_tenant_schema) do
        {:ok, _} = TenantManager.create_tenant_schema(@test_tenant_schema)
      end

      # Create a test table in the tenant schema
      Context.with_tenant_context(@test_tenant_schema, fn ->
        Repo.query("""
          CREATE TABLE IF NOT EXISTS test_data (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_data TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT NOW()
          )
        """)
      end)

      on_exit(fn ->
        TenantManager.drop_tenant_schema(@test_tenant_schema)
      end)

      :ok
    end

    test "executes operations in tenant context" do
      result =
        Context.with_tenant_context(@test_tenant_schema, fn ->
          Repo.query("INSERT INTO test_data (tenant_data) VALUES ($1) RETURNING id", ["test_data"])
        end)

      assert {:ok, %{rows: [[_id]]}} = result
    end

    test "isolates data between schemas" do
      # Insert data in tenant schema
      Context.with_tenant_context(@test_tenant_schema, fn ->
        Repo.query("INSERT INTO test_data (tenant_data) VALUES ($1)", ["tenant_data"])
      end)

      # Try to access from public schema - should fail
      {:error, _} = Repo.query("SELECT * FROM test_data")
    end

    test "switches search path correctly" do
      Context.with_tenant_context(@test_tenant_schema, fn ->
        # Verify we're in the correct schema context
        {:ok, %{rows: [[search_path]]}} = Repo.query("SHOW search_path")
        assert String.contains?(search_path, "acq_#{@test_tenant_schema}")
      end)
    end
  end

  # We are NOT porting the isolated helpers yet as they are part of the facade removal strategy.
  # If we decide to keep them, we will move them to Context later.
  # For now, we focus on the core context switching capability.
end
