defmodule Mcp.Underwriting.Processor do
  @moduledoc """
  Represents a payment processor or acquirer.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(role == :admin)
    end
  end

  postgres do
    table "underwriting_processors"
    repo(Mcp.Repo)
  end

  # Processors are global platform entities, not per-tenant
  # But we might want them selectable by tenants.
  # For now, we'll keep them as public shared entities.

  actions do
    defaults [:read, :destroy, :update]

    create :create do
      primary? true
      accept [:name, :adapter, :status]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :adapter, :string do
      description "The code module or service name for API interaction."
    end

    attribute :status, :atom do
      constraints one_of: [:active, :inactive]
      default :active
    end

    attribute :supported_regions, {:array, :string} do
      description "List of ISO country codes or regions (e.g., US, EU, APAC) supported by this processor."
      default ["US"]
    end

    timestamps()
  end

  relationships do
    has_many :bank_profiles, Mcp.Underwriting.BankProfile
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :get_by_id, action: :read, get_by: [:id]
  end
end
