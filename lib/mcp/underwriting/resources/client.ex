defmodule Mcp.Underwriting.Client do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "underwriting_clients"
    repo Mcp.Repo
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:type, :email, :phone, :external_id, :person_details, :company_details]
      argument :application_id, :uuid, allow_nil?: false
      change manage_relationship(:application_id, :application, type: :append_and_remove)
    end

    update :update do
      primary? true
      accept [:email, :phone, :external_id, :person_details, :company_details]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :atom do
      constraints one_of: [:person, :company]
      allow_nil? false
    end

    attribute :email, :string
    attribute :phone, :string
    attribute :external_id, :string # ComplyCube Client ID

    attribute :person_details, :map do
      default %{}
      # Structure: %{first_name: "", last_name: "", dob: "", nationality: ""}
    end

    attribute :company_details, :map do
      default %{}
      # Structure: %{name: "", registration_number: "", incorporation_type: "", website: ""}
    end

    timestamps()
  end

  relationships do
    belongs_to :application, Mcp.Underwriting.Application

    has_many :addresses, Mcp.Underwriting.Address
    has_many :documents, Mcp.Underwriting.Document
    has_many :checks, Mcp.Underwriting.Check
  end
end
