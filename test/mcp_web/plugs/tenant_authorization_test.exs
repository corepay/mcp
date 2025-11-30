defmodule McpWeb.Plugs.TenantAuthorizationTest do
  @moduledoc """
  Tests for TenantAuthorization plug functionality.

  This test suite covers role-based access control,
  permission checking, and authorization enforcement.
  """

  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn


  alias McpWeb.Plugs.TenantAuthorization

  @opts [required_permissions: [:user_management]]

  describe "call/2 with valid authentication" do
    test "authorizes admin users with sufficient permissions" do
      admin_user = %{
        id: "user-123",
        role: :admin,
        is_tenant_owner: false,
        permissions: [:all]
      }

      tenant_context = %{id: "tenant-456"}

      conn =
        conn(:get, "/users")
        |> assign(:current_user, admin_user)
        |> assign(:current_tenant_user, admin_user)
        |> assign(:tenant_context, tenant_context)

      result_conn = TenantAuthorization.call(conn, @opts)

      assert result_conn.assigns.authorized_user == true
      assert result_conn.assigns.user_role == :admin
      assert result_conn.assigns.user_permissions == [:all]
      assert result_conn.assigns.is_tenant_owner == false
    end

    test "authorizes tenant owners bypassing permission checks" do
      tenant_owner = %{
        id: "owner-123",
        role: :viewer,
        is_tenant_owner: true,
        permissions: [:view_only]
      }

      tenant_context = %{id: "tenant-456"}

      conn =
        conn(:get, "/users")
        |> assign(:current_user, tenant_owner)
        |> assign(:current_tenant_user, tenant_owner)
        |> assign(:tenant_context, tenant_context)

      result_conn = TenantAuthorization.call(conn, @opts)

      assert result_conn.assigns.authorized_user == true
      assert result_conn.assigns.is_tenant_owner == true
    end

    test "rejects users without required permissions" do
      viewer_user = %{
        id: "viewer-123",
        role: :viewer,
        is_tenant_owner: false,
        permissions: [:view_only]
      }

      tenant_context = %{id: "tenant-456"}

      conn =
        conn(:get, "/users")
        |> assign(:current_user, viewer_user)
        |> assign(:current_tenant_user, viewer_user)
        |> assign(:tenant_context, tenant_context)

      result_conn = TenantAuthorization.call(conn, @opts)

      assert result_conn.state == :sent
      assert result_conn.status == 403
      assert result_conn.resp_body =~ "Unauthorized"
    end

    test "rejects users without tenant context" do
      user = %{
        id: "user-123",
        role: :admin,
        is_tenant_owner: false,
        permissions: [:all]
      }

      conn =
        conn(:get, "/users")
        |> assign(:current_user, user)
        |> assign(:current_tenant_user, user)

      result_conn = TenantAuthorization.call(conn, @opts)

      assert result_conn.state == :sent
      assert result_conn.status == 403
      assert result_conn.resp_body =~ "Unauthorized"
    end

    test "rejects requests without user authentication" do
      tenant_context = %{id: "tenant-456"}

      conn =
        conn(:get, "/users")
        |> assign(:tenant_context, tenant_context)

      result_conn = TenantAuthorization.call(conn, @opts)

      assert result_conn.state == :sent
      assert result_conn.status == 403
      assert result_conn.resp_body =~ "Unauthorized"
    end
  end

  describe "permission checking functions" do
    test "user_has_permission?/2 checks individual permissions" do
      admin_user = %{role: :admin, permissions: [:all]}
      viewer_user = %{role: :viewer, permissions: [:view_only]}

      assert TenantAuthorization.user_has_permission?(admin_user, :any_permission)
      assert TenantAuthorization.user_has_permission?(viewer_user, :view_only)
      refute TenantAuthorization.user_has_permission?(viewer_user, :user_management)
    end

    test "user_has_any_permission?/2 checks multiple permissions" do
      billing_admin = %{role: :billing_admin, permissions: [:manage_billing, :view_customers]}

      assert TenantAuthorization.user_has_any_permission?(billing_admin, [
               :manage_billing,
               :user_management
             ])

      refute TenantAuthorization.user_has_any_permission?(billing_admin, [
               :user_management,
               :system_configuration
             ])
    end

    test "user_has_all_permissions?/2 requires all permissions" do
      billing_admin = %{role: :billing_admin, permissions: [:manage_billing, :view_customers]}

      assert TenantAuthorization.user_has_all_permissions?(billing_admin, [:manage_billing])

      refute TenantAuthorization.user_has_all_permissions?(billing_admin, [
               :manage_billing,
               :user_management
             ])
    end

    test "user_has_role?/2 checks user role" do
      admin_user = %{role: :admin}
      operator_user = %{role: :operator}

      assert TenantAuthorization.user_has_role?(admin_user, :admin)
      refute TenantAuthorization.user_has_role?(admin_user, :operator)
      # String version
      assert TenantAuthorization.user_has_role?(operator_user, "operator")
    end

    test "user_has_any_role?/2 checks multiple roles" do
      admin_user = %{role: :admin}
      viewer_user = %{role: :viewer}

      assert TenantAuthorization.user_has_any_role?(admin_user, [:admin, :billing_admin])
      refute TenantAuthorization.user_has_any_role?(viewer_user, [:admin, :billing_admin])
    end
  end

  describe "permission helper functions" do
    test "can_manage_users?/1 checks user management permissions" do
      admin = %{role: :admin, is_tenant_owner: false, permissions: []}
      billing_admin = %{role: :billing_admin, is_tenant_owner: false, permissions: []}
      tenant_owner = %{role: :viewer, is_tenant_owner: true, permissions: []}
      viewer = %{role: :viewer, is_tenant_owner: false, permissions: []}

      assert TenantAuthorization.can_manage_users?(admin)
      assert TenantAuthorization.can_manage_users?(tenant_owner)
      refute TenantAuthorization.can_manage_users?(billing_admin)
      refute TenantAuthorization.can_manage_users?(viewer)
    end

    test "can_manage_billing?/1 checks billing management permissions" do
      admin = %{role: :admin, is_tenant_owner: false, permissions: []}
      billing_admin = %{role: :billing_admin, is_tenant_owner: false, permissions: []}
      tenant_owner = %{role: :viewer, is_tenant_owner: true, permissions: []}
      operator = %{role: :operator, is_tenant_owner: false, permissions: []}

      assert TenantAuthorization.can_manage_billing?(admin)
      assert TenantAuthorization.can_manage_billing?(billing_admin)
      assert TenantAuthorization.can_manage_billing?(tenant_owner)
      refute TenantAuthorization.can_manage_billing?(operator)
    end

    test "can_view_reports?/1 checks report viewing permissions" do
      admin = %{role: :admin, is_tenant_owner: false, permissions: []}

      billing_admin = %{
        role: :billing_admin,
        is_tenant_owner: false,
        permissions: [:view_reports]
      }

      viewer = %{role: :viewer, is_tenant_owner: false, permissions: []}

      assert TenantAuthorization.can_view_reports?(admin)
      assert TenantAuthorization.can_view_reports?(billing_admin)
      refute TenantAuthorization.can_view_reports?(viewer)
    end

    test "can_access_system_settings?/1 checks system settings access" do
      admin = %{role: :admin, is_tenant_owner: false, permissions: []}
      operator = %{role: :operator, is_tenant_owner: false, permissions: []}
      tenant_owner = %{role: :viewer, is_tenant_owner: true, permissions: []}

      assert TenantAuthorization.can_access_system_settings?(admin)
      assert TenantAuthorization.can_access_system_settings?(tenant_owner)
      refute TenantAuthorization.can_access_system_settings?(operator)
    end

    test "can_invite_users?/1 checks user invitation permissions" do
      admin = %{role: :admin, is_tenant_owner: false, permissions: []}

      billing_admin = %{
        role: :billing_admin,
        is_tenant_owner: false,
        permissions: [:user_management]
      }

      viewer = %{role: :viewer, is_tenant_owner: false, permissions: []}

      assert TenantAuthorization.can_invite_users?(admin)
      assert TenantAuthorization.can_invite_users?(billing_admin)
      refute TenantAuthorization.can_invite_users?(viewer)
    end
  end

  describe "tenant owner bypass" do
    test "tenant owners bypass permission checks when allowed" do
      tenant_owner = %{
        id: "owner-123",
        role: :viewer,
        is_tenant_owner: true,
        permissions: [:view_only]
      }

      tenant_context = %{id: "tenant-456"}

      opts_with_bypass = [required_permissions: [:user_management], allow_tenant_owners: true]

      conn =
        conn(:get, "/users")
        |> assign(:current_user, tenant_owner)
        |> assign(:current_tenant_user, tenant_owner)
        |> assign(:tenant_context, tenant_context)

      result_conn = TenantAuthorization.call(conn, opts_with_bypass)

      assert result_conn.assigns.authorized_user == true
    end

    test "tenant owners don't bypass when disabled" do
      tenant_owner = %{
        id: "owner-123",
        role: :viewer,
        is_tenant_owner: true,
        permissions: [:view_only]
      }

      tenant_context = %{id: "tenant-456"}

      opts_without_bypass = [required_permissions: [:user_management], allow_tenant_owners: false]

      conn =
        conn(:get, "/users")
        |> assign(:current_user, tenant_owner)
        |> assign(:current_tenant_user, tenant_owner)
        |> assign(:tenant_context, tenant_context)

      result_conn = TenantAuthorization.call(conn, opts_without_bypass)

      assert result_conn.state == :sent
      assert result_conn.status == 403
    end
  end

  describe "role-based authorization" do
    test "authorizes based on required roles" do
      admin_user = %{role: :admin, is_tenant_owner: false, permissions: []}
      viewer_user = %{role: :viewer, is_tenant_owner: false, permissions: []}

      tenant_context = %{id: "tenant-456"}

      opts_with_roles = [required_roles: [:admin, :billing_admin]]

      # Admin should be authorized
      admin_conn =
        conn(:get, "/users")
        |> assign(:current_user, admin_user)
        |> assign(:current_tenant_user, admin_user)
        |> assign(:tenant_context, tenant_context)

      admin_result = TenantAuthorization.call(admin_conn, opts_with_roles)
      assert admin_result.assigns.authorized_user == true

      # Viewer should not be authorized
      viewer_conn =
        conn(:get, "/users")
        |> assign(:current_user, viewer_user)
        |> assign(:current_tenant_user, viewer_user)
        |> assign(:tenant_context, tenant_context)

      viewer_result = TenantAuthorization.call(viewer_conn, opts_with_roles)
      assert viewer_result.state == :sent
      assert viewer_result.status == 403
    end

    test "authorizes based on both roles and permissions" do
      billing_admin = %{
        role: :billing_admin,
        is_tenant_owner: false,
        permissions: [:manage_billing]
      }

      tenant_context = %{id: "tenant-456"}

      opts_with_both = [
        required_roles: [:billing_admin, :admin],
        required_permissions: [:manage_billing]
      ]

      conn =
        conn(:get, "/billing")
        |> assign(:current_user, billing_admin)
        |> assign(:current_tenant_user, billing_admin)
        |> assign(:tenant_context, tenant_context)

      result_conn = TenantAuthorization.call(conn, opts_with_both)

      assert result_conn.assigns.authorized_user == true
    end
  end

  describe "error responses" do
    test "returns proper JSON error responses" do
      viewer_user = %{
        id: "viewer-123",
        role: :viewer,
        is_tenant_owner: false,
        permissions: [:view_only]
      }

      tenant_context = %{id: "tenant-456"}

      conn =
        conn(:get, "/api/users")
        |> assign(:current_user, viewer_user)
        |> assign(:current_tenant_user, viewer_user)
        |> assign(:tenant_context, tenant_context)

      result_conn = TenantAuthorization.call(conn, @opts)

      assert result_conn.status == 403
      assert get_resp_header(result_conn, "content-type") == ["application/json"]

      response_body = Jason.decode!(result_conn.resp_body)
      assert response_body["error"] == "Unauthorized"
      assert response_body["reason"] == :insufficient_permissions
      assert is_binary(response_body["message"])
    end
  end
end
