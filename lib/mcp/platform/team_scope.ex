defmodule Mcp.Platform.TeamScope do
  @moduledoc """
  Resource for managing Team Scopes.
  Defines where a team's permissions apply (polymorphic association).
  """
  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "team_scopes"
    repo(Mcp.Repo)
    schema("platform")
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:entity_type, :entity_id]
      argument :team_id, :uuid, allow_nil?: false

      change manage_relationship(:team_id, :team, type: :append_and_remove)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :entity_type, :atom do
      allow_nil? false
      constraints one_of: [:tenant, :merchant, :reseller, :store, :partner]
    end

    attribute :entity_id, :uuid do
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :team, Mcp.Platform.Team do
      allow_nil? false
    end
  end

  code_interface do
    define :create
    define :read
    define :destroy
  end
end
