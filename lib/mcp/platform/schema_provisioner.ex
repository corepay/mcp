defmodule Mcp.Platform.SchemaProvisioner do
  @moduledoc """
  Schema provisioner helper for tests.
  """

  def initialize_tenant_schema(_schema_name) do
    # Mock initialization
    {:ok, :initialized}
  end

  def backup_tenant_schema(_schema_name) do
    # Mock backup
    {:ok, "backup_file_path"}
  end

  def restore_tenant_schema(_schema_name, _backup_file) do
    # Mock restore
    :ok
  end

  def provision_tenant_schema(_schema_name, _opts \\ []) do
    # Mock provision
    {:ok, :provisioned}
  end

  def deprovision_tenant_schema(_schema_name, _opts \\ []) do
    # Mock deprovision
    :ok
  end

  def schema_exists?(_schema_name) do
    # Mock check
    true
  end
end
