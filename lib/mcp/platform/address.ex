defmodule Mcp.Platform.Address do
  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshArchival, AshJsonApi.Resource],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "addresses"
    schema("platform")
    repo(Mcp.Repo)
  end

  actions do
    defaults [:read, :destroy, :create, :update]
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :owner_type, :string, allow_nil?: false
    attribute :owner_id, :uuid, allow_nil?: false
    attribute :address_type, :string
    attribute :label, :string
    attribute :line1, :string, allow_nil?: false
    attribute :line2, :string
    attribute :city, :string, allow_nil?: false
    attribute :state, :string
    attribute :postal_code, :string, allow_nil?: false
    attribute :country, :string, allow_nil?: false, default: "US"
    attribute :is_verified, :boolean, default: false
    attribute :verified_at, :utc_datetime
    attribute :verification_method, :string
    attribute :is_primary, :boolean, default: false
    attribute :notes, :string

    timestamps()
  end

  json_api do
    type "address"
  end
end
