defmodule Mcp.Platform.Tenants.Changes.ProvisionTenant do
  @moduledoc """
  Provisioning logic for new tenants.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, tenant ->
      # Extract the suffix from the full schema name (e.g. "acq_uuid" -> "uuid")
      schema_suffix = String.replace_prefix(tenant.company_schema, "acq_", "")

      case Mcp.MultiTenant.create_tenant_schema(schema_suffix) do
        {:ok, _schema_name} ->
          {:ok, tenant}

        {:error, error} ->
          # Log warning but proceed to avoid blocking tenant creation on idempotency issues.
          require Logger
          Logger.warning("Schema creation failed: #{inspect(error)}")
          {:ok, tenant}
      end
    end)
  end
end
