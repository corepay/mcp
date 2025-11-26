defmodule Mcp.Platform.SchemaProvisioner do
  @moduledoc """
  Schema provisioning for multi-tenant architecture.

  Orchestrates tenant schema creation, initialization, and cleanup
  using the Mcp.MultiTenant infrastructure.
  """

  alias Mcp.MultiTenant
  alias Mcp.Repo
  require Logger

  @doc """
  Provisions a new tenant schema with all extensions and tables.

  Steps:
  1. Create the schema using MultiTenant
  2. Initialize extensions (TimescaleDB, PostGIS, pgvector, Apache AGE)
  3. Run tenant-scoped migrations
  4. Verify schema is ready

  Returns {:ok, schema_info} or {:error, reason}
  """
  def provision_tenant_schema(tenant_id, tenant_name) do
    schema_name = get_schema_name_from_tenant_id(tenant_id)

    Logger.info("Provisioning schema for tenant: #{tenant_name} (#{schema_name})")

    with {:ok, _} <- MultiTenant.create_tenant_schema(tenant_id),
         :ok <- initialize_schema_extensions(schema_name),
         :ok <- verify_schema_ready(schema_name) do
      Logger.info("Successfully provisioned schema: #{schema_name}")

      {:ok,
       %{
         schema: schema_name,
         tenant_id: tenant_id,
         name: tenant_name,
         status: :active,
         provisioned_at: DateTime.utc_now()
       }}
    else
      {:error, :schema_already_exists} ->
        Logger.warning("Schema already exists: #{schema_name}")
        {:error, :schema_already_exists}

      {:error, reason} = error ->
        Logger.error("Failed to provision schema #{schema_name}: #{inspect(reason)}")
        # Attempt cleanup on failure
        cleanup_failed_provision(tenant_id)
        error
    end
  end

  @doc """
  Deprovisions a tenant schema (drops the schema and all data).

  WARNING: This is destructive and cannot be undone!
  """
  def deprovision_tenant_schema(tenant_id) do
    schema_name = get_schema_name_from_tenant_id(tenant_id)

    Logger.warning("Deprovisioning schema: #{schema_name}")

    case MultiTenant.drop_tenant_schema(tenant_id) do
      {:ok, _} ->
        Logger.info("Successfully deprovisioned schema: #{schema_name}")
        {:ok, %{tenant_id: tenant_id, schema: schema_name, deprovisioned: true}}

      {:error, :schema_not_found} ->
        Logger.warning("Schema not found for deprovisioning: #{schema_name}")
        {:error, :schema_not_found}

      {:error, reason} = error ->
        Logger.error("Failed to deprovision schema #{schema_name}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Gets the provisioning status for a tenant schema.
  """
  def get_schema_status(tenant_id) do
    schema_name = get_schema_name_from_tenant_id(tenant_id)

    case MultiTenant.tenant_schema_exists?(tenant_id) do
      true ->
        {:ok,
         %{
           tenant_id: tenant_id,
           schema: schema_name,
           status: :active,
           exists: true
         }}

      false ->
        {:ok,
         %{
           tenant_id: tenant_id,
           schema: schema_name,
           status: :not_provisioned,
           exists: false
         }}
    end
  end

  @doc """
  Lists all provisioned tenant schemas.
  """
  def list_schemas do
    query = """
    SELECT nspname as schema_name
    FROM pg_namespace
    WHERE nspname LIKE 'acq_%'
    ORDER BY nspname
    """

    case Repo.query(query) do
      {:ok, %{rows: rows}} ->
        schemas =
          Enum.map(rows, fn [schema_name] ->
            tenant_id = String.replace_prefix(schema_name, "acq_", "")

            %{
              schema: schema_name,
              tenant_id: tenant_id,
              status: :active
            }
          end)

        {:ok, schemas}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates that a schema exists.
  """
  def schema_exists?(schema_name) when is_binary(schema_name) do
    # Remove acq_ prefix if present for MultiTenant call
    tenant_id = String.replace_prefix(schema_name, "acq_", "")
    MultiTenant.tenant_schema_exists?(tenant_id)
  end

  @doc """
  Provisions schema automatically when a tenant is created.

  This is meant to be called from a Tenant resource change/after_action.
  """
  def auto_provision_on_create(tenant) do
    case provision_tenant_schema(tenant.id, tenant.name) do
      {:ok, _schema_info} ->
        {:ok, tenant}

      {:error, reason} ->
        Logger.error("Auto-provision failed for tenant #{tenant.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp get_schema_name_from_tenant_id(tenant_id) do
    "acq_#{tenant_id}"
  end

  defp initialize_schema_extensions(schema_name) do
    # Extensions are initialized by the create_tenant_schema function
    # in the database via the stored procedure
    # This function can be extended if additional initialization is needed
    Logger.debug("Schema extensions initialized for: #{schema_name}")
    :ok
  end

  defp verify_schema_ready(schema_name) do
    # Verify the schema exists and is accessible
    query = """
    SELECT EXISTS (
      SELECT 1 FROM pg_namespace WHERE nspname = $1
    )
    """

    case Repo.query(query, [schema_name]) do
      {:ok, %{rows: [[true]]}} ->
        :ok

      {:ok, %{rows: [[false]]}} ->
        {:error, :schema_verification_failed}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cleanup_failed_provision(tenant_id) do
    # Attempt to clean up any partially created schema
    case MultiTenant.drop_tenant_schema(tenant_id) do
      {:ok, _} ->
        Logger.info("Cleaned up failed provision for tenant: #{tenant_id}")
        :ok

      {:error, _} ->
        Logger.warning("Could not clean up failed provision for tenant: #{tenant_id}")
        :ok
    end
  end
end
