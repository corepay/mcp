defmodule Mcp.Underwriting.VendorSettings do
  @moduledoc """
  Settings for external underwriting vendors.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "underwriting_vendor_settings"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :update, :destroy]

    create :create do
      primary? true
      accept [:preferred_vendor, :sla_hours, :auto_approve_threshold, :auto_reject_threshold]
    end

    read :get_settings do
      # Singleton access: return the first record or default (per tenant)
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
      constraints one_of: [:comply_cube, :idenfy]
      default :comply_cube
      allow_nil? false
    end

    attribute :circuit_breaker_enabled, :boolean do
      default true
      allow_nil? false
    end

    attribute :webhook_token, :string do
      allow_nil? false
      default &Ash.UUID.generate/0
    end

    attribute :auto_approve_threshold, :integer do
      default 90
      allow_nil? false
    end

    attribute :auto_reject_threshold, :integer do
      default 50
      allow_nil? false
    end

    attribute :sla_hours, :integer do
      default 4
      allow_nil? false
    end

    timestamps()
  end
end
