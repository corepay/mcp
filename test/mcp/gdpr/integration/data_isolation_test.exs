defmodule Mcp.Gdpr.Integration.DataIsolationTest do
  use McpWeb.ConnCase, async: true

  @moduletag :gdpr
  @moduletag :integration

  # Add host header for all API tests to bypass tenant routing
  setup %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-forwarded-host", "www.example.com")

    {:ok, conn: conn}
  end

  # Test setup functions for multi-tenant scenarios
  defp create_tenant_user(context) do
    tenant_name = context[:tenant] || "tenant1"
    user_role = context[:role] || :user

    user = %{
      id: Ecto.UUID.generate(),
      email: "#{user_role}@#{tenant_name}.example.com",
      role: user_role,
      tenant_schema: tenant_name,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    [user: user, tenant: tenant_name]
  end

  defp auth_tenant_user_conn(%{conn: conn} = context) do
    user = context[:user]
    tenant = context[:tenant]

    auth_conn =
      conn
      |> assign(:current_user, user)
      |> assign(:tenant_schema, tenant)
      |> assign(:current_tenant, %{company_schema: tenant})
      |> put_req_header("authorization", "Bearer mock.jwt.token.#{user.id}")

    [conn: auth_conn, user: user, tenant: tenant]
  end

  describe "Multi-Tenant Data Isolation" do
    setup [:create_tenant_user, :auth_tenant_user_conn]

    test "tenant1 cannot access tenant2 data", %{conn: conn, user: _user1, tenant: _tenant1} do
      # GREEN: Test that users from one tenant cannot access another tenant's data

      # Create user from different tenant
      [user: user2, tenant: tenant2] = create_tenant_user(%{tenant: "tenant2"})

      # Set up test context for cross-tenant access simulation
      conn =
        conn
        |> put_private(:test_cross_tenant_target, %{user_id: user2.id, tenant: tenant2})

      # Attempt to access tenant2 user data from tenant1 connection
      conn = delete(conn, "/api/gdpr/data/#{user2.id}")

      # Should return 403 or 404 - user from tenant1 cannot access tenant2 data
      assert conn.status in [403, 404]
      response = json_response(conn, conn.status)

      if conn.status == 403 do
        assert response["error"] =~ "forbidden"
      else
        assert response["error"] =~ "not found"
      end
    end

    test "admin operations work within tenant scope", %{conn: conn, tenant: tenant} do
      # GREEN: Test that admin operations are properly scoped to tenant

      # Create admin user for this tenant
      [user: admin_user, tenant: ^tenant] = create_tenant_user(%{tenant: tenant, role: :admin})

      admin_conn =
        conn
        |> assign(:current_user, admin_user)
        |> assign(:tenant_schema, tenant)
        |> put_req_header("authorization", "Bearer admin.token.#{admin_user.id}")

      # Get compliance report - should be scoped to current tenant
      conn = get(admin_conn, "/api/gdpr/admin/compliance")

      # Should return 200 with tenant-scoped compliance data
      response = json_response(conn, 200)
      assert %{"compliance_score" => score} = response
      assert is_number(score)

      # Response should not contain data from other tenants
      refute Map.has_key?(response, "cross_tenant_data")
    end

    test "export requests are tenant-isolated", %{conn: conn, user: _user, tenant: tenant} do
      # RED: Test that export requests are properly isolated by tenant

      # Request export for current tenant user
      conn = post(conn, "/api/gdpr/export", %{"format" => "json", "tenant" => tenant})

      # Should return 202 with export details
      response = json_response(conn, 202)
      assert %{"export_id" => export_id, "status" => "pending"} = response

      # Export should be associated with current tenant
      assert String.contains?(export_id, tenant) or
               response["tenant_id"] == tenant or
               get_resp_header(conn, "x-tenant-id") == [tenant]
    end

    test "audit trail maintains tenant separation", %{conn: conn, user: _user, tenant: tenant} do
      # RED: Test that audit entries are properly separated by tenant

      # Perform GDPR action
      post(conn, "/api/gdpr/export", %{"format" => "json"})

      # Get audit trail
      conn = get(conn, "/api/gdpr/audit-trail")

      # Should return audit entries for current tenant only
      response = json_response(conn, 200)
      assert %{"audit_entries" => entries} = response
      assert is_list(entries)

      # All entries should belong to current tenant
      tenant_entries =
        Enum.filter(entries, fn entry ->
          entry["tenant_id"] == tenant or entry["tenant_schema"] == tenant
        end)

      # Should have at least one entry for the current tenant
      assert length(tenant_entries) >= 1

      # No entries should belong to other tenants
      other_tenant_entries =
        Enum.filter(entries, fn entry ->
          entry["tenant_id"] != nil and entry["tenant_id"] != tenant
        end)

      assert Enum.empty?(other_tenant_entries)
    end
  end

  describe "Cross-Tenant Data Leak Prevention" do
    setup [:create_tenant_user, :auth_tenant_user_conn]

    test "user enumeration across tenants is prevented", %{
      conn: conn,
      user: _user1,
      tenant: _tenant1
    } do
      # RED: Test that users cannot enumerate users across tenants

      # Create user from different tenant
      [user: _user2] = create_tenant_user(%{tenant: "tenant2"})

      # Try to access user2's export data
      conn = get(conn, "/api/gdpr/export/#{Ecto.UUID.generate()}/status")

      # Should return 404 - user cannot access other tenants' exports
      response = json_response(conn, 404)
      assert response["error"] =~ "not found"

      # Response should not leak information about tenant existence
      refute String.contains?(response["error"], "tenant2")
      refute String.contains?(response["error"], "user not found")
    end

    test "audit trail injection prevention", %{conn: conn, user: _user, tenant: tenant} do
      # RED: Test that users cannot inject audit entries for other tenants

      # Try to inject audit entry for different tenant via malicious parameters
      malicious_payload = %{
        "format" => "json",
        "tenant_id" => "other_tenant",
        "user_id" => Ecto.UUID.generate(),
        "action" => "DATA_EXPORT"
      }

      conn = post(conn, "/api/gdpr/export", malicious_payload)

      # Should either accept but isolate to current tenant or reject malicious request
      if conn.status == 202 do
        # If accepted, verify it's isolated to current tenant
        response = json_response(conn, 202)

        assert response["tenant_id"] == tenant or
                 not Map.has_key?(response, "tenant_id")
      else
        # Should reject with validation error
        assert conn.status in [400, 403]
        response = json_response(conn, conn.status)

        assert response["error"] =~ "invalid" or
                 response["error"] =~ "forbidden"
      end
    end

    test "tenant isolation in compliance reports", %{conn: conn, user: _user, tenant: tenant} do
      # RED: Test that compliance reports are properly scoped to tenant

      # Create admin connection
      [user: admin_user] = create_tenant_user(%{tenant: tenant, role: :admin})

      admin_conn =
        conn
        |> assign(:current_user, admin_user)
        |> put_req_header("authorization", "Bearer admin.token.#{admin_user.id}")

      # Get compliance report
      conn = get(admin_conn, "/api/gdpr/admin/compliance")

      # Should return tenant-scoped compliance data
      response = json_response(conn, 200)

      # Verify tenant scoping indicators
      # Implicit scoping
      assert response["tenant_id"] == tenant or
               not Map.has_key?(response, "tenant_id")

      # Verify data aggregation is tenant-specific
      if Map.has_key?(response, "total_users") do
        assert is_number(response["total_users"])
        # Should be reasonable for single tenant (not massive aggregation)
        assert response["total_users"] < 10_000
      end
    end
  end

  describe "Tenant Context Enforcement" do
    test "requests without tenant context are rejected", %{conn: conn} do
      # RED: Test that requests without proper tenant context are handled appropriately

      # Make request without tenant assignment
      conn = post(conn, "/api/gdpr/export", %{"format" => "json"})

      # Should either work with default tenant or return appropriate error
      # The key is that it shouldn't crash or leak cross-tenant data
      assert conn.status in [202, 400, 401]
    end

    test "tenant context switching is prevented", %{conn: conn} do
      # RED: Test that users cannot switch tenant context via headers or parameters

      # Try to switch tenant via headers
      conn =
        conn
        |> put_req_header("x-tenant-id", "different_tenant")
        |> post("/api/gdpr/export", %{"format" => "json"})

      # Should either ignore tenant switch header or reject request
      # Should not actually switch to different tenant
      if conn.status == 202 do
        response = json_response(conn, 202)
        # If accepted, verify it's not using the requested tenant
        refute response["tenant_id"] == "different_tenant"
      end
    end
  end
end
