defmodule Mcp.Underwriting.Execution do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "executions"
    repo Mcp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:pipeline_id, :subject_id, :subject_type, :context, :status]
    end

    update :update do
      accept [:status, :results, :context]
    end
  end

  code_interface do
    define :create
    define :update
  end

  attributes do
    uuid_primary_key :id

    attribute :subject_id, :uuid do
      allow_nil? false
    end

    attribute :subject_type, :atom do
      allow_nil? false
    end

    attribute :status, :atom do
      constraints [one_of: [:pending, :processing, :completed, :failed]]
      default :pending
      allow_nil? false
    end

    attribute :context, :map do
      allow_nil? true
      default %{}
      description "Runtime context (e.g. loan_amount, property_value)"
    end

    attribute :results, :map do
      allow_nil? true
      default %{}
      description "Map of Agent Output by Stage Name"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :pipeline, Mcp.Underwriting.Pipeline do
      allow_nil? false
    end

  end
end
