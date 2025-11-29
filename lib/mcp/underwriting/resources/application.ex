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
      accept [:status, :application_data, :risk_score, :subject_id, :subject_type]
    end

    update :update do
      primary? true
      accept [:status, :application_data, :risk_score, :submitted_at, :sla_due_at]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :subject_id, :uuid do
      allow_nil? false
    end

    attribute :subject_type, :atom do
      allow_nil? false
      constraints one_of: [:merchant, :individual, :property]
    end

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

    attribute :submitted_at, :utc_datetime_usec
    attribute :sla_due_at, :utc_datetime_usec

    timestamps()
  end

  relationships do
    # belongs_to :merchant, Mcp.Platform.Merchant do
    #   domain Mcp.Platform
    # end

    has_many :reviews, Mcp.Underwriting.Review
    has_many :clients, Mcp.Underwriting.Client
    has_many :documents, Mcp.Underwriting.Document
    has_one :risk_assessment, Mcp.Underwriting.RiskAssessment
    has_many :activities, Mcp.Underwriting.Activity
  end

  code_interface do
    define :create
    define :update
    define :read
    define :destroy
    define :get_by_id, action: :read, get_by: [:id]
  end
end
