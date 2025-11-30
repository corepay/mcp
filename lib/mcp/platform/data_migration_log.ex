defmodule Mcp.Platform.DataMigrationLog do
  @moduledoc """
  Resource for logging migration events.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "data_migration_logs"
    schema "platform"
    repo Mcp.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :message, :string do
      allow_nil? false
    end
    
    attribute :level, :atom do
      constraints one_of: [:info, :warning, :error]
      default :info
    end
    
    attribute :details, :map

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
      accept [:migration_id, :message, :level, :details]
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
