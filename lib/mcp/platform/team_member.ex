defmodule Mcp.Platform.TeamMember do
  @moduledoc """
  Resource for managing Team Members.
  """
  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "team_members"
    repo(Mcp.Repo)
    schema("platform")
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:role, :user_profile_id]
      argument :user_id, :uuid, allow_nil?: false
      argument :team_id, :uuid, allow_nil?: false

      change manage_relationship(:user_id, :user, type: :append_and_remove)
      change manage_relationship(:team_id, :team, type: :append_and_remove)
    end

    update :update do
      primary? true
      accept [:role]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :atom do
      constraints one_of: [:member, :lead, :admin]
      default :member
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at

    attribute :user_profile_id, :uuid do
      # Allow nil in resource, but DB enforces it? Or false? DB says NOT NULL.
      allow_nil? true
    end
  end

  relationships do
    belongs_to :team, Mcp.Platform.Team do
      allow_nil? false
    end

    belongs_to :user, Mcp.Accounts.User do
      allow_nil? false
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
  end
end
