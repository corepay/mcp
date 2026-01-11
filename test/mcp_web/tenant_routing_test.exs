defmodule McpWeb.TenantRoutingTest do
  use McpWeb.ConnCase, async: false

  import Plug.Conn

  alias Mcp.Platform.Tenant
  alias McpWeb.TenantRouting

  # Test setup with real database records
  setup do
    unique_id = System.unique_integer([:positive])

    # Create a tenant with subdomain
    {:ok, tenant_with_subdomain} =
      Tenant.create(%{
        name: "Test Company #{unique_id}",
        slug: "test-tenant-#{unique_id}",
        subdomain: "test-#{unique_id}",
        company_schema: "acq_test_subdomain_#{unique_id}",
        plan: :starter
      })

    # Create a tenant with custom domain
    {:ok, tenant_with_custom_domain} =
      Tenant.create(%{
        name: "Custom Domain Company #{unique_id}",
        slug: "custom-tenant-#{unique_id}",
        subdomain: "custom-#{unique_id}",
        custom_domain: "custom-#{unique_id}.example.com",
        company_schema: "acq_test_custom_#{unique_id}",
        plan: :professional
      })

    {:ok,
     tenant_with_subdomain: tenant_with_subdomain,
     tenant_with_custom_domain: tenant_with_custom_domain,
     subdomain: "test-#{unique_id}",
     custom_domain: "custom-#{unique_id}.example.com"}
  end

  describe "extract_tenant_from_host" do
    test "identifies tenant by subdomain", %{tenant_with_subdomain: tenant, subdomain: subdomain} do
      conn =
        build_conn(:get, "http://#{subdomain}.localhost")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      assert result_conn.assigns[:current_tenant].id == tenant.id
      assert result_conn.assigns[:tenant_schema] == tenant.company_schema
      assert result_conn.assigns[:tenant_id] == tenant.id
      assert result_conn.private[:tenant_id] == tenant.id
      assert result_conn.private[:tenant_schema] == tenant.company_schema
    end

    test "identifies tenant by custom domain", %{
      tenant_with_custom_domain: tenant,
      custom_domain: custom_domain
    } do
      conn =
        build_conn(:get, "http://#{custom_domain}")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      assert result_conn.assigns[:current_tenant].id == tenant.id
      assert result_conn.assigns[:tenant_schema] == tenant.company_schema
      assert result_conn.assigns[:tenant_id] == tenant.id
      assert result_conn.private[:tenant_id] == tenant.id
      assert result_conn.private[:tenant_schema] == tenant.company_schema
    end

    test "handles base domain without tenant context" do
      conn =
        build_conn(:get, "http://localhost")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      assert result_conn.assigns[:current_tenant] == nil
      assert result_conn.assigns[:tenant_schema] == nil
      assert result_conn.assigns[:tenant_id] == nil
    end

    test "handles www subdomain as base domain" do
      conn =
        build_conn(:get, "http://www.localhost")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      assert result_conn.assigns[:current_tenant] == nil
      assert result_conn.assigns[:tenant_schema] == nil
      assert result_conn.assigns[:tenant_id] == nil
    end

    test "handles tenant not found" do
      conn =
        build_conn(:get, "http://nonexistent.localhost")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      assert result_conn.assigns[:current_tenant] == nil
      assert result_conn.assigns[:tenant_schema] == nil
      assert result_conn.assigns[:tenant_id] == nil
    end

    test "handles invalid host header" do
      conn =
        build_conn(:get, "http://")
        |> Map.put(:host, "")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      # In test environment, invalid hosts are allowed to pass through
      # (see handle_invalid_host in TenantRouting)
      assert result_conn.state != :sent
    end

    test "handles port in host header", %{tenant_with_subdomain: tenant, subdomain: subdomain} do
      conn =
        build_conn(:get, "http://#{subdomain}.localhost:4000")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      assert result_conn.assigns[:current_tenant].id == tenant.id
    end
  end

  describe "x-forwarded-host header handling" do
    test "uses x-forwarded-host when present", %{
      tenant_with_subdomain: tenant,
      subdomain: subdomain
    } do
      conn =
        build_conn(:get, "http://internal-host")
        |> put_req_header("x-forwarded-host", "#{subdomain}.localhost")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      assert result_conn.assigns[:current_tenant].id == tenant.id
    end

    test "prioritizes x-forwarded-host over host header", %{
      tenant_with_subdomain: tenant,
      subdomain: subdomain
    } do
      conn =
        build_conn(:get, "http://wrong.localhost")
        |> put_req_header("x-forwarded-host", "#{subdomain}.localhost")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      # Should use x-forwarded-host, not host
      assert result_conn.assigns[:current_tenant].id == tenant.id
    end
  end

  describe "get_current_tenant" do
    test "returns current tenant from connection", %{
      tenant_with_subdomain: tenant,
      subdomain: subdomain
    } do
      conn =
        build_conn(:get, "http://#{subdomain}.localhost")
        |> assign(:current_tenant, tenant)

      assert TenantRouting.get_current_tenant(conn).id == tenant.id
    end

    test "returns nil when no tenant is set" do
      conn = build_conn(:get, "http://localhost")

      assert TenantRouting.get_current_tenant(conn) == nil
    end
  end

  describe "tenant_context?" do
    test "returns true when tenant context is active", %{
      tenant_with_subdomain: tenant,
      subdomain: subdomain
    } do
      conn =
        build_conn(:get, "http://#{subdomain}.localhost")
        |> assign(:current_tenant, tenant)

      assert TenantRouting.tenant_context?(conn) == true
    end

    test "returns false when no tenant context" do
      conn = build_conn(:get, "http://localhost")

      assert TenantRouting.tenant_context?(conn) == false
    end
  end

  describe "get_base_domain" do
    test "returns configured base domain" do
      original_domain = Application.get_env(:mcp, :base_domain)

      try do
        Application.put_env(:mcp, :base_domain, "example.com")
        assert TenantRouting.get_base_domain() == "example.com"
      after
        Application.put_env(:mcp, :base_domain, original_domain)
      end
    end

    test "returns localhost as default" do
      original_domain = Application.get_env(:mcp, :base_domain)

      try do
        Application.delete_env(:mcp, :base_domain)
        assert TenantRouting.get_base_domain() == "localhost"
      after
        if original_domain do
          Application.put_env(:mcp, :base_domain, original_domain)
        end
      end
    end
  end

  describe "skip_subdomain_extraction option" do
    test "skips tenant routing when skip_subdomain_extraction is true" do
      conn =
        build_conn(:get, "http://any-host.com")

      opts = TenantRouting.init(skip_subdomain_extraction: true)
      result_conn = TenantRouting.call(conn, opts)

      assert result_conn.assigns[:current_tenant] == nil
    end

    test "processes tenant routing when skip_subdomain_extraction is false", %{
      tenant_with_subdomain: tenant,
      subdomain: subdomain
    } do
      conn =
        build_conn(:get, "http://#{subdomain}.localhost")

      opts = TenantRouting.init(skip_subdomain_extraction: false)
      result_conn = TenantRouting.call(conn, opts)

      assert result_conn.assigns[:current_tenant].id == tenant.id
    end
  end

  describe "edge cases and security" do
    test "handles host with uppercase letters", %{
      tenant_with_subdomain: tenant,
      subdomain: subdomain
    } do
      conn =
        build_conn(:get, "http://#{String.upcase(subdomain)}.localhost")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      # Host should be normalized to lowercase
      assert result_conn.assigns[:current_tenant].id == tenant.id
    end

    test "handles custom domain with uppercase letters", %{
      tenant_with_custom_domain: tenant,
      custom_domain: custom_domain
    } do
      conn =
        build_conn(:get, "http://#{String.upcase(custom_domain)}")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      # Custom domain should be normalized to lowercase
      assert result_conn.assigns[:current_tenant].id == tenant.id
    end

    test "handles multiple subdomains (only uses first level)", %{
      tenant_with_subdomain: tenant,
      subdomain: subdomain
    } do
      conn =
        build_conn(:get, "http://#{subdomain}.app.localhost")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      # Should extract "test" as the subdomain
      assert result_conn.assigns[:current_tenant].id == tenant.id
    end

    test "prevents injection via host header" do
      conn =
        build_conn(:get, "http://malicious';DROP TABLE tenants;--@localhost")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      # Should not find a tenant and should handle gracefully
      assert result_conn.assigns[:current_tenant] == nil
    end
  end

  describe "tenant context lifecycle" do
    test "properly sets all tenant-related assigns", %{
      tenant_with_subdomain: tenant,
      subdomain: subdomain
    } do
      conn =
        build_conn(:get, "http://#{subdomain}.localhost")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      # Verify all assigns are set correctly
      assert result_conn.assigns[:current_tenant].id == tenant.id
      assert result_conn.assigns[:tenant_schema] == tenant.company_schema
      assert result_conn.assigns[:tenant_id] == tenant.id

      # Verify private fields are also set (used by some downstream plugs)
      assert result_conn.private[:tenant_id] == tenant.id
      assert result_conn.private[:tenant_schema] == tenant.company_schema
    end

    test "preserves existing connection assigns", %{
      tenant_with_subdomain: tenant,
      subdomain: subdomain
    } do
      conn =
        build_conn(:get, "http://#{subdomain}.localhost")
        |> assign(:existing_value, "should_persist")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      assert result_conn.assigns[:existing_value] == "should_persist"
      assert result_conn.assigns[:current_tenant].id == tenant.id
    end
  end
end
