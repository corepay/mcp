defmodule McpWeb.TenantRouting do
  @moduledoc """
  Plug for tenant identification and routing based on subdomain or custom domain.

  This plug extracts tenant information from the HTTP host and sets up the proper
  tenant context for the request, enabling multi-tenancy via subdomain routing.
  """

  import Plug.Conn

  alias Mcp.Platform.Tenant
  require Logger

  @doc """
  Initialize the plug with configuration options.
  """
  def init(opts \\ []) do
    Keyword.merge(
      [
        base_domain: get_base_domain(),
        fallback_tenant: nil,
        skip_subdomain_extraction: false
      ],
      opts
    )
  end

  @doc """
  Call the plug to handle tenant routing.
  """
  def call(conn, opts) do
    if Keyword.get(opts, :skip_subdomain_extraction, false) do
      conn
    else
      case extract_tenant_from_host(conn, opts) do
        {:ok, tenant} ->
          setup_tenant_context(conn, tenant)

        {:error, :tenant_not_found} ->
          handle_tenant_not_found(conn, opts)

        {:error, :invalid_host} ->
          handle_invalid_host(conn, opts)
      end
    end
  end

  @doc """
  Extract tenant information from the current connection.
  """
  def get_current_tenant(conn) do
    conn.assigns[:current_tenant]
  end

  @doc """
  Check if the current request is in a tenant context.
  """
  def tenant_context?(conn) do
    not is_nil(conn.assigns[:current_tenant])
  end

  @doc """
  Get the base domain for tenant routing.
  """
  def get_base_domain do
    Application.get_env(:mcp, :base_domain, "localhost")
  end

  # Private functions

  defp extract_tenant_from_host(conn, _opts) do
    host = get_host(conn)

    if is_nil(host) or host == "" do
      {:error, :invalid_host}
    else
      case identify_tenant_from_host(host) do
        {:ok, tenant} -> {:ok, tenant}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp get_host(conn) do
    # Try various headers to get the actual host
    case get_req_header(conn, "x-forwarded-host") do
      [host | _] ->
        String.downcase(host)

      [] ->
        case get_req_header(conn, "host") do
          [host | _] -> String.downcase(host)
          [] -> nil
        end
    end
  end

  defp identify_tenant_from_host(host) do
    # Remove port if present
    host_without_port = String.split(host, ":") |> List.first()

    cond do
      # Check for custom domain first
      tenant_by_custom_domain =
          Tenant.by_custom_domain!(host_without_port)
          |> Enum.at(0) ->
        {:ok, tenant_by_custom_domain}

      # Check for subdomain pattern
      matches_subdomain_pattern?(host_without_port) ->
        subdomain = extract_subdomain_from_host(host_without_port)

        case Tenant.by_subdomain!(subdomain) |> Enum.at(0) do
          nil -> {:error, :tenant_not_found}
          tenant -> {:ok, tenant}
        end

      # Base domain - no tenant context
      base_domain?(host_without_port) ->
        {:error, :tenant_not_found}

      # Unknown pattern
      true ->
        {:error, :tenant_not_found}
    end
  rescue
    Ash.Error.Invalid.NoSuchResource -> {:error, :tenant_not_found}
    Ash.Error.Query.NotFound -> {:error, :tenant_not_found}
    _ -> {:error, :tenant_not_found}
  end

  defp matches_subdomain_pattern?(host) do
    base_domain = get_base_domain()
    String.ends_with?(host, ".#{base_domain}") and String.contains?(host, ".")
  end

  defp base_domain?(host) do
    base_domain = get_base_domain()
    host == base_domain or host == "www.#{base_domain}"
  end

  defp extract_subdomain_from_host(host) do
    base_domain = get_base_domain()
    subdomain_part = String.replace_prefix(host, ".#{base_domain}", "")

    # Handle potential www prefix for base domain
    case String.split(subdomain_part, ".") do
      [subdomain] -> subdomain
      [subdomain | _] -> subdomain
      [] -> host
    end
  end

  defp setup_tenant_context(conn, tenant) do
    conn
    |> assign(:current_tenant, tenant)
    |> assign(:tenant_schema, tenant.company_schema)
    |> assign(:tenant_id, tenant.id)
    |> put_private(:tenant_id, tenant.id)
    |> put_private(:tenant_schema, tenant.company_schema)
  end

  defp handle_tenant_not_found(conn, opts) do
    fallback_tenant = Keyword.get(opts, :fallback_tenant)

    if fallback_tenant do
      # In development, you might want to fall back to a default tenant
      conn
      |> assign(:current_tenant, nil)
      |> assign(:tenant_schema, nil)
      |> assign(:tenant_id, nil)
    else
      # In production, return 404 for unknown tenants
      if Application.get_env(:mcp, :env) == :prod do
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(:not_found, render_tenant_not_found_page())
        |> halt()
      else
        # In development, continue without tenant context for debugging
        conn
        |> assign(:current_tenant, nil)
        |> assign(:tenant_schema, nil)
        |> assign(:tenant_id, nil)
      end
    end
  end

  defp handle_invalid_host(conn, _opts) do
    if Mix.env() == :test do
      conn
    else
      host = get_host(conn)
      Logger.warning("Invalid host access attempt: #{host}")

      conn
      |> put_resp_content_type("text/html")
      |> send_resp(:bad_request, "Invalid host header")
      |> halt()
    end
  end

  defp render_tenant_not_found_page do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Tenant Not Found</title>
      <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #e53e3e; }
        p { color: #4a5568; }
      </style>
    </head>
    <body>
      <h1>Tenant Not Found</h1>
      <p>The requested tenant could not be found or may have been deactivated.</p>
      <p>Please check the URL and try again.</p>
    </body>
    </html>
    """
  end
end
