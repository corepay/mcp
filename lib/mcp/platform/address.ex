defmodule Mcp.Platform.Address do
  @moduledoc """
  Represents a physical address in the platform domain.
  """
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

  alias Mcp.Platform.Types.OwnerType

  attributes do
    uuid_primary_key :id

    attribute :owner_type, OwnerType, allow_nil?: false, public?: true
    attribute :owner_id, :uuid, allow_nil?: false, public?: true
    attribute :address_type, :string, public?: true
    attribute :label, :string, public?: true
    attribute :line1, :string, allow_nil?: false, public?: true
    attribute :line2, :string, public?: true
    attribute :city, :string, allow_nil?: false, public?: true
    attribute :state, :string, public?: true
    attribute :postal_code, :string, allow_nil?: false, public?: true
    attribute :country, :string, allow_nil?: false, default: "US", public?: true
    attribute :geo_location, AshGeo.Geometry, public?: true
    attribute :is_verified, :boolean, default: false, public?: true
    attribute :verified_at, :utc_datetime, public?: true
    attribute :verification_method, :string, public?: true
    attribute :is_primary, :boolean, default: false, public?: true
    attribute :notes, :string, public?: true

    timestamps()
  end

  relationships do
    # Add relationships if any, or verify if existing file had them.
    # Previous view_file didn't show relationships block so skipping if not present.
    # But wait, Address usually belongs to owner? But it uses owner_type/owner_id manual polymorphism.
  end

  actions do
    defaults [:read, :destroy, :update]

    create :create do
      primary? true

      accept [
        :owner_type,
        :owner_id,
        :address_type,
        :label,
        :line1,
        :line2,
        :city,
        :state,
        :postal_code,
        :country,
        :geo_location,
        :is_verified,
        :verified_at,
        :verification_method,
        :is_primary,
        :notes
      ]
    end

    read :read_one do
      get? true
      get_by [:id]
    end
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
      authorize_if actor_attribute_equals(:id, :owner_id)
      authorize_if Mcp.Platform.Checks.TenantAccess
    end
  end

  code_interface do
    define :read_one, args: [:id]
    define :create
    define :update
    define :destroy
  end

  json_api do
    type "address"
  end
end
