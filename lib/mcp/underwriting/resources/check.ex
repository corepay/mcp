defmodule Mcp.Underwriting.Check do
  @moduledoc """
  Represents a specific check (KYC, KYB, Credit) performed during underwriting.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "underwriting_checks"
    repo(Mcp.Repo)
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

    read :list_by_client do
      argument :client_id, :uuid, allow_nil?: false
      filter expr(client_id == ^arg(:client_id))
    end

    read :get_latest_by_type do
      argument :client_id, :uuid, allow_nil?: false
      argument :type, :atom, allow_nil?: false
      get? true
      filter expr(client_id == ^arg(:client_id) and type == ^arg(:type))
      prepare build(sort: [inserted_at: :desc], limit: 1)
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :get, action: :read, get_by: [:id]
    define :list_by_client, args: [:client_id]
    define :get_latest_by_type, args: [:client_id, :type]
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

    # ComplyCube Check ID
    attribute :external_id, :string
    # Store full provider response
    attribute :raw_result, :map

    timestamps()
  end

  relationships do
    belongs_to :client, Mcp.Underwriting.Client
    belongs_to :document, Mcp.Underwriting.Document
  end
end
