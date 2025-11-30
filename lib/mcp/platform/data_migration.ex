defmodule Mcp.Platform.DataMigration do
  @moduledoc """
  Resource for tracking data migration jobs.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "data_migrations"
    schema "platform"
    repo Mcp.Repo
  end

  json_api do
    type "data_migration"
  end

  attributes do
    uuid_primary_key :id

    attribute :migration_type, :atom do
      constraints one_of: [:import, :export]
      allow_nil? false
    end

    attribute :name, :string do
      allow_nil? false
    end

    attribute :description, :string

    attribute :status, :atom do
      constraints one_of: [:pending, :processing, :completed, :failed]
      default :pending
    end

    attribute :source_format, :atom do
      constraints one_of: [:csv, :json, :sql]
    end
    
    attribute :target_format, :atom do
      constraints one_of: [:csv, :json, :sql]
    end

    attribute :source_config, :map do
      default %{}
    end

    attribute :target_config, :map do
      default %{}
    end
    
    attribute :field_mappings, :map do
      default %{}
    end
    
    attribute :validation_rules, :map do
      default %{}
    end

    attribute :batch_size, :integer do
      default 100
    end
    
    attribute :total_records, :integer do
      default 0
    end
    
    attribute :processed_records, :integer do
      default 0
    end
    
    attribute :failed_records, :integer do
      default 0
    end
    
    attribute :progress_percentage, :float do
      default 0.0
    end
    
    attribute :file_path, :string

    timestamps()
  end
  
  relationships do
    belongs_to :tenant, Mcp.Platform.Tenant do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:tenant_id, :migration_type, :name, :description, :source_format, :target_format, :source_config, :target_config, :field_mappings, :validation_rules, :batch_size, :total_records]
    end
    
    update :update_progress do
      accept [:processed_records, :failed_records, :progress_percentage, :status, :file_path]
    end
    
    update :complete do
      change set_attribute(:status, :completed)
      accept [:processed_records, :failed_records, :progress_percentage, :file_path]
    end
    
    update :fail do
      change set_attribute(:status, :failed)
    end
  end

  code_interface do
    define :create
    define :read
    define :get, action: :read, get_by: [:id]
    define :update_progress
    define :complete
    define :fail
  end
end
