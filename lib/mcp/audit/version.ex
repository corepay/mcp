defmodule Mcp.Audit.Version do
  use Ash.Resource,
    domain: Mcp.Audit,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPaperTrail.Resource]

  postgres do
    table "versions"
    repo(Mcp.Repo)
  end

  attributes do
    uuid_primary_key :id
  end

  # AshPaperTrail adds attributes and relationships automatically

  actions do
    defaults [:read, :destroy, :create, :update]
  end
end
