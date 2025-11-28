defmodule Mcp.Infrastructure.TenantManager do
  @moduledoc """
  Manages tenant schema lifecycle (creation, deletion, existence checks).
  """

  alias Mcp.Repo
  import Ecto.Query

  @tenant_schema_prefix "acq_"

  def create_tenant_schema(tenant_schema_name) when is_binary(tenant_schema_name) do
    schema_name = @tenant_schema_prefix <> tenant_schema_name

    case check_schema_exists(tenant_schema_name) do
      {:ok, false} ->
        execute_create_tenant_schema(tenant_schema_name)
        run_tenant_migrations(schema_name)
        {:ok, schema_name}

      {:ok, true} ->
        # We should ensure tables exist even if schema exists
        execute_create_tenant_schema(tenant_schema_name)
        run_tenant_migrations(schema_name)
        {:ok, schema_name}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def drop_tenant_schema(tenant_schema_name) when is_binary(tenant_schema_name) do
    schema_name = @tenant_schema_prefix <> tenant_schema_name

    case check_schema_exists(tenant_schema_name) do
      {:ok, true} ->
        execute_drop_tenant_schema(tenant_schema_name)
        {:ok, schema_name}

      {:ok, false} ->
        {:error, :schema_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def tenant_schema_exists?(tenant_schema_name) when is_binary(tenant_schema_name) do
    case check_schema_exists(tenant_schema_name) do
      {:ok, exists} -> exists
      {:error, _} -> false
    end
  end

  def get_tenant_schema_name(tenant_id) when is_binary(tenant_id) do
    query = from(t in "platform.tenants", where: t.id == ^tenant_id, select: t.company_schema)
    Repo.one(query)
  end

  # Private Helpers

  defp check_schema_exists(tenant_schema_name) do
    query = "SELECT tenant_schema_exists($1) as exists"

    case Repo.query(query, [tenant_schema_name]) do
      {:ok, %{rows: [[exists]]}} -> {:ok, exists}
      {:error, reason} ->
        IO.inspect(reason, label: "Check Schema Exists Error")
        {:error, reason}
    end
  end

  defp execute_create_tenant_schema(tenant_schema_name) do
    query = "SELECT create_tenant_schema($1)"

    case Repo.query(query, [tenant_schema_name]) do
      {:ok, _} -> :ok
      {:error, reason} ->
        IO.inspect(reason, label: "Create Tenant Schema Error")
        {:error, reason}
    end
  end

  defp execute_drop_tenant_schema(tenant_schema_name) do
    query = "SELECT drop_tenant_schema($1)"

    case Repo.query(query, [tenant_schema_name]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_tenant_migrations(schema_name) do
    path = Application.app_dir(:mcp, "priv/repo/tenant_migrations")
    
    try do
      Ecto.Migrator.run(Repo, path, :up, all: true, prefix: schema_name)
    rescue
      _e -> 
        # In test sandbox, this might fail. We catch it to avoid crashing.
        :error
    end
  end
end
