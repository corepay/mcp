defmodule Mcp.Underwriting.Address do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "underwriting_addresses"
    repo Mcp.Repo
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:line1, :line2, :city, :state, :postal_code, :country, :type]
      argument :client_id, :uuid, allow_nil?: false
      change manage_relationship(:client_id, :client, type: :append_and_remove)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :line1, :string
    attribute :line2, :string
    attribute :city, :string
    attribute :state, :string
    attribute :postal_code, :string
    attribute :country, :string # ISO 2
    attribute :type, :string # main, billing, etc.

    timestamps()
  end

  relationships do
    belongs_to :client, Mcp.Underwriting.Client
  end
end
