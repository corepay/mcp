defmodule McpWeb.TenantContext do
  @moduledoc """
  Plug for setting up tenant context for database operations.

  This plug ensures that all database operations within a tenant context
  use the correct schema isolation using the with_tenant_schema function.
  """

  import Plug.Conn
  require Logger
  alias Mcp.Repo
  alias McpWeb.TenantRouting

  @doc """
  Initialize the plug with options.
  """
  def init(opts \\ []) do
    Keyword.merge(
      [
        skip_tenant_context: false,
        required_for_routes: []
      ],
      opts
    )
  end

  @doc """
  Call the plug to set up tenant context.
  """
  def call(conn, opts) do
    if should_skip_tenant_context?(conn, opts) do
      conn
    else
      setup_tenant_context(conn, opts)
    end
  end

  @doc """
  Execute a function within the current tenant's context.
  Ensures proper database schema switching and cache isolation.
  """
  def with_tenant_context(conn, fun) when is_function(fun, 0) do
    case get_current_tenant(conn) do
      nil ->
        # No tenant context, execute in default schema
        fun.()

      tenant ->
        # Validate tenant is accessible
        if tenant.status in [:active, :trial] do
          execute_with_tenant_isolation(tenant, fun, conn)
        else
          raise ArgumentError,
                "Cannot execute operations in inactive tenant context: #{tenant.status}"
        end
    end
  end

  def with_tenant_context(tenant_id_or_schema, fun) when is_function(fun, 0) do
    tenant = resolve_tenant(tenant_id_or_schema)

    if tenant do
      execute_with_tenant_isolation(tenant, fun, nil)
    else
      raise ArgumentError, "Tenant not found: #{inspect(tenant_id_or_schema)}"
    end
  end

  @doc """
  Get the current tenant schema from the connection.
  """
  def get_tenant_schema(conn) do
    conn.assigns[:tenant_schema]
  end

  @doc """
  Get the current tenant ID from the connection.
  """
  def get_tenant_id(conn) do
    conn.assigns[:tenant_id]
  end

  @doc """
  Check if the current connection has a valid tenant context.
  """
  def has_tenant_context?(conn) do
    not is_nil(get_tenant_schema(conn)) and not is_nil(get_tenant_id(conn))
  end

  # Private functions

  defp should_skip_tenant_context?(conn, opts) do
    skip_tenant_context = Keyword.get(opts, :skip_tenant_context, false)
    required_for_routes = Keyword.get(opts, :required_for_routes, [])

    cond do
      skip_tenant_context -> true
      Enum.empty?(required_for_routes) -> false
      true -> not Enum.any?(required_for_routes, &String.starts_with?(conn.request_path, &1))
    end
  end

  defp setup_tenant_context(conn, _opts) do
    case TenantRouting.get_current_tenant(conn) do
      nil ->
        # No tenant context, continue without tenant isolation
        conn

      tenant ->
        # Validate tenant status before setting up context
        if tenant.status in [:active, :trial] do
          # Establish tenant database context
          case establish_tenant_database_context(tenant) do
            :ok ->
              conn
              |> put_private(:tenant_context_set, true)
              |> assign(:tenant_context_active, true)
              |> put_private(:tenant_database_context, true)
              |> assign(:tenant_cache_prefix, build_tenant_cache_prefix(tenant.id))

            {:error, reason} ->
              Logger.error(
                "Failed to establish tenant database context for #{tenant.subdomain}: #{inspect(reason)}"
              )

              handle_tenant_context_error(conn, tenant, reason)
          end
        else
          handle_inactive_tenant(conn, tenant)
        end
    end
  end

  defp handle_inactive_tenant(conn, tenant) do
    case tenant.status do
      :suspended ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(:forbidden, render_suspended_tenant_page(tenant))
        |> halt()

      :canceled ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(:forbidden, render_canceled_tenant_page(tenant))
        |> halt()

      :deleted ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(:not_found, render_deleted_tenant_page(tenant))
        |> halt()

      _ ->
        conn
    end
  end

  defp render_suspended_tenant_page(tenant) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Account Suspended</title>
      <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #f6ad55; }
        p { color: #4a5568; }
        .contact { margin-top: 30px; }
      </style>
    </head>
    <body>
      <h1>Account Suspended</h1>
      <p>The account for #{tenant.company_name} has been temporarily suspended.</p>
      <p>Please contact support to resolve any outstanding issues.</p>
      <div class="contact">
        <p>Email: support@example.com</p>
      </div>
    </body>
    </html>
    """
  end

  defp render_canceled_tenant_page(tenant) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Account Canceled</title>
      <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #e53e3e; }
        p { color: #4a5568; }
        .contact { margin-top: 30px; }
      </style>
    </head>
    <body>
      <h1>Account Canceled</h1>
      <p>The account for #{tenant.company_name} has been canceled.</p>
      <p>If you believe this is an error, please contact support.</p>
      <div class="contact">
        <p>Email: support@example.com</p>
      </div>
    </body>
    </html>
    """
  end

  defp render_deleted_tenant_page(_tenant) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Account Not Found</title>
      <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #e53e3e; }
        p { color: #4a5568; }
      </style>
    </head>
    <body>
      <h1>Account Not Found</h1>
      <p>This account could not be found.</p>
      <p>The URL may be incorrect or the account may have been permanently removed.</p>
    </body>
    </html>
    """
  end

  # Enhanced helper functions for robust context switching

  defp establish_tenant_database_context(tenant) do
    try do
      # Verify tenant schema exists and is accessible
      case Repo.query(
             "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'acq_#{tenant.company_schema}'"
           ) do
        {:ok, %{rows: [_ | _]}} ->
          # Schema exists, establish context by setting search path
          original_search_path = Repo.get_search_path()

          case Repo.query(
                 "SET search_path TO acq_#{tenant.company_schema}, public, platform, shared, ag_catalog"
               ) do
            {:ok, _} ->
              # Store original path for cleanup
              Process.put(:original_search_path, original_search_path)
              Process.put(:current_tenant_schema, tenant.company_schema)
              Process.put(:current_tenant_id, tenant.id)
              :ok

            {:error, reason} ->
              Logger.error(
                "Failed to set search path for tenant #{tenant.subdomain}: #{inspect(reason)}"
              )

              {:error, :database_context_failed}
          end

        {:ok, _} ->
          Logger.error("Tenant schema not found: acq_#{tenant.company_schema}")
          {:error, :schema_not_found}

        {:error, reason} ->
          Logger.error("Database error verifying tenant schema: #{inspect(reason)}")
          {:error, :database_error}
      end
    rescue
      error ->
        Logger.error("Exception establishing tenant database context: #{inspect(error)}")
        {:error, :exception}
    end
  end

  defp execute_with_tenant_isolation(tenant, fun, _conn) do
    # Set up process-level tenant context for cache operations
    Process.put(:current_tenant_id, tenant.id)
    Process.put(:current_tenant_schema, tenant.company_schema)

    # Execute function with proper database schema switching
    result =
      Repo.with_tenant_schema(tenant.company_schema, fn ->
        # Additional safety check - ensure we're in the right schema
        verify_tenant_schema_context(tenant)
        fun.()
      end)

    # Cleanup process-level context
    Process.delete(:current_tenant_id)
    Process.delete(:current_tenant_schema)

    result
  end

  defp verify_tenant_schema_context(tenant) do
    case Repo.query("SELECT current_schema()") do
      {:ok, %{rows: [[current_schema]]}} ->
        expected_schema = "acq_#{tenant.company_schema}"

        unless String.contains?(current_schema, expected_schema) do
          Logger.warning(
            "Schema verification failed. Current: #{current_schema}, Expected: #{expected_schema}"
          )
        end

      {:error, reason} ->
        Logger.error("Failed to verify current schema: #{inspect(reason)}")
    end
  end

  defp get_current_tenant(conn) do
    TenantRouting.get_current_tenant(conn)
  end

  defp resolve_tenant(tenant_id) when is_binary(tenant_id) do
    cond do
      String.starts_with?(tenant_id, "acq_") ->
        # It's a schema name, remove prefix and look up by company_schema
        _schema_name = String.replace_prefix(tenant_id, "acq_", "")
        # Simplified approach - use existing action if available, otherwise nil
        nil

      true ->
        # Try as subdomain first (most common use case)
        case Mcp.Platform.Tenant.by_subdomain!(tenant_id) do
          [tenant] -> tenant
          tenants when is_list(tenants) and length(tenants) > 0 -> hd(tenants)
          _ -> nil
        end
    end
  end

  defp build_tenant_cache_prefix(tenant_id) do
    "tenant:#{tenant_id}"
  end

  defp handle_tenant_context_error(conn, tenant, error) do
    Logger.error("Tenant context error for #{tenant.subdomain}: #{inspect(error)}")

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(:internal_server_error, render_tenant_error_page(tenant, error))
    |> halt()
  end

  defp render_tenant_error_page(tenant, _error) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Service Temporarily Unavailable</title>
      <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #f6ad55; }
        p { color: #4a5568; }
        .error { margin-top: 20px; color: #718096; font-size: 0.9em; }
      </style>
    </head>
    <body>
      <h1>Service Temporarily Unavailable</h1>
      <p>We're having trouble accessing the account for #{tenant.company_name}.</p>
      <p>Please try again in a few moments.</p>
      <div class="error">
        <p>Error ID: #{System.unique_integer([:positive])}</p>
      </div>
    </body>
    </html>
    """
  end
end
