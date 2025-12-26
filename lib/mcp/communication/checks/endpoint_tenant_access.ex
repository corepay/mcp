defmodule Mcp.Communication.Checks.EndpointTenantAccess do
  @moduledoc """
  Policy check that verifies actor has access to the webhook endpoint's tenant.
  """
  use Ash.Policy.FilterCheck

  alias Mcp.Communication.WebhookEndpoint
  alias Mcp.Platform.TenantHelpers

  def describe(_opts), do: "actor has access to the endpoint's tenant"

  def filter(actor, _context, _opts) do
    tenant_ids = TenantHelpers.get_actor_tenant_ids(actor)
    expr(endpoint.tenant_id in ^tenant_ids)
  end

  def match?(actor, %{record: record}, _opts) do
    tenant_ids = TenantHelpers.get_actor_tenant_ids(actor)

    case Map.get(record, :endpoint) do
      %WebhookEndpoint{tenant_id: tenant_id} ->
        tenant_id in tenant_ids

      _ ->
        check_endpoint_access(record, tenant_ids)
    end
  end

  defp check_endpoint_access(record, tenant_ids) do
    endpoint_id = Map.get(record, :endpoint_id)

    if endpoint_id do
      case Ash.get(WebhookEndpoint, endpoint_id, authorize?: false) do
        {:ok, endpoint} -> endpoint.tenant_id in tenant_ids
        _ -> false
      end
    else
      false
    end
  end

  # Override match? to fetch?
  # Let's just define filter for now. `authorize_if` with a filter check will use filter for lists.
  # For specific records, if match? returns false, it will fail.
  # We should implement match? correctly by creating a query?
  # Or better: `authorize_if expr(...)` works if we can pin the values.
  # The issue before was `get_actor_tenant_ids(actor)` invocation syntax inside expr.
  # IF I use a generic policy that defines the ids:
  # `authorize_if {Mcp.Communication.Checks.EndpointTenantAccess, []}`
end
