defmodule Mcp.Platform.Invitation do
  @moduledoc """
  Resource representing team and entity invitations.
  Tracks invitation status, expiration, and acceptance.
  """
  use Ash.Resource,
    otp_app: :mcp,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "invitations"
    repo(Mcp.Repo)
    schema("platform")
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:email, :role, :permissions, :entity_type, :entity_id, :team_id, :scope_id]
      argument :token, :string, allow_nil?: false
      argument :expires_at, :utc_datetime, allow_nil?: false

      change set_attribute(:token, arg(:token))
      change set_attribute(:expires_at, arg(:expires_at))
      change set_attribute(:status, :pending)
    end

    update :accept do
      accept []
      change set_attribute(:status, :accepted)
      change set_attribute(:accepted_at, &DateTime.utc_now/0)
    end

    update :expire do
      accept []
      change set_attribute(:status, :expired)
    end

    read :by_token do
      argument :token, :string, allow_nil?: false
      get? true
      filter expr(token == ^arg(:token))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string do
      allow_nil? false
      constraints match: ~r/^[^\s]+@[^\s]+$/
    end

    attribute :token, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :status, :atom do
      constraints one_of: [:pending, :accepted, :expired, :revoked]
      default :pending
      allow_nil? false
    end

    attribute :role, :atom do
      allow_nil? false
      constraints one_of: [:admin, :developer, :member, :viewer]
      default :member
    end

    attribute :permissions, {:array, :atom} do
      default []
    end

    # Context fields (Entity Hierarchy)
    attribute :entity_type, :atom do
      constraints one_of: [:tenant, :merchant, :reseller, :store]
    end

    attribute :entity_id, :uuid

    attribute :expires_at, :utc_datetime do
      allow_nil? false
    end

    attribute :accepted_at, :utc_datetime

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :inviter, Mcp.Accounts.User
    belongs_to :team, Mcp.Platform.Team
    belongs_to :scope, Mcp.Platform.TeamScope
    # Scope is polymorphic in concept, but we store explicit entity_type/id.
    # We can also verify against a TeamScope if needed, but linking to Team is main goal.
  end

  code_interface do
    define :create, args: [:email, :token, :expires_at]
    define :accept
    define :expire
    define :by_token, args: [:token]
  end

  identities do
    identity :token, [:token]
  end
end
