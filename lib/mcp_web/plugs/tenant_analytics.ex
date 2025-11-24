defmodule McpWeb.Plugs.TenantAnalytics do
  @moduledoc """
  Plug for ensuring tenant analytics isolation and permissions.

  This plug ensures that all analytics operations are properly isolated
  to the tenant context and that users have appropriate permissions
  to access analytics features.
  """

  import Plug.Conn
  alias Mcp.Platform.Tenant

  def init(opts), do: opts

  def call(conn, _opts) do
    # Ensure tenant context is set for analytics operations
    case ensure_tenant_context(conn) do
      {:ok, conn} ->
        ensure_analytics_permissions(conn)

      {:error, conn} ->
        conn
        |> put_status(:forbidden)
        |> halt()
    end
  end

  defp ensure_tenant_context(conn) do
    case get_tenant_from_conn(conn) do
      nil ->
        # No tenant context - analytics not available
        {:error, conn}

      tenant ->
        # Set tenant context for all subsequent operations
        conn =
          conn
          |> assign(:current_tenant, tenant)
          |> assign(:tenant_id, tenant.id)

        {:ok, conn}
    end
  end

  defp get_tenant_from_conn(conn) do
    # Try to get tenant from different sources
    cond do
      # From subdomain
      conn.host && get_tenant_by_subdomain(conn.host) ->
        get_tenant_by_subdomain(conn.host)

      # From current user's default tenant
      conn.assigns[:current_user] ->
        get_user_tenant(conn.assigns[:current_user])

      # From custom domain
      conn.host && get_tenant_by_custom_domain(conn.host) ->
        get_tenant_by_custom_domain(conn.host)

      true ->
        nil
    end
  end

  defp get_tenant_by_subdomain(host) do
    # Extract subdomain from host
    subdomain =
      host
      |> String.split(".")
      |> List.first()
      |> String.trim()

    if subdomain && subdomain != "www" do
      case Tenant.by_subdomain(subdomain) do
        [tenant | _] -> tenant
        _ -> nil
      end
    else
      nil
    end
  end

  defp get_tenant_by_custom_domain(host) do
    case Tenant.by_custom_domain(host) do
      {:ok, tenant} -> tenant
      _ -> nil
    end
  end

  defp get_user_tenant(user) do
    case user.tenant_id do
      nil -> nil
      tenant_id -> Tenant.by_id!(tenant_id)
    end
  end

  defp ensure_analytics_permissions(conn) do
    user = conn.assigns[:current_user]

    cond do
      # Super admin has access to all analytics
      user && user.role == :super_admin ->
        conn

      # Check if user has analytics access for this tenant
      user && has_analytics_permission?(user, conn.assigns[:current_tenant]) ->
        conn

      # Check for public dashboard access
      is_public_analytics_request?(conn) ->
        conn

      true ->
        conn
        |> put_status(:forbidden)
        |> halt()
    end
  end

  defp has_analytics_permission?(user, tenant) do
    # User belongs to the tenant and has analytics role
    user.tenant_id == tenant.id && has_analytics_role?(user.role)
  end

  defp has_analytics_role?(:admin), do: true
  defp has_analytics_role?(:manager), do: true
  defp has_analytics_role?(:analyst), do: true
  defp has_analytics_role?(:operator), do: true
  defp has_analytics_role?(_), do: false

  defp is_public_analytics_request?(conn) do
    # Check if this is a request for a public dashboard or report
    path = conn.request_path

    cond do
      String.starts_with?(path, "/analytics/public") -> true
      String.contains?(path, "/dashboards/") && is_public_dashboard_request?(conn) -> true
      true -> false
    end
  end

  defp is_public_dashboard_request?(conn) do
    # Check if the requested dashboard is public
    dashboard_slug = get_dashboard_slug_from_path(conn.request_path)

    if dashboard_slug do
      # This would query the database to check if dashboard is public
      # For now, return false
      false
    else
      false
    end
  end

  defp get_dashboard_slug_from_path(path) do
    case Regex.run(~r{/dashboards/([^/]+)}, path) do
      [_match, slug] -> slug
      _ -> nil
    end
  end
end
