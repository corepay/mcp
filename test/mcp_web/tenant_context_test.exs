defmodule McpWeb.TenantContextTest do
  use ExUnit.Case, async: false
  use Plug.Test

  import Mox

  alias Mcp.Cache.TenantIsolation
  alias Mcp.Platform.Tenant
  alias Mcp.Repo
  alias McpWeb.TenantContext
  alias McpWeb.TenantRouting

  setup do
    # Start Mox
    Mox.verify_on_exit!()

    # Test tenant data
    test_tenant = %Tenant{
      id: "123e4567-e89b-12d3-a456-426614174000",
      slug: "test-tenant",
      name: "Test Company",
      company_schema: "test_tenant",
      subdomain: "test",
      status: :active,
      plan: :professional
    }

    {:ok, %{test_tenant: test_tenant}}
  end

  describe "init/1" do
    test "initializes with default options" do
      opts = TenantContext.init([])

      assert Keyword.get(opts, :skip_tenant_context) == false
      assert Keyword.get(opts, :required_for_routes) == []
    end

    test "merges custom options with defaults" do
      opts = TenantContext.init(skip_tenant_context: true, required_for_routes: ["/api"])

      assert Keyword.get(opts, :skip_tenant_context) == true
      assert Keyword.get(opts, :required_for_routes) == ["/api"]
    end
  end

  describe "call/2" do
    test "continues without tenant context when no tenant found" do
      # Mock TenantRouting to return no tenant
      expect(TenantRouting, :get_current_tenant, fn _conn -> nil end)

      conn =
        conn(:get, "/")
        |> TenantContext.call([])

      refute conn.assigns[:tenant_context_active]
      refute conn.assigns[:current_tenant]
    end

    test "sets up tenant context for active tenant", %{test_tenant: tenant} do
      # Mock dependencies
      expect(TenantRouting, :get_current_tenant, fn _conn -> tenant end)

      # Mock successful database context establishment
      expect(
        Repo,
        :query,
        fn "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'acq_test_tenant'" ->
          {:ok, %{rows: [["acq_test_tenant"]]}}
        end
      )

      expect(Repo, :get_search_path, fn -> "public" end)

      expect(
        Repo,
        :query,
        fn "SET search_path TO acq_test_tenant, public, platform, shared, ag_catalog" ->
          {:ok, %{rows: []}}
        end
      )

      conn =
        conn(:get, "/")
        |> TenantContext.call([])

      assert conn.assigns[:tenant_context_active]
      assert conn.private[:tenant_context_set]
      assert conn.private[:tenant_database_context]
      assert conn.assigns[:tenant_cache_prefix] == "tenant:#{tenant.id}"
    end

    test "handles suspended tenant appropriately", %{test_tenant: tenant} do
      suspended_tenant = %{tenant | status: :suspended}

      expect(TenantRouting, :get_current_tenant, fn _conn -> suspended_tenant end)

      conn =
        conn(:get, "/")
        |> TenantContext.call([])

      assert conn.status == 403
      assert conn.state == :sent
      assert conn.resp_body =~ "Account Suspended"
    end

    test "handles canceled tenant appropriately", %{test_tenant: tenant} do
      canceled_tenant = %{tenant | status: :canceled}

      expect(TenantRouting, :get_current_tenant, fn _conn -> canceled_tenant end)

      conn =
        conn(:get, "/")
        |> TenantContext.call([])

      assert conn.status == 403
      assert conn.state == :sent
      assert conn.resp_body =~ "Account Canceled"
    end

    test "handles deleted tenant appropriately", %{test_tenant: tenant} do
      deleted_tenant = %{tenant | status: :deleted}

      expect(TenantRouting, :get_current_tenant, fn _conn -> deleted_tenant end)

      conn =
        conn(:get, "/")
        |> TenantContext.call([])

      assert conn.status == 404
      assert conn.state == :sent
      assert conn.resp_body =~ "Account Not Found"
    end
  end

  describe "with_tenant_context/2" do
    test "executes function without tenant context when no tenant" do
      expect(TenantRouting, :get_current_tenant, fn _conn -> nil end)

      conn = conn(:get, "/")

      result =
        TenantContext.with_tenant_context(conn, fn ->
          "no_tenant_result"
        end)

      assert result == "no_tenant_result"
    end

    test "executes function within tenant database context", %{test_tenant: tenant} do
      expect(TenantRouting, :get_current_tenant, fn _conn -> tenant end)

      expect(Repo, :with_tenant_schema, fn "test_tenant", fun ->
        fun.()
      end)

      expect(Repo, :query, fn "SELECT current_schema()" ->
        {:ok, %{rows: [["acq_test_tenant"]]}}
      end)

      conn = conn(:get, "/")

      result =
        TenantContext.with_tenant_context(conn, fn ->
          "tenant_result"
        end)

      assert result == "tenant_result"
    end

    test "raises error for inactive tenant context", %{test_tenant: tenant} do
      inactive_tenant = %{tenant | status: :suspended}

      expect(TenantRouting, :get_current_tenant, fn _conn -> inactive_tenant end)

      conn = conn(:get, "/")

      assert_raise ArgumentError,
                   "Cannot execute operations in inactive tenant context: suspended",
                   fn ->
                     TenantContext.with_tenant_context(conn, fn ->
                       "should_not_execute"
                     end)
                   end
    end
  end

  describe "with_tenant_context/1" do
    test "executes function for specific tenant by schema" do
      test_tenant = %Tenant{
        id: "test-id",
        company_schema: "test_schema",
        status: :active
      }

      expect(Tenant, :read!, fn %{company_schema: "test_schema"} ->
        [test_tenant]
      end)

      expect(Repo, :with_tenant_schema, fn "test_schema", fun ->
        fun.()
      end)

      expect(Repo, :query, fn "SELECT current_schema()" ->
        {:ok, %{rows: [["acq_test_schema"]]}}
      end)

      result =
        TenantContext.with_tenant_context("acq_test_schema", fn ->
          "schema_result"
        end)

      assert result == "schema_result"
    end

    test "executes function for specific tenant by ID" do
      test_tenant = %Tenant{
        id: "test-id",
        company_schema: "test_schema",
        status: :active
      }

      expect(Tenant, :read!, fn %{id: "test-id"} ->
        [test_tenant]
      end)

      expect(Repo, :with_tenant_schema, fn "test_schema", fun ->
        fun.()
      end)

      expect(Repo, :query, fn "SELECT current_schema()" ->
        {:ok, %{rows: [["acq_test_schema"]]}}
      end)

      result =
        TenantContext.with_tenant_context("test-id", fn ->
          "id_result"
        end)

      assert result == "id_result"
    end

    test "raises error for non-existent tenant" do
      expect(Tenant, :read!, fn %{company_schema: "nonexistent"} ->
        []
      end)

      assert_raise ArgumentError, "Tenant not found: \"acq_nonexistent\"", fn ->
        TenantContext.with_tenant_context("acq_nonexistent", fn ->
          "should_not_execute"
        end)
      end
    end
  end

  describe "utility functions" do
    test "get_tenant_schema returns correct schema" do
      conn =
        conn(:get, "/")
        |> assign(:tenant_schema, "test_schema")

      assert TenantContext.get_tenant_schema(conn) == "test_schema"
    end

    test "get_tenant_id returns correct ID" do
      conn =
        conn(:get, "/")
        |> assign(:tenant_id, "test-id")

      assert TenantContext.get_tenant_id(conn) == "test-id"
    end

    test "has_tenant_context? returns true when both schema and ID are present" do
      conn =
        conn(:get, "/")
        |> assign(:tenant_schema, "test_schema")
        |> assign(:tenant_id, "test-id")

      assert TenantContext.has_tenant_context?(conn) == true
    end

    test "has_tenant_context? returns false when missing schema" do
      conn =
        conn(:get, "/")
        |> assign(:tenant_id, "test-id")

      assert TenantContext.has_tenant_context?(conn) == false
    end

    test "has_tenant_context? returns false when missing ID" do
      conn =
        conn(:get, "/")
        |> assign(:tenant_schema, "test_schema")

      assert TenantContext.has_tenant_context?(conn) == false
    end
  end

  describe "skip_tenant_context option" do
    test "skips tenant context when option is true" do
      opts = [skip_tenant_context: true]

      conn =
        conn(:get, "/api/health")
        |> TenantContext.call(opts)

      refute conn.assigns[:tenant_context_active]
    end

    test "skips tenant context for specific routes" do
      opts = [required_for_routes: ["/admin"]]

      conn =
        conn(:get, "/api/health")
        |> TenantContext.call(opts)

      refute conn.assigns[:tenant_context_active]
    end

    test "processes tenant context for matching routes" do
      test_tenant = %Tenant{
        id: "test-id",
        name: "Test Tenant",
        company_schema: "test_schema",
        status: :active
      }

      expect(TenantRouting, :get_current_tenant, fn _conn -> test_tenant end)

      expect(
        Repo,
        :query,
        fn "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'acq_test_schema'" ->
          {:ok, %{rows: [["acq_test_schema"]]}}
        end
      )

      expect(Repo, :get_search_path, fn -> "public" end)

      expect(
        Repo,
        :query,
        fn "SET search_path TO acq_test_schema, public, platform, shared, ag_catalog" ->
          {:ok, %{rows: []}}
        end
      )

      opts = [required_for_routes: ["/admin"]]

      conn =
        conn(:get, "/admin/dashboard")
        |> TenantContext.call(opts)

      assert conn.assigns[:tenant_context_active]
    end
  end
end
