defmodule McpWeb.Plugs.ContextPlug do
  @moduledoc """
  Resolves the application context (:platform, :tenant, :merchant, :store) based on the request host/subdomain.

  It assigns the following to `conn.assigns`:
  - `:context_type` -> :platform, :tenant, :merchant, :store
  - `:context_entity` -> The actual Tenant/Merchant/Store struct (or nil for platform)
  - `:tenant_schema` -> The database schema for multi-tenancy (if applicable)

  Logic:
  1. `platform.base.do` or `admin.base.do` -> :platform
  2. `{tenant_slug}.base.do` -> Tenant Context
  3. `{merchant_slug}.base.do` -> Merchant Context (via global slug lookup)
  4. `{merchant_slug}.{tenant_slug}.base.do` -> Explicit Merchant Context (Future proofing)
  """
  import Plug.Conn
  require Logger
  alias Mcp.Platform.Merchant
  alias Mcp.Platform.Tenant

  def init(opts) do
    Keyword.merge(opts,
      tenant_resource: Keyword.get(opts, :tenant_resource, Tenant),
      merchant_resource: Keyword.get(opts, :merchant_resource, Merchant)
    )
  end

  def call(conn, opts) do
    host = get_host(conn)
    base_domain = Application.get_env(:mcp, :base_domain, "localhost")

    # Try cache first
    case fetch_from_cache(host) do
      {:ok, {context_type, entity, custom_assigns}} ->
        setup_from_cache(conn, context_type, entity, custom_assigns)

      _ ->
        resolve_and_cache(conn, host, base_domain, opts)
    end
  end

  defp resolve_and_cache(conn, host, base_domain, opts) do
    cond do
      # 1. Platform / Admin
      host == "platform.#{base_domain}" or host == "admin.#{base_domain}" ->
        conn
        |> set_context(:platform, nil)
        |> cache_context(host)

      # 2. Subdomain processing
      String.ends_with?(host, ".#{base_domain}") ->
        subdomain = String.replace(host, ".#{base_domain}", "")
        resolve_subdomain(conn, subdomain, host, opts)

      # 3. Fallback / Dev (localhost)
      host == "localhost" or host == base_domain ->
        # In dev, maybe we default to platform or no context
        conn
        |> set_context(:platform, nil)
        |> cache_context(host)

      true ->
        not_found(conn)
    end
  end

  defp resolve_subdomain(conn, subdomain, host, opts) do
    case String.split(subdomain, ".") do
      [slug] ->
        resolve_tenant_subdomain(conn, slug, host, opts)

      [merchant_slug, tenant_slug] ->
        resolve_merchant_subdomain(conn, merchant_slug, tenant_slug, host, opts)

      _ ->
        not_found(conn)
    end
  end

  defp resolve_tenant_subdomain(conn, slug, host, opts) do
    tenant_resource = opts[:tenant_resource]

    case tenant_resource.by_subdomain(slug) do
      {:ok, tenant} ->
        conn
        |> setup_tenant_context(tenant)
        |> cache_context(host)

      _ ->
        not_found(conn)
    end
  end

  defp resolve_merchant_subdomain(conn, merchant_slug, tenant_slug, host, opts) do
    tenant_resource = opts[:tenant_resource]
    merchant_resource = opts[:merchant_resource]

    case tenant_resource.by_subdomain(tenant_slug) do
      {:ok, tenant} ->
        conn = setup_tenant_context(conn, tenant)
        lookup_merchant(conn, merchant_resource, merchant_slug, tenant, host)

      _ ->
        not_found(conn)
    end
  end

  defp lookup_merchant(conn, merchant_resource, merchant_slug, tenant, host) do
    case merchant_resource.by_slug(merchant_slug, tenant: tenant) do
      {:ok, merchant} ->
        conn
        |> setup_merchant_context(merchant)
        |> cache_context(host)

      _ ->
        not_found(conn)
    end
  end

  defp not_found(conn) do
    conn
    |> send_resp(404, "Organization not found")
    |> halt()
  end

  defp setup_tenant_context(conn, tenant) do
    conn
    |> assign(:context_type, :tenant)
    |> assign(:context_entity, tenant)
    # Backward compat
    |> assign(:current_tenant, tenant)
    # For Ash Multitenancy
    |> assign(:tenant_schema, tenant.company_schema)
    # Ash automatic tenant setting if using Plug
    |> put_private(:ash_tenant, tenant.company_schema)
  end

  defp setup_merchant_context(conn, merchant) do
    # Merchants belong to a tenant. We need to load the tenant to set the schema.
    # We assume we can get the tenant_id from merchant, or we need to preload it.
    conn
    |> assign(:context_type, :merchant)
    |> assign(:context_entity, merchant)
  end

  defp set_context(conn, type, entity) do
    conn
    |> assign(:context_type, type)
    |> assign(:context_entity, entity)
  end

  defp get_host(conn) do
    case get_req_header(conn, "x-forwarded-host") do
      [host | _] -> String.downcase(host) |> String.split(":") |> List.first()
      [] -> conn.host
    end
  end

  # --- Caching Helpers ---

  defp fetch_from_cache(host) do
    case Redix.command(:redix_cache, ["GET", routing_key(host)]) do
      {:ok, nil} ->
        :miss

      {:ok, binary} when is_binary(binary) ->
        try do
          {:ok, :erlang.binary_to_term(binary)}
        rescue
          _ -> :miss
        end

      _ ->
        :miss
    end
  end

  defp setup_from_cache(conn, context_type, entity, custom_assigns) do
    conn =
      conn
      |> assign(:context_type, context_type)
      |> assign(:context_entity, entity)

    # Rehydrate other assignments
    Enum.reduce(custom_assigns, conn, fn {key, val}, acc ->
      if key == :ash_tenant do
        put_private(acc, :ash_tenant, val)
      else
        assign(acc, key, val)
      end
    end)
  end

  defp cache_context(conn, host) do
    # Extract what we want to cache
    context_type = conn.assigns[:context_type]
    entity = conn.assigns[:context_entity]

    # Capture other critical assigns we might have set
    custom_assigns =
      %{
        current_tenant: conn.assigns[:current_tenant],
        tenant_schema: conn.assigns[:tenant_schema],
        ash_tenant: conn.private[:ash_tenant]
      }
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    data = {context_type, entity, custom_assigns}
    binary = :erlang.term_to_binary(data)

    # TTL: 5 minutes = 300 seconds
    Redix.command(:redix_cache, ["SET", routing_key(host), binary, "EX", "300"])

    conn
  end

  defp routing_key(host), do: "routing:#{host}"
end
