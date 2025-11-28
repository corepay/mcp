defmodule Mcp.Secrets.VaultClient do
  @moduledoc """
  Vault client for secrets management using Supabase Vault (Postgres extension).
  """

  require Logger
  alias Mcp.Repo

  def get_secret(path, opts \\ []) do
    tenant_id = Keyword.get(opts, :tenant_id)
    full_path = build_tenant_path(path, tenant_id)

    case Repo.query("SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = $1", [
           full_path
         ]) do
      {:ok, %{rows: [[secret]]}} -> {:ok, secret}
      {:ok, %{rows: []}} -> {:error, :not_found}
      error -> error
    end
  end

  def set_secret(path, value, opts \\ []) do
    tenant_id = Keyword.get(opts, :tenant_id)
    full_path = build_tenant_path(path, tenant_id)

    # vault.create_secret(new_secret text, new_name text, new_description text DEFAULT NULL::text, new_key_id uuid DEFAULT NULL::uuid)
    # We use upsert-like logic by deleting first (simple approach) or handling conflict if vault supports it.
    # Supabase vault doesn't support upsert easily on name, so we delete first.

    Repo.transaction(fn ->
      Repo.query!("SELECT vault.create_secret($1, $2)", [value, full_path])
    end)

    {:ok, full_path}
  rescue
    e -> {:error, e}
  end

  def delete_secret(path, opts \\ []) do
    tenant_id = Keyword.get(opts, :tenant_id)
    full_path = build_tenant_path(path, tenant_id)

    # We need to find the secret ID to delete it, or delete by name if possible.
    # The vault.secrets table has 'name'.
    # DELETE FROM vault.secrets WHERE name = $1

    case Repo.query("DELETE FROM vault.secrets WHERE name = $1", [full_path]) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  def list_secrets(path_prefix, opts \\ []) do
    tenant_id = Keyword.get(opts, :tenant_id)
    full_path_prefix = build_tenant_path(path_prefix, tenant_id)

    # List secrets starting with prefix
    query = "SELECT name FROM vault.secrets WHERE name LIKE $1"

    case Repo.query(query, ["#{full_path_prefix}%"]) do
      {:ok, %{rows: rows}} -> {:ok, List.flatten(rows)}
      error -> error
    end
  end

  # Helper to maintain tenant isolation naming convention
  defp build_tenant_path(path, nil), do: path

  defp build_tenant_path(path, tenant_id) do
    if String.starts_with?(path, "tenants/") do
      path
    else
      "tenants/#{tenant_id}/#{path}"
    end
  end
end
