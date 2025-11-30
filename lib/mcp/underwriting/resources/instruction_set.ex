defmodule Mcp.Underwriting.InstructionSet do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "instruction_sets"
    repo Mcp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :instructions, :blueprint_id]
    end

    update :update do
      accept [:name, :instructions]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      description "Human readable name for this policy (e.g. 'Conservative Mortgage Policy')"
    end

    attribute :instructions, :string do
      allow_nil? false
      description "Natural language instructions for the agent."
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :blueprint, Mcp.Underwriting.AgentBlueprint do
      allow_nil? false
    end

    belongs_to :tenant, Mcp.Platform.Tenant do
      # In a real multi-tenant app, this is crucial.
      # For now, we'll make it optional or assume it's handled by the actor context,
      # but explicit relationship is better for DB constraints.
      allow_nil? true 
      attribute_type :uuid
    end
  end
end
