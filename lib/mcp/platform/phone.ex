defmodule Mcp.Platform.Phone do
  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshArchival, AshJsonApi.Resource],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "phones"
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
    attribute :phone_type, :string
    attribute :label, :string
    attribute :phone, :string, allow_nil?: false
    attribute :country_code, :string, default: "US"
    attribute :extension, :string
    attribute :is_verified, :boolean, default: false
    attribute :verified_at, :utc_datetime
    attribute :verification_code, :string
    attribute :verification_sent_at, :utc_datetime
    attribute :can_sms, :boolean, default: false
    attribute :can_voice, :boolean, default: true
    attribute :is_primary, :boolean, default: false

    timestamps()
  end

  json_api do
    type "phone"
  end
end
