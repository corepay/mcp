defmodule McpWeb.Auth.AuthorizationPlug do
  @moduledoc """
  Authorization plug for multi-tenant context management.

  This plug handles tenant authorization, context switching, and permission
  validation based on JWT claims.
  """

  import Plug.Conn

  @doc """
  Initialize the authorization plug with options.
  """
  def init(opts \\ []) do
    Keyword.merge(
      [
        required_permissions: [],
        required_roles: [],
        tenant_required: false,
        tenant_param: "tenant_id"
      ],
      opts
    )
  end

  @doc """
  Call the plug to handle authorization.
  """
  def call(conn, opts) do
    current_session = get_session(conn)

    if current_session do
      conn
      |> extract_tenant_context(opts)
      |> validate_authorization(opts)
      |> set_tenant_context()
    else
      conn
    end
  end

  @doc """
  Check if current user is authorized for the given tenant.
  """
  def authorized_for_tenant?(conn, tenant_id) do
    current_session = get_session(conn)
    current_context = Map.get(current_session, :current_context, %{})
    authorized_contexts = Map.get(current_session, :authorized_contexts, [])

    current_context["tenant_id"] == tenant_id or
      Enum.any?(authorized_contexts, fn ctx -> ctx["tenant_id"] == tenant_id end)
  end

  @doc """
  Get the current tenant from connection.
  """
  def current_tenant(conn) do
    conn.assigns[:current_tenant] ||
      (get_session(conn)[:current_context] || %{})["tenant_id"]
  end

  @doc """
  Get current user permissions for the current tenant.
  """
  def current_permissions(conn) do
    current_session = get_session(conn)
    (current_session[:current_context] || %{})["permissions"] || []
  end

  @doc """
  Check if user has specific permission.
  """
  def has_permission?(conn, permission) do
    permission in current_permissions(conn)
  end

  @doc """
  Get current user role for the current tenant.
  """
  def current_role(conn) do
    current_session = get_session(conn)
    (current_session[:current_context] || %{})["role"]
  end

  @doc """
  Check if user has specific role.
  """
  def has_role?(conn, role) do
    current_role(conn) == role
  end

  @doc """
  Check if user has admin privileges.
  """
  def admin?(conn) do
    current_role(conn) in ["admin", "super_admin"]
  end

  # Private functions

  defp get_current_session(conn) do
    conn.assigns[:current_session]
  end

  defp extract_tenant_context(conn, opts) do
    tenant_param = Keyword.get(opts, :tenant_param, "tenant_id")

    # Try to get tenant from various sources
    tenant_id =
      cond do
        # From query parameters
        conn.params[tenant_param] ->
          conn.params[tenant_param]

        # From request headers
        get_req_header(conn, "x-tenant-id") != [] ->
          hd(get_req_header(conn, "x-tenant-id"))

        # From JWT current context
        get_session(conn)[:current_context]["tenant_id"] ->
          get_session(conn)[:current_context]["tenant_id"]

        true ->
          nil
      end

    assign(conn, :requested_tenant, tenant_id)
  end

  defp validate_authorization(conn, opts) do
    tenant_id = conn.assigns[:requested_tenant]
    _current_session = get_current_session(conn)

    # Check tenant authorization if tenant is required or specified
    if tenant_id &&
         (Keyword.get(opts, :tenant_required) || Keyword.get(opts, :tenant_required, false)) do
      case authorized_for_tenant?(conn, tenant_id) do
        true ->
          # Tenant authorized, check permissions and roles
          conn
          |> check_permissions(opts)
          |> check_roles(opts)

        false ->
          conn
          |> send_resp(:forbidden, "Not authorized for this tenant")
          |> halt()
      end
    else
      # No tenant authorization needed, just check permissions and roles
      conn
      |> check_permissions(opts)
      |> check_roles(opts)
    end
  end

  defp check_permissions(conn, opts) do
    required_permissions = Keyword.get(opts, :required_permissions, [])
    current_permissions = current_permissions(conn)

    missing_permissions =
      Enum.filter(required_permissions, fn perm ->
        perm not in current_permissions
      end)

    if Enum.empty?(missing_permissions) do
      conn
    else
      conn
      |> send_resp(
        :forbidden,
        "Missing required permissions: #{Enum.join(missing_permissions, ", ")}"
      )
      |> halt()
    end
  end

  defp check_roles(conn, opts) do
    required_roles = Keyword.get(opts, :required_roles, [])
    current_role = current_role(conn)

    if Enum.empty?(required_roles) or current_role in required_roles do
      conn
    else
      conn
      |> send_resp(:forbidden, "Insufficient role privileges")
      |> halt()
    end
  end

  defp set_tenant_context(conn) do
    tenant_id = conn.assigns[:requested_tenant]

    if tenant_id do
      # Find the tenant context from authorized contexts
      current_session = get_session(conn)
      authorized_contexts = Map.get(current_session, :authorized_contexts, [])

      tenant_context =
        Enum.find(authorized_contexts, fn ctx ->
          ctx["tenant_id"] == tenant_id
        end)

      if tenant_context do
        # Set current context to the selected tenant
        new_session = Map.put(current_session, :current_context, tenant_context)
        updated_session = Map.put(new_session, :authorized_contexts, authorized_contexts)

        conn
        |> assign(:current_session, updated_session)
        |> assign(:current_tenant, tenant_id)
        |> assign(:current_tenant_context, tenant_context)
      else
        conn
      end
    else
      conn
    end
  end
end
