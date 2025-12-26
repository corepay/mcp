defmodule Mcp.Platform.Phone do
  @moduledoc """
  Represents a phone number.
  """
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

  alias Mcp.Platform.Types.OwnerType

  attributes do
    uuid_primary_key :id

    attribute :owner_type, OwnerType, allow_nil?: false, public?: true
    attribute :owner_id, :uuid, allow_nil?: false, public?: true
    attribute :phone_type, :string, public?: true
    attribute :label, :string, public?: true
    attribute :phone, :string, allow_nil?: false, public?: true
    attribute :country_code, :string, default: "US", public?: true
    attribute :extension, :string, public?: true
    attribute :is_verified, :boolean, default: false, public?: true
    attribute :verified_at, :utc_datetime, public?: true
    attribute :verification_code, :string, public?: true
    attribute :verification_sent_at, :utc_datetime, public?: true
    attribute :can_sms, :boolean, default: false, public?: true
    attribute :can_voice, :boolean, default: true, public?: true
    attribute :is_primary, :boolean, default: false, public?: true

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
        :phone,
        :phone_type,
        :label,
        :country_code,
        :extension,
        :is_primary,
        :can_sms,
        :can_voice
      ]
    end

    create :create do
      primary? true

      accept [
        :owner_type,
        :owner_id,
        :phone,
        :phone_type,
        :label,
        :country_code,
        :extension,
        :is_primary,
        :can_sms,
        :can_voice
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
    type "phone"
  end
end
