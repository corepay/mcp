defmodule Mcp.Underwriting.Application do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "underwriting_applications"
    repo Mcp.Repo
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:status, :application_data, :risk_score]
      argument :merchant_id, :uuid, allow_nil?: false
      change manage_relationship(:merchant_id, :merchant, type: :append_and_remove)
    end

    update :update do
      primary? true
      accept [:status, :application_data, :risk_score]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      constraints one_of: [:draft, :submitted, :under_review, :manual_review, :approved, :rejected, :more_info_required]
      default :draft
    end

    attribute :application_data, :map do
      default %{}
    end

    attribute :risk_score, :integer do
      default 0
    end

    timestamps()
  end

  relationships do
    belongs_to :merchant, Mcp.Platform.Merchant do
      domain Mcp.Platform
    end

    has_many :reviews, Mcp.Underwriting.Review
    has_many :clients, Mcp.Underwriting.Client
    has_many :documents, Mcp.Underwriting.Document
    has_one :risk_assessment, Mcp.Underwriting.RiskAssessment
  end

  code_interface do
    define :create
    define :update
    define :read
    define :destroy
    define :get_by_id, action: :read, get_by: [:id]
  end
end
