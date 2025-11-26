defmodule McpWeb.Plugs.TenantAuthorization do
  @moduledoc """
  Authorization plug for tenant-specific role-based access control.

  This plug enforces role-based permissions for tenant users,
  ensuring that users can only access resources they're authorized for
  within their tenant context.
  """

  import Plug.Conn
  require Logger

  @doc """
  Initialize the plug with authorization options.
  """
  def init(opts \\ []) do
    Keyword.merge(
      [
        required_permissions: [],
        required_roles: [],
        allow_tenant_owners: true,
        tenant_resource: nil
      ],
      opts
    )
  end

  @doc """
  Call the plug to perform authorization checks.
  """
  def call(conn, opts) do
    current_user = get_current_user(conn)
    tenant_context = get_tenant_context(conn)

    cond do
      is_nil(current_user) ->
        handle_unauthorized(conn, :no_user)

      is_nil(tenant_context) ->
        handle_unauthorized(conn, :no_tenant_context)

      not user_in_tenant?(current_user, tenant_context) ->
        handle_unauthorized(conn, :user_not_in_tenant)

      not authorized?(current_user, tenant_context, opts) ->
        handle_unauthorized(conn, :insufficient_permissions)

      true ->
        # User is authorized, add authorization data to conn assigns
        conn
        |> assign(:authorized_user, true)
        |> assign(:user_permissions, get_user_permissions(current_user))
        |> assign(:user_role, get_user_role(current_user))
        |> assign(:is_tenant_owner, tenant_owner?(current_user))
    end
  end

  @doc """
  Check if a user has specific permission.
  """
  def user_has_permission?(user, permission) do
    case get_user_permissions(user) do
      nil -> false
      permissions -> permission in permissions
    end
  end

  @doc """
  Check if a user has any of the specified permissions.
  """
  def user_has_any_permission?(user, permissions) when is_list(permissions) do
    user_permissions = get_user_permissions(user)
    Enum.any?(permissions, &(&1 in (user_permissions || [])))
  end

  @doc """
  Check if a user has all specified permissions.
  """
  def user_has_all_permissions?(user, permissions) when is_list(permissions) do
    user_permissions = get_user_permissions(user)
    Enum.all?(permissions, &(&1 in (user_permissions || [])))
  end

  @doc """
  Check if a user has specific role.
  """
  def user_has_role?(user, role) when is_atom(role) do
    get_user_role(user) == role
  end

  def user_has_role?(user, role) when is_binary(role) do
    get_user_role(user) == String.to_atom(role)
  end

  @doc """
  Check if user has any of the specified roles.
  """
  def user_has_any_role?(user, roles) when is_list(roles) do
    user_role = get_user_role(user)
    Enum.any?(roles, &(&1 == user_role))
  end

  @doc """
  Check if user can manage other users.
  """
  def can_manage_users?(user) do
    user_has_permission?(user, :user_management) or
      user_has_permission?(user, :all) or
      tenant_owner?(user)
  end

  @doc """
  Check if user can manage billing.
  """
  def can_manage_billing?(user) do
    user_has_permission?(user, :billing_management) or
      user_has_permission?(user, :all) or
      tenant_owner?(user)
  end

  @doc """
  Check if user can view reports.
  """
  def can_view_reports?(user) do
    user_has_permission?(user, :view_reports) or
      user_has_permission?(user, :all) or
      tenant_owner?(user)
  end

  @doc """
  Check if user can access system settings.
  """
  def can_access_system_settings?(user) do
    user_has_permission?(user, :system_configuration) or
      user_has_permission?(user, :all) or
      tenant_owner?(user)
  end

  @doc """
  Check if user can invite other users.
  """
  def can_invite_users?(user) do
    user_has_permission?(user, :user_management) or
      user_has_permission?(user, :all) or
      tenant_owner?(user)
  end

  # Private helper functions

  defp get_current_user(conn) do
    conn.assigns[:current_user] ||
      conn.assigns[:current_tenant_user] ||
      get_session_user(conn)
  end

  defp get_session_user(conn) do
    case get_session(conn, :user_id) do
      nil -> nil
      # Would typically load full user from database
      user_id -> %{id: user_id}
    end
  end

  defp get_tenant_context(conn) do
    conn.assigns[:tenant_context] ||
      conn.assigns[:current_tenant]
  end

  defp user_in_tenant?(user, tenant_context) do
    # This would typically check if the user belongs to the current tenant
    # For now, we'll assume the user is in the tenant if they have a tenant user record
    user_tenant_id = Map.get(user, :tenant_id) || Map.get(user, :tenant_user_id)
    current_tenant_id = Map.get(tenant_context, :id) || Map.get(tenant_context, :tenant_id)

    user_tenant_id == current_tenant_id or Map.get(user, :is_tenant_owner, false)
  end

  defp authorized?(user, _tenant_context, opts) do
    # Check tenant owner bypass
    if Keyword.get(opts, :allow_tenant_owners, true) and tenant_owner?(user) do
      true
    else
      # Check required roles
      required_roles = Keyword.get(opts, :required_roles, [])

      if Enum.empty?(required_roles) || user_has_any_role?(user, required_roles) do
        # Check required permissions
        required_permissions = Keyword.get(opts, :required_permissions, [])
        Enum.empty?(required_permissions) || user_has_all_permissions?(user, required_permissions)
      else
        false
      end
    end
  end

  defp get_user_permissions(user) do
    case user do
      %{permissions: permissions} when is_list(permissions) ->
        permissions

      %{role: role} ->
        get_role_permissions(role)

      _ ->
        []
    end
  end

  defp get_user_role(user) do
    Map.get(user, :role, :viewer)
  end

  defp tenant_owner?(user) do
    Map.get(user, :is_tenant_owner, false)
  end

  defp get_role_permissions(:admin),
    do: [:all, :user_management, :billing_management, :support_management, :system_configuration]

  defp get_role_permissions(:operator), do: [:manage_customers, :view_billing, :basic_operations]
  defp get_role_permissions(:viewer), do: [:view_only]

  defp get_role_permissions(:billing_admin),
    do: [:manage_billing, :view_customers, :view_operations]

  defp get_role_permissions(:support_admin),
    do: [:manage_support, :view_customers, :view_billing, :view_operations]

  defp get_role_permissions(_), do: []

  defp handle_unauthorized(conn, reason) do
    Logger.warning(
      "Authorization failed: #{inspect(reason)} for user: #{inspect(get_current_user(conn))}"
    )

    conn
    |> put_status(:forbidden)
    |> put_resp_content_type("application/json")
    |> json_response(%{
      error: "Unauthorized",
      reason: reason,
      message: format_error_message(reason)
    })
    |> halt()
  end

  defp json_response(conn, data) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> resp(conn.status || 200, Jason.encode!(data))
  end

  defp format_error_message(:no_user), do: "Authentication required"
  defp format_error_message(:no_tenant_context), do: "Tenant context required"
  defp format_error_message(:user_not_in_tenant), do: "You don't have access to this tenant"

  defp format_error_message(:insufficient_permissions),
    do: "You don't have permission to access this resource"

  defp format_error_message(_), do: "Access denied"
end
