defmodule McpWeb.TenantRoutingTest do
  use ExUnit.Case, async: true
  use Plug.Test
  import Mock

  alias Mcp.Platform.Tenant
  alias McpWeb.TenantRouting

  # Mock tenant data
  @valid_tenant %Tenant{
    id: "123e4567-e89b-12d3-a456-426614174000",
    slug: "test-tenant",
    name: "Test Company",
    company_schema: "test_tenant",
    subdomain: "test",
    custom_domain: "test-company.com",
    plan: :starter,
    status: :active
  }

  @tenant_with_custom_domain %Tenant{
    id: "123e4567-e89b-12d3-a456-426614174001",
    slug: "custom-tenant",
    name: "Custom Domain Company",
    company_schema: "custom_tenant",
    subdomain: "custom",
    custom_domain: "custom.example.com",
    plan: :professional,
    status: :active
  }

  describe "extract_tenant_from_host" do
    test "identifies tenant by subdomain" do
      conn =
        conn(:get, "http://test.localhost")
        |> put_req_header("host", "test.localhost")

      # Mock the Tenant.read! call
      with_mock Tenant, [:passthrough],
        read!: fn
          :by_custom_domain, _ -> []
          :by_subdomain, subdomain: "test" -> [@valid_tenant]
        end do
        opts = TenantRouting.init(base_domain: "localhost")
        result_conn = TenantRouting.call(conn, opts)

        assert result_conn.assigns[:current_tenant] == @valid_tenant
        assert result_conn.assigns[:tenant_schema] == "test_tenant"
        assert result_conn.assigns[:tenant_id] == @valid_tenant.id
      end
    end

    test "identifies tenant by custom domain" do
      conn =
        conn(:get, "http://custom.example.com")
        |> put_req_header("host", "custom.example.com")

      # Mock the Tenant.read! call
      with_mock Tenant, [:passthrough],
        read!: fn
          :by_custom_domain, custom_domain: "custom.example.com" -> [@tenant_with_custom_domain]
          :by_subdomain, _ -> []
        end do
        opts = TenantRouting.init(base_domain: "localhost")
        result_conn = TenantRouting.call(conn, opts)

        assert result_conn.assigns[:current_tenant] == @tenant_with_custom_domain
        assert result_conn.assigns[:tenant_schema] == "custom_tenant"
        assert result_conn.assigns[:tenant_id] == @tenant_with_custom_domain.id
      end
    end

    test "handles base domain without tenant context" do
      conn =
        conn(:get, "http://localhost")
        |> put_req_header("host", "localhost")

      # Mock the Tenant.read! call
      with_mock Tenant, [:passthrough],
        read!: fn
          :by_custom_domain, _ -> []
          :by_subdomain, _ -> []
        end do
        opts = TenantRouting.init(base_domain: "localhost")
        result_conn = TenantRouting.call(conn, opts)

        assert result_conn.assigns[:current_tenant] == nil
        assert result_conn.assigns[:tenant_schema] == nil
        assert result_conn.assigns[:tenant_id] == nil
      end
    end

    test "handles www subdomain as base domain" do
      conn =
        conn(:get, "http://www.localhost")
        |> put_req_header("host", "www.localhost")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      assert result_conn.assigns[:current_tenant] == nil
    end

    test "handles tenant not found" do
      conn =
        conn(:get, "http://nonexistent.localhost")
        |> put_req_header("host", "nonexistent.localhost")

      # Mock the Tenant.read! call
      with_mock Tenant, [:passthrough],
        read!: fn
          :by_custom_domain, _ -> []
          :by_subdomain, subdomain: "nonexistent" -> []
        end do
        opts = TenantRouting.init(base_domain: "localhost")
        result_conn = TenantRouting.call(conn, opts)

        assert result_conn.assigns[:current_tenant] == nil
        assert result_conn.assigns[:tenant_schema] == nil
        assert result_conn.assigns[:tenant_id] == nil
      end
    end

    test "handles invalid host header" do
      conn =
        conn(:get, "http://")
        |> put_req_header("host", "")

      opts = TenantRouting.init(base_domain: "localhost")
      result_conn = TenantRouting.call(conn, opts)

      assert result_conn.state == :sent
      assert result_conn.status == 400
    end

    test "handles port in host header" do
      conn =
        conn(:get, "http://test.localhost:4000")
        |> put_req_header("host", "test.localhost:4000")

      # Mock the Tenant.read! call
      with_mock Tenant, [:passthrough],
        read!: fn
          :by_custom_domain, _ -> []
          :by_subdomain, subdomain: "test" -> [@valid_tenant]
        end do
        opts = TenantRouting.init(base_domain: "localhost")
        result_conn = TenantRouting.call(conn, opts)

        assert result_conn.assigns[:current_tenant] == @valid_tenant
      end
    end
  end

  describe "x-forwarded-host header handling" do
    test "uses x-forwarded-host when present" do
      conn =
        conn(:get, "http://internal-host")
        |> put_req_header("x-forwarded-host", "test.localhost")
        |> put_req_header("host", "internal-host")

      # Mock the Tenant.read! call
      with_mock Tenant, [:passthrough],
        read!: fn
          :by_custom_domain, _ -> []
          :by_subdomain, subdomain: "test" -> [@valid_tenant]
        end do
        opts = TenantRouting.init(base_domain: "localhost")
        result_conn = TenantRouting.call(conn, opts)

        assert result_conn.assigns[:current_tenant] == @valid_tenant
      end
    end
  end

  describe "get_current_tenant" do
    test "returns current tenant from connection" do
      conn =
        conn(:get, "http://test.localhost")
        |> assign(:current_tenant, @valid_tenant)

      assert TenantRouting.get_current_tenant(conn) == @valid_tenant
    end

    test "returns nil when no tenant is set" do
      conn = conn(:get, "http://localhost")

      assert TenantRouting.get_current_tenant(conn) == nil
    end
  end

  describe "tenant_context?" do
    test "returns true when tenant context is active" do
      conn =
        conn(:get, "http://test.localhost")
        |> assign(:current_tenant, @valid_tenant)

      assert TenantRouting.tenant_context?(conn) == true
    end

    test "returns false when no tenant context" do
      conn = conn(:get, "http://localhost")

      assert TenantRouting.tenant_context?(conn) == false
    end
  end

  describe "get_base_domain" do
    test "returns configured base domain" do
      Application.put_env(:mcp, :base_domain, "example.com")
      assert TenantRouting.get_base_domain() == "example.com"
    after
      Application.put_env(:mcp, :base_domain, "localhost")
    end

    test "returns localhost as default" do
      Application.delete_env(:mcp, :base_domain)
      assert TenantRouting.get_base_domain() == "localhost"
    after
      Application.put_env(:mcp, :base_domain, "localhost")
    end
  end

  describe "skip_subdomain_extraction option" do
    test "skips tenant routing when skip_subdomain_extraction is true" do
      conn =
        conn(:get, "http://any-host.com")
        |> put_req_header("host", "any-host.com")

      opts = TenantRouting.init(skip_subdomain_extraction: true)
      result_conn = TenantRouting.call(conn, opts)

      assert result_conn.assigns[:current_tenant] == nil
    end
  end
end
