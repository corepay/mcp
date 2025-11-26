defmodule Mcp.Platform.Tenant.Changes.ProvisionSchema do
  @moduledoc """
  Ash change for automatically provisioning tenant schemas.

  This change triggers the schema provisioning workflow when a tenant is created,
  ensuring that the tenant's database schema is properly initialized with all
  required tables, extensions, and initial data.
  """

  use Ash.Resource.Change

  alias Mcp.Platform.SchemaProvisioner

  @doc """
  Provision tenant schema after tenant creation.
  """
  def change(changeset, opts, _context) do
    if create_action?(changeset) && has_slug?(changeset) do
      setup_schema_provisioning(changeset, opts)
    else
      changeset
    end
  end

  defp create_action?(changeset), do: changeset.action_type == :create

  defp has_slug?(changeset) do
    Ash.Changeset.get_attribute(changeset, :slug) != nil
  end

  defp setup_schema_provisioning(changeset, opts) do
    slug = Ash.Changeset.get_attribute(changeset, :slug)

    Ash.Changeset.after_action(changeset, fn _changeset, tenant ->
      provision_schema_async(slug, opts)
      # Schema provisioning is async, don't fail tenant creation if it has issues
      {:ok, tenant}
    end)
  end

  defp provision_schema_async(tenant_slug, opts) do
    # Use Task.Supervisor to provision schema asynchronously
    # This prevents blocking the tenant creation process
    Task.Supervisor.start_child(Mcp.TaskSupervisor, fn ->
      try do
        SchemaProvisioner.provision_tenant_schema(tenant_slug, opts)
        :ok
      rescue
        error ->
          {:error, error}
      catch
        :exit, reason ->
          {:error, reason}
      end
    end)

    :ok
  end
end
