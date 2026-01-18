defmodule Mcp.Graph.IsolationTest do
  @moduledoc """
  Tests for graph isolation and tenant context switching in Apache AGE.
  """
  use Mcp.DataCase, async: true

  alias Mcp.Graph.TenantContext

  describe "graph isolation" do
    test "graph context is correctly set for different tenants" do
      # This test might fail if AGE is not installed, so we wrap it or check for extension
      case Repo.query("SELECT 1 FROM pg_extension WHERE extname = 'age'") do
        {:ok, %{num_rows: 1}} ->
          tenant_a = insert(:tenant, slug: "tenanta", company_schema: "acq_tenanta")
          tenant_b = insert(:tenant, slug: "tenantb", company_schema: "acq_tenantb")

          # Verify context switching for tenant_a
          TenantContext.with_tenant_graph(tenant_a.slug, "test", fn ->
            {:ok, res} = Repo.query("SHOW age.graph_name")
            assert [["acq_tenanta_test"]] == res.rows
          end)

          # Verify context switching for tenant_b
          TenantContext.with_tenant_graph(tenant_b.slug, "test", fn ->
            {:ok, res} = Repo.query("SHOW age.graph_name")
            assert [["acq_tenantb_test"]] == res.rows
          end)

        _ ->
          IO.puts("Skipping AGE specific isolation test - extension not found")
      end
    end
  end
end
