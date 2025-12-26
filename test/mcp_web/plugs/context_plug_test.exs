defmodule McpWeb.Plugs.ContextPlugTest do
  use McpWeb.ConnCase, async: true
  alias McpWeb.Plugs.ContextPlug

  # We need to ensure Redix is available.
  # Since we are running in :test env, and using real Redis, we assume it's started by the app.

  setup do
    # Clear any existing keys for localhost to ensure clean state
    Redix.command(:redix_cache, ["DEL", "routing:localhost"])
    Redix.command(:redix_cache, ["DEL", "routing:acme.localhost"])
    :ok
  end

  describe "ContextPlug" do
    test "resolves platform context and caches it", %{conn: conn} do
      conn = %{conn | host: "platform.localhost"}
      conn = ContextPlug.call(conn, [])

      assert conn.assigns.context_type == :platform
      assert conn.assigns.context_entity == nil

      # Verify cache
      {:ok, binary} = Redix.command(:redix_cache, ["GET", "routing:platform.localhost"])
      assert binary
      {:platform, nil, _} = :erlang.binary_to_term(binary)
    end

    defmodule MockTenant do
      defstruct [:id, :slug, :company_schema]

      def by_subdomain("acme"),
        do: {:ok, %MockTenant{id: "t1", slug: "acme", company_schema: "acme_schema"}}

      def by_subdomain(_), do: {:error, :not_found}
    end

    defmodule MockMerchant do
      defstruct [:id, :slug]

      def by_slug("bobs-burgers", opts) do
        if opts[:tenant] do
          {:ok, %MockMerchant{id: "m1", slug: "bobs-burgers"}}
        else
          {:error, :tenant_required}
        end
      end

      def by_slug(_, _), do: {:error, :not_found}
    end

    test "resolves tenant context and caches it", %{conn: conn} do
      conn = %{conn | host: "acme.localhost"}
      conn = ContextPlug.call(conn, ContextPlug.init(tenant_resource: MockTenant))

      assert conn.assigns.context_type == :tenant
      assert conn.assigns.context_entity.id == "t1"
      assert conn.assigns.tenant_schema == "acme_schema"

      # Verify cache
      {:ok, binary} = Redix.command(:redix_cache, ["GET", "routing:acme.localhost"])
      assert binary
      {:tenant, tenant, assigns} = :erlang.binary_to_term(binary)
      assert tenant.id == "t1"
      assert assigns.tenant_schema == "acme_schema"
      assert assigns.ash_tenant == "acme_schema"
    end

    test "uses cached value on subsequent requests", %{conn: conn} do
      # 1. First request to populate cache
      conn = %{conn | host: "acme.localhost"}
      ContextPlug.call(conn, ContextPlug.init(tenant_resource: MockTenant))

      # 2. Second request should NOT call MockTenant (if we were mocking strict calls)
      # But since we aren't using strict mocks, we verify by modifying the cache manually
      # to see if the Plug picks up the modified value.

      fake_tenant = %MockTenant{id: "t2-cached", slug: "acme", company_schema: "cached_schema"}

      data =
        {:tenant, fake_tenant, %{tenant_schema: "cached_schema", ash_tenant: "cached_schema"}}

      binary = :erlang.term_to_binary(data)
      Redix.command(:redix_cache, ["SET", "routing:acme.localhost", binary])

      # 3. Request again
      conn2 = %{conn | host: "acme.localhost"}
      conn2 = ContextPlug.call(conn2, ContextPlug.init(tenant_resource: MockTenant))

      assert conn2.assigns.context_type == :tenant
      assert conn2.assigns.context_entity.id == "t2-cached"
      assert conn2.assigns.tenant_schema == "cached_schema"
      assert conn2.private.ash_tenant == "cached_schema"
    end

    test "resolves merchant context and caches it", %{conn: conn} do
      conn = %{conn | host: "bobs-burgers.acme.localhost"}

      conn =
        ContextPlug.call(
          conn,
          ContextPlug.init(tenant_resource: MockTenant, merchant_resource: MockMerchant)
        )

      assert conn.assigns.context_type == :merchant
      assert conn.assigns.context_entity.id == "m1"
      assert conn.assigns.tenant_schema == "acme_schema"

      # Verify cache
      {:ok, binary} = Redix.command(:redix_cache, ["GET", "routing:bobs-burgers.acme.localhost"])
      assert binary
      {:merchant, merchant, assigns} = :erlang.binary_to_term(binary)
      assert merchant.id == "m1"
      assert assigns.tenant_schema == "acme_schema"
    end

    test "returns 404 for unknown organization", %{conn: conn} do
      conn = %{conn | host: "unknown-org.localhost"}
      conn = ContextPlug.call(conn, ContextPlug.init(tenant_resource: MockTenant))

      assert conn.status == 404
      assert conn.halted
    end
  end
end
