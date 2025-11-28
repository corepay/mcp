defmodule Mcp.Underwriting.Check do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "underwriting_checks"
    repo Mcp.Repo
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:type, :status, :outcome, :external_id, :raw_result]
      argument :client_id, :uuid, allow_nil?: false
      argument :document_id, :uuid
      change manage_relationship(:client_id, :client, type: :append_and_remove)
      change manage_relationship(:document_id, :document, type: :append_and_remove)
    end

    update :update do
      primary? true
      accept [:status, :outcome, :raw_result, :external_id]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :atom do
      constraints one_of: [
        :standard_screening_check,
        :extensive_screening_check,
        :document_check,
        :identity_check,
        :proof_of_address_check,
        :multi_bureau_check,
        :face_authentication_check
      ]
      allow_nil? false
    end

    attribute :status, :atom do
      constraints one_of: [:pending, :complete, :failed]
      default :pending
    end

    attribute :outcome, :atom do
      constraints one_of: [:clear, :attention, :confirmed, :not_confirmed, :none]
      default :none
    end

    attribute :external_id, :string # ComplyCube Check ID
    attribute :raw_result, :map # Store full provider response

    timestamps()
  end

  relationships do
    belongs_to :client, Mcp.Underwriting.Client
    belongs_to :document, Mcp.Underwriting.Document
  end
end
