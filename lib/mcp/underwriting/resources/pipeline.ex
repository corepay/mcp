defmodule Mcp.Underwriting.Pipeline do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "pipelines"
    repo Mcp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :description, :stages, :review_required]
    end

    update :update do
      accept [:name, :description, :stages, :review_required]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :description, :string do
      allow_nil? true
    end

    attribute :stages, {:array, :map} do
      # List of maps: [%{blueprint_id: "...", step_name: "Extraction"}]
      allow_nil? false
      default []
    end

    attribute :review_required, :boolean do
      allow_nil? false
      default false
      description "If true, the final output will be reviewed by the Response Reviewer agent."
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :tenant, Mcp.Platform.Tenant do
      allow_nil? true
    end
  end
end
