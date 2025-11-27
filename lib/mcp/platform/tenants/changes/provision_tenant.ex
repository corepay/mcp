defmodule Mcp.Platform.Tenants.Changes.ProvisionTenant do
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, tenant ->
      # Extract the suffix from the full schema name (e.g. "acq_uuid" -> "uuid")
      schema_suffix = String.replace_prefix(tenant.company_schema, "acq_", "")
      
      case Mcp.MultiTenant.create_tenant_schema(schema_suffix) do
        {:ok, _schema_name} ->
          # In a real scenario, we would also run migrations here
          # Mcp.MultiTenant.run_tenant_migrations(schema_suffix)
          {:ok, tenant}

        {:error, :schema_already_exists} ->
          {:ok, tenant}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end
end
