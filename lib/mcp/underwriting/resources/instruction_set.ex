defmodule Mcp.Underwriting.InstructionSet do
  @moduledoc """
  Set of instructions for an underwriting agent.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "instruction_sets"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :instructions, :blueprint_id]
      change &calculate_hash/2
    end

    update :update do
      require_atomic? false
      accept [:name, :instructions]
      change &calculate_hash/2
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :get, action: :read, get_by: [:id]
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

    attribute :hash, :string do
      description "SHA-256 hash of the instructions for version tracking."
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

  def calculate_hash(changeset, _) do
    case Ash.Changeset.get_attribute(changeset, :instructions) do
      nil ->
        changeset

      instructions ->
        hash = :crypto.hash(:sha256, instructions) |> Base.encode16()
        Ash.Changeset.force_change_attribute(changeset, :hash, hash)
    end
  end
end
