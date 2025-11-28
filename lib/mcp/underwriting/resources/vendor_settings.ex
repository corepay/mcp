defmodule Mcp.Underwriting.VendorSettings do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "underwriting_vendor_settings"
    repo Mcp.Repo
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    
    read :get_settings do
      # Singleton access: return the first record or default
      prepare build(limit: 1)
    end
  end

  code_interface do
    define :get_settings, action: :get_settings
    define :create, action: :create
    define :update, action: :update
  end

  attributes do
    uuid_primary_key :id

    attribute :preferred_vendor, :atom do
      constraints [one_of: [:comply_cube, :idenfy]]
      default :comply_cube
      allow_nil? false
    end

    attribute :circuit_breaker_enabled, :boolean do
      default true
      allow_nil? false
    end
    
    timestamps()
  end
  
  # Singleton enforcement could be done via unique index or code, 
  # but for now we'll just rely on the Admin UI to manage the single record.
end
