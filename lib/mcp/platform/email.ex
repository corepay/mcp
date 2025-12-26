defmodule Mcp.Platform.Email do
  @moduledoc """
  Represents an email address.
  """
  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshArchival, AshJsonApi.Resource],
    authorizers: [Ash.Policy.Authorizer]

  alias Mcp.Platform.Types.OwnerType

  postgres do
    table "emails"
    schema("platform")
    repo(Mcp.Repo)
  end

  attributes do
    uuid_primary_key :id

    attribute :owner_type, OwnerType, allow_nil?: false, public?: true
    attribute :owner_id, :uuid, allow_nil?: false, public?: true
    attribute :email_type, :string, public?: true
    attribute :label, :string, public?: true
    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :is_verified, :boolean, default: false, public?: true
    attribute :verified_at, :utc_datetime, public?: true
    attribute :verification_token, :string, public?: true
    attribute :verification_sent_at, :utc_datetime, public?: true
    attribute :is_primary, :boolean, default: false, public?: true
    attribute :can_receive_marketing, :boolean, default: false, public?: true
    attribute :can_receive_transactional, :boolean, default: true, public?: true

    timestamps()
  end

  relationships do
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(owner_id == ^actor(:id))
      authorize_if Mcp.Platform.Checks.TenantAccess
    end

    policy action_type(:create) do
      authorize_if Mcp.Platform.Checks.OwnerMatchesActor
      authorize_if Mcp.Platform.Checks.TenantMemberForCreate
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(owner_id == ^actor(:id))
      authorize_if Mcp.Platform.Checks.TenantAccess
    end
  end

  actions do
    defaults [:read, :destroy]

    update :update do
      primary? true

      accept [
        :owner_type,
        :owner_id,
        :email,
        :email_type,
        :label,
        :is_primary,
        :can_receive_marketing,
        :can_receive_transactional
      ]
    end

    create :create do
      primary? true

      accept [
        :owner_type,
        :owner_id,
        :email,
        :email_type,
        :label,
        :is_primary,
        :can_receive_marketing,
        :can_receive_transactional
      ]
    end

    read :read_one do
      get? true
      get_by [:id]
    end

    update :set_primary do
      require_atomic? false
      accept []
      change Mcp.Platform.Changes.SetPrimary
    end
  end

  code_interface do
    define :read_one, args: [:id]
    define :create
    define :update
    define :destroy
    define :set_primary
  end

  json_api do
    type "email"
  end
end
