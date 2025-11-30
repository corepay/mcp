defmodule Mcp.Underwriting.AgentBlueprint do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "agent_blueprints"
    repo Mcp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :description, :base_prompt, :tools, :routing_config, :knowledge_base_ids]
    end

    update :update do
      accept [:name, :description, :base_prompt, :tools, :routing_config, :knowledge_base_ids]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints [min_length: 3]
    end

    attribute :description, :string do
      allow_nil? true
    end

    attribute :base_prompt, :string do
      allow_nil? false
      description "The system prompt that defines the agent's persona and core capabilities."
    end

    attribute :tools, {:array, :atom} do
      allow_nil? true
      default []
      description "List of tool names this agent can use."
    end

    attribute :routing_config, :map do
      allow_nil? true
      default %{mode: :single, primary_provider: :ollama}
      description "Configuration for smart routing and fallback logic."
    end

    attribute :knowledge_base_ids, {:array, :uuid} do
      allow_nil? true
      default []
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :instruction_sets, Mcp.Underwriting.InstructionSet do
      destination_attribute :blueprint_id
    end
  end
end
