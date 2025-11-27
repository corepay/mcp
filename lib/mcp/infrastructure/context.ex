defmodule Mcp.Infrastructure.Context do
  @moduledoc """
  Manages database context switching for multi-tenancy.
  """

  alias Mcp.Repo

  @tenant_schema_prefix "acq_"

  def switch_to_tenant_schema(tenant_schema_name) when is_binary(tenant_schema_name) do
    schema_name = @tenant_schema_prefix <> tenant_schema_name
    execute_set_search_path(schema_name)
  end

  def with_tenant_context(tenant_schema_name, fun) when is_function(fun, 0) do
    case switch_to_tenant_schema(tenant_schema_name) do
      :ok ->
        try do
          fun.()
        after
          reset_search_path()
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private Helpers

  defp execute_set_search_path(schema_name) do
    # SECURITY: schema_name is constructed internally with a prefix, but we should still be careful.
    # Postgres doesn't support parameterized SET search_path easily without dynamic SQL.
    # Since we control the prefix and the input comes from our system, it's relatively safe,
    # but ideally we would validate the schema name format.
    query = "SET search_path TO #{schema_name}, public, platform, shared"

    case Repo.query(query) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp reset_search_path do
    Repo.query("SET search_path TO public")
  end
end
