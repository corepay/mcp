defmodule Mcp.Platform.DataMigrationRecord do
  @moduledoc """
  Resource for tracking individual record status in a migration.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "data_migration_records"
    schema "platform"
    repo Mcp.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :source_data, :map
    attribute :target_data, :map
    
    attribute :status, :atom do
      constraints one_of: [:pending, :success, :failed, :validation_failed]
      default :pending
    end
    
    attribute :error_message, :string
    attribute :validation_errors, :map

    timestamps()
  end
  
  relationships do
    belongs_to :migration, Mcp.Platform.DataMigration do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:migration_id, :source_data, :target_data, :status, :error_message, :validation_errors]
    end
    
    read :by_migration do
      argument :migration_id, :uuid, allow_nil?: false
      filter expr(migration_id == ^arg(:migration_id))
    end
  end

  code_interface do
    define :create
    define :read
    define :by_migration, args: [:migration_id]
  end
end
