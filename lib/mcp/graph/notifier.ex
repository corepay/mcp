defmodule Mcp.Graph.Notifier do
  @moduledoc """
  Ash Notifier to sync resources with Apache AGE graph.
  Ensures that every Merchant, Reseller, and Tenant has a corresponding node in the graph.
  """
  use Ash.Notifier

  alias Mcp.Graph.TenantContext
  alias Mcp.Platform.{Merchant, Reseller, Tenant}

  @impl true
  def notify(notification) do
    # In Ash 3.0, tenant is available on the changeset or in the notification
    tenant =
      Map.get(notification, :tenant) || (notification.changeset && notification.changeset.tenant)

    # Only sync on create and update
    if notification.action.type in [:create, :update] do
      sync_to_graph(notification.resource, notification.data, tenant)
    end
  end

  def sync_to_graph(Merchant, merchant, tenant) do
    tenant_slug = get_tenant_slug(tenant)

    # Cypher for Merchant
    cypher = """
    MERGE (m:Merchant {id: $id})
    SET m.business_name = $business_name,
        m.status = $status,
        m.updated_at = $updated_at
    """

    params = [
      id: to_string(merchant.id),
      business_name: merchant.business_name,
      status: to_string(merchant.status),
      updated_at: DateTime.to_iso8601(merchant.updated_at || DateTime.utc_now())
    ]

    TenantContext.execute_cypher(tenant_slug, "graph", cypher, params)

    # Handle relationship to Reseller if present
    if merchant.reseller_id do
      rel_cypher = """
      MATCH (m:Merchant {id: $merchant_id})
      MERGE (r:Reseller {id: $reseller_id})
      MERGE (r)-[:MANAGES]->(m)
      """

      TenantContext.execute_cypher(tenant_slug, "graph", rel_cypher,
        merchant_id: to_string(merchant.id),
        reseller_id: to_string(merchant.reseller_id)
      )
    end
  end

  def sync_to_graph(Reseller, reseller, tenant) do
    tenant_slug = get_tenant_slug(tenant)

    cypher = """
    MERGE (r:Reseller {id: $id})
    SET r.company_name = $company_name,
        r.status = $status,
        r.updated_at = $updated_at
    """

    TenantContext.execute_cypher(tenant_slug, "graph", cypher,
      id: to_string(reseller.id),
      company_name: reseller.company_name,
      status: to_string(reseller.status),
      updated_at: DateTime.to_iso8601(reseller.updated_at || DateTime.utc_now())
    )
  end

  def sync_to_graph(_, _, _), do: :ok

  def get_tenant_slug(nil), do: "default"

  def get_tenant_slug(tenant) when is_binary(tenant) do
    # If tenant is the schema name (acq_...), strip the prefix
    if String.starts_with?(tenant, "acq_") do
      String.replace_prefix(tenant, "acq_", "")
    else
      tenant
    end
  end

  def get_tenant_slug(%Tenant{slug: slug}), do: slug

  def get_tenant_slug(tenant) do
    # Try to fetch if it's an ID
    case Tenant.get_by_id(tenant) do
      {:ok, t} -> t.slug
      _ -> to_string(tenant)
    end
  end
end
