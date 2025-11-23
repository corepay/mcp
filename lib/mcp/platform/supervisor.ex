defmodule Mcp.Platform.Supervisor do
  @moduledoc """
  Platform supervisor.
  Manages platform-level services: PubSub, Finch HTTP client, Registry/PartitionSupervisor.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Phoenix PubSub for real-time communication
      {Phoenix.PubSub, name: Mcp.PubSub},

      # Finch HTTP client for external API calls
      {Finch, name: Mcp.Finch},

      # Registry for process lookup
      {Registry, keys: :unique, name: Mcp.Registry},

      # PartitionSupervisor for dynamic supervision
      {PartitionSupervisor, child_spec: DynamicSupervisor, name: Mcp.DynamicSupervisor},

      # Schema Provisioner is handled by TenantMigrationManager
      # Mcp.Platform.SchemaProvisioner,

      # Tenant Migration Manager for schema migrations
      # Mcp.Platform.TenantMigrationManager,

      # Tenant Backup Manager for backup and recovery
      # Mcp.Platform.TenantBackupManager,

      # Task.Supervisor for async tenant operations
      {Task.Supervisor, name: Mcp.TaskSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
