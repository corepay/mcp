defmodule Mcp.Platform.Email do
  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshArchival, AshJsonApi.Resource],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "emails"
    schema "platform"
    repo Mcp.Repo
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
    attribute :email_type, :string
    attribute :label, :string
    attribute :email, :ci_string, allow_nil?: false
    attribute :is_verified, :boolean, default: false
    attribute :verified_at, :utc_datetime
    attribute :verification_token, :string
    attribute :verification_sent_at, :utc_datetime
    attribute :is_primary, :boolean, default: false
    attribute :can_receive_marketing, :boolean, default: false
    attribute :can_receive_transactional, :boolean, default: true

    timestamps()
  end

  json_api do
    type "email"
  end
end
