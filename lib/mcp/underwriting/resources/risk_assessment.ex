defmodule Mcp.Underwriting.RiskAssessment do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "risk_assessments"
    repo Mcp.Repo
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:score, :factors, :recommendation]
      argument :merchant_id, :uuid, allow_nil?: false
      change manage_relationship(:merchant_id, :merchant, type: :append_and_remove)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :score, :integer do
      allow_nil? false
    end

    attribute :factors, :map do
      default %{}
    end

    attribute :recommendation, :atom do
      constraints one_of: [:approve, :reject, :manual_review]
    end

    timestamps()
  end

  relationships do
    belongs_to :merchant, Mcp.Platform.Merchant do
      domain Mcp.Platform
    end
  end

  code_interface do
    define :create
    define :read
    define :destroy
  end
end
