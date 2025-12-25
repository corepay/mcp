defmodule Mcp.Underwriting.Review do
  @moduledoc """
  Represents a manual review of an application.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "underwriting_reviews"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:decision, :notes, :risk_score]
      argument :application_id, :uuid, allow_nil?: false
      argument :reviewer_id, :uuid, allow_nil?: false
      change manage_relationship(:application_id, :application, type: :append_and_remove)
      change manage_relationship(:reviewer_id, :reviewer, type: :append_and_remove)
    end

    update :update do
      primary? true
      accept [:decision, :notes, :risk_score]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :decision, :atom do
      constraints one_of: [:approved, :rejected, :more_info_required]
      allow_nil? false
    end

    attribute :notes, :string
    attribute :risk_score, :integer

    attribute :reviewer_id, :uuid do
      allow_nil? false
      description "The user who performed this review - required for audit trail"
    end

    timestamps()
  end

  relationships do
    belongs_to :application, Mcp.Underwriting.Application

    belongs_to :reviewer, Mcp.Accounts.User do
      source_attribute :reviewer_id
      destination_attribute :id
      allow_nil? false
    end
  end

  code_interface do
    define :create
    define :update
    define :read
    define :destroy
  end
end
