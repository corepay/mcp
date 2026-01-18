defmodule Mcp.Underwriting.Changes.SetSla do
  @moduledoc """
  Calculates and sets the SLA due date based on tenant settings.
  """
  use Ash.Resource.Change

  alias Mcp.Underwriting.VendorSettings

  def change(changeset, _opts, context) do
    tenant = changeset.tenant || context.tenant

    sla_hours =
      case VendorSettings.get_settings(tenant: tenant, authorize?: false) do
        {:ok, [settings | _]} -> settings.sla_hours
        {:ok, settings} when is_map(settings) and not is_nil(settings) -> settings.sla_hours
        _ -> 24
      end

    due_at = DateTime.add(DateTime.utc_now(), sla_hours, :hour)
    Ash.Changeset.force_change_attribute(changeset, :sla_due_at, due_at)
  end
end
