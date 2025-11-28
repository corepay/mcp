defmodule Mcp.Underwriting.Document do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "underwriting_documents"
    repo Mcp.Repo
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:type, :issuing_country, :external_id, :status]
      argument :client_id, :uuid, allow_nil?: false
      change manage_relationship(:client_id, :client, type: :append_and_remove)
    end

    update :update do
      primary? true
      accept [:status, :external_id]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :atom do
      constraints one_of: [:passport, :driving_license, :national_identity_card, :utility_bill, :bank_statement, :other]
      allow_nil? false
    end

    attribute :issuing_country, :string # ISO 2
    attribute :external_id, :string # ComplyCube Document ID

    attribute :status, :atom do
      constraints one_of: [:uploaded, :verified, :rejected, :pending]
      default :pending
    end

    timestamps()
  end

  relationships do
    belongs_to :client, Mcp.Underwriting.Client
    has_many :checks, Mcp.Underwriting.Check
  end
end
