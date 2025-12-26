defmodule Mcp.Platform.Team do
  @moduledoc """
  Resource for managing Teams.
  Teams allow organizing users with shared permissions.
  """
  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "teams"
    repo(Mcp.Repo)
    schema("platform")
  end

  actions do
    defaults [:read, :destroy]

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
    end

    create :create do
      primary? true
      accept [:name, :slug, :description, :permissions, :entity_type, :entity_id]
    end

    update :update do
      primary? true
      accept [:name, :description, :permissions]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :slug, :string do
      allow_nil? false
    end

    attribute :description, :string

    attribute :permissions, {:array, :string} do
      allow_nil? false
      default []
    end

    attribute :entity_type, :atom do
      allow_nil? false
      constraints one_of: [:tenant, :merchant, :reseller, :platform]
    end

    attribute :entity_id, :uuid do
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :members, Mcp.Platform.TeamMember
    has_many :scopes, Mcp.Platform.TeamScope
  end

  code_interface do
    define :create
    define :read
    define :by_id, args: [:id], get?: true
    define :update
    define :destroy
  end
end
